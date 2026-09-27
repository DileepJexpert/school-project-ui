"""Audience-scoped notices with read state belonging to each user."""

from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth import aware
from app.db import get_session
from app.dependencies import lock_tenant, require_tenant, tenant_id
from app.models import Notification, NotificationRead, Student, User
from app.schemas import NotificationInput

router = APIRouter(prefix="/notifications", tags=["notifications"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]


def _notice(session: Session, tenant: str, notice_id: str) -> Notification:
    item = session.get(Notification, notice_id)
    if item is None or item.tenant_id != tenant or item.deleted_at:
        raise HTTPException(status_code=404, detail="Notification not found")
    return item


def _linked_students(session: Session, user: User) -> list[Student]:
    ids = {part.strip() for part in (user.linked_entity_id or "").split(",") if part.strip()}
    return [student for student_id in ids if (student := session.get(Student, student_id)) is not None and student.tenant_id == user.tenant_id]


def _visible(item: Notification, user: User, students: list[Student]) -> bool:
    if user.role in ("SUPER_ADMIN", "SCHOOL_ADMIN", "TEACHER"):
        return True
    if item.expires_at and aware(item.expires_at) < datetime.now(timezone.utc):
        return False
    if item.target_audience == "ALL":
        return True
    if item.target_audience == "CLASS_SPECIFIC":
        return any(student.class_name == item.target_class for student in students)
    return any(student.id == item.target_student_id for student in students)


def _wire(session: Session, item: Notification, user: User) -> dict:
    read = session.scalar(select(NotificationRead).where(
        NotificationRead.notification_id == item.id, NotificationRead.user_id == user.id,
    )) is not None
    return {
        "id": item.id, "title": item.title, "message": item.message,
        "type": item.type, "targetAudience": item.target_audience,
        "targetClass": item.target_class, "targetStudentId": item.target_student_id,
        "priority": item.priority, "createdBy": item.created_by,
        "createdAt": aware(item.created_at).isoformat(),
        "expiresAt": aware(item.expires_at).isoformat() if item.expires_at else None,
        "read": read,
    }


def _list(session: Session, tenant: str, user: User) -> list[dict]:
    require_tenant(session, tenant)
    students = _linked_students(session, user) if user.role in ("STUDENT", "PARENT") else []
    items = session.scalars(select(Notification).where(
        Notification.tenant_id == tenant, Notification.deleted_at.is_(None),
    ).order_by(Notification.created_at.desc(), Notification.id))
    return [_wire(session, item, user) for item in items if _visible(item, user, students)]


@router.get("")
def notifications(request: Request, session: Db, tenant: TenantId) -> list[dict]:
    return _list(session, tenant, session.get(User, request.state.user_id))


@router.get("/type/{notice_type}")
def notifications_by_type(notice_type: str, request: Request, session: Db, tenant: TenantId) -> list[dict]:
    return [item for item in notifications(request, session, tenant) if item["type"] == notice_type.upper()]


@router.get("/student/{student_id}")
def notifications_for_student(student_id: str, request: Request, session: Db, tenant: TenantId, class_name: str | None = None) -> list[dict]:
    user = session.get(User, request.state.user_id)
    student = session.get(Student, student_id)
    if student is None or student.tenant_id != tenant:
        raise HTTPException(status_code=404, detail="Student not found")
    if user.role in ("STUDENT", "PARENT") and student.id not in {item.id for item in _linked_students(session, user)}:
        raise HTTPException(status_code=403, detail="Student not linked to account")
    # The student's saved class is authoritative; ignore a stale client className.
    return [item for item in _list(session, tenant, user) if item["targetAudience"] == "ALL" or (
        item["targetAudience"] == "CLASS_SPECIFIC" and item["targetClass"] == student.class_name
    ) or (item["targetAudience"] == "INDIVIDUAL" and item["targetStudentId"] == student_id)]


@router.get("/class/{class_name}")
def notifications_for_class(class_name: str, request: Request, session: Db, tenant: TenantId) -> list[dict]:
    user = session.get(User, request.state.user_id)
    if user.role in ("STUDENT", "PARENT") and class_name not in {student.class_name for student in _linked_students(session, user)}:
        raise HTTPException(status_code=403, detail="Class not linked to account")
    return [item for item in _list(session, tenant, user) if item["targetAudience"] == "ALL" or (
        item["targetAudience"] == "CLASS_SPECIFIC" and item["targetClass"] == class_name
    )]


def _check_target(session: Session, tenant: str, data: NotificationInput) -> None:
    if data.target_student_id:
        student = session.get(Student, data.target_student_id)
        if student is None or student.tenant_id != tenant:
            raise HTTPException(status_code=404, detail="Target student not found")


@router.post("", status_code=201)
def create_notification(data: NotificationInput, request: Request, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        lock_tenant(session, tenant)
        _check_target(session, tenant, data)
        user = session.get(User, request.state.user_id)
        item = Notification(
            tenant_id=tenant, title=data.title.strip(), message=data.message.strip(),
            type=data.type, target_audience=data.target_audience,
            target_class=data.target_class if data.target_audience == "CLASS_SPECIFIC" else None,
            target_student_id=data.target_student_id if data.target_audience == "INDIVIDUAL" else None,
            priority=data.priority, created_by=user.full_name, creator_id=user.id,
            created_at=datetime.now(timezone.utc), expires_at=aware(data.expires_at) if data.expires_at else None,
        )
        session.add(item)
        session.flush()
        result = _wire(session, item, user)
    return result


@router.put("/{notice_id}/read")
def mark_read(notice_id: str, request: Request, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        lock_tenant(session, tenant)
        item = _notice(session, tenant, notice_id)
        user = session.get(User, request.state.user_id)
        if not _visible(item, user, _linked_students(session, user)):
            raise HTTPException(status_code=403, detail="Notification not visible to account")
        existing = session.scalar(select(NotificationRead).where(
            NotificationRead.notification_id == item.id, NotificationRead.user_id == user.id,
        ))
        if existing is None:
            session.add(NotificationRead(
                tenant_id=tenant, notification_id=item.id, user_id=user.id,
                read_at=datetime.now(timezone.utc),
            ))
            session.flush()
        result = _wire(session, item, user)
    return result


@router.put("/{notice_id}")
def update_notification(notice_id: str, data: NotificationInput, request: Request, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        lock_tenant(session, tenant)
        item = _notice(session, tenant, notice_id)
        if request.state.user_role == "TEACHER" and item.creator_id != request.state.user_id:
            raise HTTPException(status_code=403, detail="Can edit only own notification")
        _check_target(session, tenant, data)
        item.title = data.title.strip()
        item.message = data.message.strip()
        item.type = data.type
        item.target_audience = data.target_audience
        item.target_class = data.target_class if data.target_audience == "CLASS_SPECIFIC" else None
        item.target_student_id = data.target_student_id if data.target_audience == "INDIVIDUAL" else None
        item.priority = data.priority
        item.expires_at = aware(data.expires_at) if data.expires_at else None
        result = _wire(session, item, session.get(User, request.state.user_id))
    return result


@router.delete("/{notice_id}", status_code=204)
def delete_notification(notice_id: str, request: Request, session: Db, tenant: TenantId) -> Response:
    with session.begin():
        lock_tenant(session, tenant)
        item = _notice(session, tenant, notice_id)
        if request.state.user_role == "TEACHER" and item.creator_id != request.state.user_id:
            raise HTTPException(status_code=403, detail="Can delete only own notification")
        item.deleted_at = datetime.now(timezone.utc)
    return Response(status_code=204)
