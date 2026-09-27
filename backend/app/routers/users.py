from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth import password_hash, user_wire, verify_password
from app.db import get_session
from app.dependencies import require_tenant, tenant_id
from app.models import Student, User
from app.schemas import ChangePasswordInput, UserInput

router = APIRouter(prefix="/users", tags=["users"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]


def _linked_entity(session: Session, tenant: str, data: UserInput) -> None:
    if data.role == "STUDENT":
        student = session.get(Student, data.linked_entity_id) if data.linked_entity_id else None
        if student is None or student.tenant_id != tenant:
            raise HTTPException(status_code=422, detail="Student user requires a student in this school")
    elif data.role == "PARENT":
        ids = [item.strip() for item in (data.linked_entity_id or "").split(",") if item.strip()]
        if not ids:
            raise HTTPException(status_code=422, detail="Parent user requires linked student IDs")
        for student_id in ids:
            student = session.get(Student, student_id)
            if student is None or student.tenant_id != tenant:
                raise HTTPException(status_code=422, detail="Linked child must belong to this school")


@router.get("")
def list_users(request: Request, session: Db, tenant: TenantId) -> list[dict]:
    require_tenant(session, tenant)
    users = list(session.scalars(select(User).where(User.scope == tenant, User.active.is_(True)).order_by(User.full_name)))
    if request.state.user_role in ("SUPER_ADMIN", "SCHOOL_ADMIN"):
        return [user_wire(item) for item in users]
    if request.state.user_role in ("PARENT", "STUDENT"):
        users = [item for item in users if item.role in ("SCHOOL_ADMIN", "TEACHER")]
    else:
        users = [item for item in users if item.role in ("SCHOOL_ADMIN", "TEACHER", "PARENT")]
    return [{"id": item.id, "fullName": item.full_name, "role": item.role} for item in users]


@router.post("", status_code=201)
def create_user(data: UserInput, session: Db, tenant: TenantId) -> dict:
    if not data.password:
        raise HTTPException(status_code=422, detail="Password is required")
    try:
        with session.begin():
            require_tenant(session, tenant)
            _linked_entity(session, tenant, data)
            user = User(
                scope=tenant,
                tenant_id=tenant,
                email=data.email,
                password_hash=password_hash(data.password),
                full_name=data.full_name,
                phone=data.phone,
                role=data.role,
                linked_entity_id=data.linked_entity_id,
                extra_permissions=data.extra_permissions,
                active=True,
                created_at=datetime.now(timezone.utc),
            )
            session.add(user)
            session.flush()
            result = user_wire(user)
        return result
    except IntegrityError as error:
        raise HTTPException(status_code=409, detail="Email is already used in this school") from error


@router.post("/change-password")
def change_password(data: ChangePasswordInput, request: Request, session: Db) -> dict:
    with session.begin():
        user = session.get(User, request.state.user_id)
        if user is None or not verify_password(data.current_password, user.password_hash):
            raise HTTPException(status_code=401, detail="Current password is incorrect")
        user.password_hash = password_hash(data.new_password)
    return {"message": "Password updated successfully"}


@router.get("/{user_id}")
def get_user(user_id: str, session: Db, tenant: TenantId) -> dict:
    require_tenant(session, tenant)
    user = session.get(User, user_id)
    if user is None or user.scope != tenant:
        raise HTTPException(status_code=404, detail="User not found")
    return user_wire(user)


@router.put("/{user_id}")
def update_user(user_id: str, data: UserInput, session: Db, tenant: TenantId) -> dict:
    try:
        with session.begin():
            require_tenant(session, tenant)
            user = session.get(User, user_id)
            if user is None or user.scope != tenant:
                raise HTTPException(status_code=404, detail="User not found")
            _linked_entity(session, tenant, data)
            user.email = data.email
            user.full_name = data.full_name
            user.phone = data.phone
            user.role = data.role
            user.linked_entity_id = data.linked_entity_id
            user.extra_permissions = data.extra_permissions
            if data.password:
                user.password_hash = password_hash(data.password)
            session.flush()
            result = user_wire(user)
        return result
    except IntegrityError as error:
        raise HTTPException(status_code=409, detail="Email is already used in this school") from error


@router.delete("/{user_id}", status_code=204)
def deactivate_user(user_id: str, session: Db, tenant: TenantId) -> Response:
    with session.begin():
        require_tenant(session, tenant)
        user = session.get(User, user_id)
        if user is None or user.scope != tenant:
            raise HTTPException(status_code=404, detail="User not found")
        user.active = False
    return Response(status_code=204)
