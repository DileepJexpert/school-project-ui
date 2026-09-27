"""Homework, incident and certificate records with year and tenant boundaries."""

from collections import Counter
from datetime import date, datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.admissions import require_open_class_year
from app.auth import aware
from app.db import get_session
from app.dependencies import lock_tenant, require_tenant, tenant_id
from app.models import CertificateRecord, Enrollment, Homework, Incident, Student, User
from app.schemas import CertificateInput, HomeworkInput, IncidentInput, IncidentResolutionInput
from app.years import academic_year_for_date

Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]
homework_router = APIRouter(prefix="/homework", tags=["homework"])
incident_router = APIRouter(prefix="/discipline", tags=["discipline"])
certificate_router = APIRouter(prefix="/certificates", tags=["certificates"])
student_homework_router = APIRouter(prefix="/student-portal", tags=["student-portal"])


def _student(session: Session, tenant: str, student_id: str) -> Student:
    item = session.get(Student, student_id)
    if item is None or item.tenant_id != tenant:
        raise HTTPException(status_code=404, detail="Student not found")
    return item


def _homework_wire(item: Homework) -> dict:
    return {
        "id": item.id, "title": item.title, "description": item.description,
        "className": item.class_name, "subject": item.subject,
        "teacherId": item.teacher_id, "teacherName": item.teacher_name,
        "dueDate": item.due_date.isoformat(), "assignedDate": item.assigned_date.isoformat(),
        "academicYear": item.academic_year, "status": item.status,
        "createdAt": aware(item.created_at).isoformat(),
    }


def _incident_wire(item: Incident) -> dict:
    return {
        "id": item.id, "studentId": item.student_id, "studentName": item.student_name,
        "className": item.class_name, "academicYear": item.academic_year,
        "severity": item.severity, "category": item.category,
        "description": item.description, "actionTaken": item.action_taken,
        "reportedBy": item.reported_by, "incidentDate": item.incident_date.isoformat(),
        "parentNotified": item.parent_notified,
        "parentNotifiedAt": aware(item.parent_notified_at).isoformat() if item.parent_notified_at else None,
        "followUpNotes": item.follow_up_notes, "resolved": item.resolved,
        "resolvedAt": aware(item.resolved_at).isoformat() if item.resolved_at else None,
        "createdAt": aware(item.created_at).isoformat(),
    }


def _certificate_wire(item: CertificateRecord) -> dict:
    return {
        "id": item.id, "studentId": item.student_id, "studentName": item.student_name,
        "className": item.class_name, "academicYear": item.academic_year,
        "certificateType": item.certificate_type, "serialNumber": item.serial_number,
        "reason": item.reason, "additionalFields": item.additional_fields,
        "generatedBy": item.generated_by, "generatedAt": aware(item.generated_at).isoformat(),
    }


@homework_router.get("")
def list_homework(session: Db, tenant: TenantId, class_name: str | None = Query(default=None, alias="className"), academic_year: str | None = Query(default=None, alias="academicYear")) -> list[dict]:
    require_tenant(session, tenant)
    query = select(Homework).where(Homework.tenant_id == tenant, Homework.deleted_at.is_(None))
    if class_name:
        query = query.where(Homework.class_name == class_name)
    if academic_year:
        query = query.where(Homework.academic_year == academic_year)
    return [_homework_wire(item) for item in session.scalars(query.order_by(Homework.created_at.desc(), Homework.id))]


@student_homework_router.get("/homework")
def student_homework(request: Request, session: Db, tenant: TenantId) -> list[dict]:
    user = session.get(User, request.state.user_id)
    if not user or user.role != "STUDENT" or not user.linked_entity_id:
        raise HTTPException(status_code=403, detail="Linked student required")
    student = _student(session, tenant, user.linked_entity_id)
    return [_homework_wire(item) for item in session.scalars(select(Homework).where(
        Homework.tenant_id == tenant, Homework.class_name == student.class_name,
        Homework.academic_year == student.academic_year, Homework.status == "ACTIVE",
        Homework.deleted_at.is_(None),
    ).order_by(Homework.due_date.desc()))]


@homework_router.get("/{homework_id}")
def get_homework(homework_id: str, request: Request, session: Db, tenant: TenantId) -> dict:
    item = session.get(Homework, homework_id)
    if item is None or item.tenant_id != tenant or item.deleted_at:
        raise HTTPException(status_code=404, detail="Homework not found")
    if request.state.user_role in ("STUDENT", "PARENT"):
        user = session.get(User, request.state.user_id)
        linked = {part.strip() for part in (user.linked_entity_id or "").split(",") if part.strip()}
        if not any((student := session.get(Student, student_id)) and student.tenant_id == tenant and student.class_name == item.class_name and student.academic_year == item.academic_year for student_id in linked):
            raise HTTPException(status_code=403, detail="Homework not assigned to linked student")
    return _homework_wire(item)


@homework_router.post("", status_code=201)
def create_homework(data: HomeworkInput, request: Request, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        lock_tenant(session, tenant)
        assigned = data.assigned_date or date.today()
        year = data.academic_year or academic_year_for_date(assigned)
        if data.due_date < assigned:
            raise HTTPException(status_code=422, detail="dueDate is before assignedDate")
        require_open_class_year(session, tenant, data.class_name, year)
        user = session.get(User, request.state.user_id)
        item = Homework(
            tenant_id=tenant, title=data.title.strip(), description=data.description,
            class_name=data.class_name.strip(), subject=data.subject.strip(),
            teacher_id=user.id, teacher_name=user.full_name, due_date=data.due_date,
            assigned_date=assigned, academic_year=year, status=data.status,
            created_at=datetime.now(timezone.utc),
        )
        session.add(item)
        session.flush()
        result = _homework_wire(item)
    return result


@homework_router.put("/{homework_id}")
def update_homework(homework_id: str, data: HomeworkInput, request: Request, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        lock_tenant(session, tenant)
        item = session.get(Homework, homework_id)
        if item is None or item.tenant_id != tenant or item.deleted_at:
            raise HTTPException(status_code=404, detail="Homework not found")
        if request.state.user_role == "TEACHER" and item.teacher_id != request.state.user_id:
            raise HTTPException(status_code=403, detail="Can edit only own homework")
        require_open_class_year(session, tenant, item.class_name, item.academic_year)
        assigned = data.assigned_date or item.assigned_date
        year = data.academic_year or item.academic_year
        require_open_class_year(session, tenant, data.class_name, year)
        if data.due_date < assigned:
            raise HTTPException(status_code=422, detail="dueDate is before assignedDate")
        item.title = data.title.strip()
        item.description = data.description
        item.class_name = data.class_name.strip()
        item.subject = data.subject.strip()
        item.due_date = data.due_date
        item.assigned_date = assigned
        item.academic_year = year
        item.status = data.status
        result = _homework_wire(item)
    return result


@homework_router.delete("/{homework_id}", status_code=204)
def delete_homework(homework_id: str, request: Request, session: Db, tenant: TenantId) -> Response:
    with session.begin():
        lock_tenant(session, tenant)
        item = session.get(Homework, homework_id)
        if item is None or item.tenant_id != tenant or item.deleted_at:
            raise HTTPException(status_code=404, detail="Homework not found")
        if request.state.user_role == "TEACHER" and item.teacher_id != request.state.user_id:
            raise HTTPException(status_code=403, detail="Can delete only own homework")
        require_open_class_year(session, tenant, item.class_name, item.academic_year)
        item.deleted_at = datetime.now(timezone.utc)
    return Response(status_code=204)


@incident_router.get("")
def incidents(session: Db, tenant: TenantId, class_name: str | None = Query(default=None, alias="className"), severity: str | None = None) -> list[dict]:
    require_tenant(session, tenant)
    query = select(Incident).where(Incident.tenant_id == tenant)
    if class_name:
        query = query.where(Incident.class_name == class_name)
    if severity:
        query = query.where(Incident.severity == severity.upper())
    return [_incident_wire(item) for item in session.scalars(query.order_by(Incident.incident_date.desc(), Incident.id))]


@incident_router.get("/summary")
def incident_summary(session: Db, tenant: TenantId) -> dict:
    require_tenant(session, tenant)
    items = [_incident_wire(item) for item in session.scalars(select(Incident).where(Incident.tenant_id == tenant))]
    return {
        "totalIncidents": len(items), "resolvedIncidents": sum(item["resolved"] for item in items),
        "unresolvedIncidents": sum(not item["resolved"] for item in items),
        "bySeverity": dict(Counter(item["severity"] for item in items)),
        "byCategory": dict(Counter(item["category"] for item in items)),
        "byClass": dict(Counter(item["className"] for item in items)),
    }


@incident_router.get("/student/{student_id}")
def student_incidents(student_id: str, request: Request, session: Db, tenant: TenantId) -> list[dict]:
    _student(session, tenant, student_id)
    if request.state.user_role == "PARENT":
        user = session.get(User, request.state.user_id)
        linked = {part.strip() for part in (user.linked_entity_id or "").split(",") if part.strip()}
        if student_id not in linked:
            raise HTTPException(status_code=403, detail="Child not linked to account")
    return [_incident_wire(item) for item in session.scalars(select(Incident).where(
        Incident.tenant_id == tenant, Incident.student_id == student_id,
    ).order_by(Incident.incident_date.desc()))]


@incident_router.post("")
def create_incident(data: IncidentInput, request: Request, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        lock_tenant(session, tenant)
        student = _student(session, tenant, data.student_id)
        year = data.academic_year or student.academic_year
        enrollment = session.scalar(select(Enrollment).where(
            Enrollment.tenant_id == tenant, Enrollment.student_id == student.id,
            Enrollment.academic_year == year,
        ))
        if enrollment is None:
            raise HTTPException(status_code=422, detail="Student not enrolled in year")
        user = session.get(User, request.state.user_id)
        item = Incident(
            tenant_id=tenant, student_id=student.id, student_name=student.full_name,
            class_name=enrollment.class_name, academic_year=year,
            severity=data.severity, category=data.category, description=data.description.strip(),
            action_taken=data.action_taken, reported_by=user.full_name,
            incident_date=data.incident_date or date.today(), created_at=datetime.now(timezone.utc),
        )
        session.add(item)
        session.flush()
        result = _incident_wire(item)
    return result


@incident_router.put("/{incident_id}/resolve")
def resolve_incident(incident_id: str, data: IncidentResolutionInput, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        lock_tenant(session, tenant)
        item = session.get(Incident, incident_id)
        if item is None or item.tenant_id != tenant:
            raise HTTPException(status_code=404, detail="Incident not found")
        if item.resolved and item.follow_up_notes != data.resolution:
            raise HTTPException(status_code=409, detail="Incident already resolved")
        if not item.resolved:
            item.resolved = True
            item.resolved_at = datetime.now(timezone.utc)
            item.follow_up_notes = data.resolution
        result = _incident_wire(item)
    return result


@certificate_router.get("")
def certificates(session: Db, tenant: TenantId) -> list[dict]:
    require_tenant(session, tenant)
    return [_certificate_wire(item) for item in session.scalars(select(CertificateRecord).where(
        CertificateRecord.tenant_id == tenant,
    ).order_by(CertificateRecord.generated_at.desc()))]


@certificate_router.get("/student/{student_id}")
def student_certificates(student_id: str, session: Db, tenant: TenantId) -> list[dict]:
    _student(session, tenant, student_id)
    return [_certificate_wire(item) for item in session.scalars(select(CertificateRecord).where(
        CertificateRecord.tenant_id == tenant, CertificateRecord.student_id == student_id,
    ).order_by(CertificateRecord.generated_at.desc()))]


@certificate_router.get("/type/{certificate_type}")
def certificates_by_type(certificate_type: str, session: Db, tenant: TenantId) -> list[dict]:
    return [item for item in certificates(session, tenant) if item["certificateType"] == certificate_type.upper()]


@certificate_router.post("/generate")
def generate_certificate(data: CertificateInput, request: Request, session: Db, tenant: TenantId) -> dict:
    prefix = {"TRANSFER": "TC", "BONAFIDE": "BF", "CHARACTER": "CC", "STUDY": "SC", "ID_CARD": "ID"}[data.certificate_type]
    with session.begin():
        lock_tenant(session, tenant)
        student = _student(session, tenant, data.student_id)
        sequence = session.scalar(select(func.count()).select_from(CertificateRecord).where(CertificateRecord.tenant_id == tenant)) or 0
        user = session.get(User, request.state.user_id)
        item = CertificateRecord(
            tenant_id=tenant, student_id=student.id, student_name=student.full_name,
            class_name=student.class_name, academic_year=student.academic_year,
            certificate_type=data.certificate_type, serial_number=f"{prefix}-{sequence + 1001}",
            reason=data.reason, additional_fields=data.additional_fields,
            generated_by=user.full_name, generated_at=datetime.now(timezone.utc),
        )
        session.add(item)
        session.flush()
        result = _certificate_wire(item)
    return result
