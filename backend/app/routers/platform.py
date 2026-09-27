from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth import password_hash, user_wire
from app.db import get_session
from app.models import Tenant, User
from app.schemas import PlatformUserInput, SchoolInput

router = APIRouter(prefix="/platform", tags=["platform"])
Db = Annotated[Session, Depends(get_session)]


def _school_wire(school: Tenant) -> dict:
    return {
        "id": school.id,
        "tenantId": school.id,
        "name": school.name,
        "city": school.city,
        "board": school.board,
        "active": school.active,
    }


@router.get("/schools/{tenant_id}/validate")
def validate_school(tenant_id: str, session: Db) -> dict:
    school = session.get(Tenant, tenant_id.lower().strip())
    if school is None or not school.active:
        return {"valid": False}
    return {"valid": True, "name": school.name, "city": school.city, "board": school.board}


@router.get("/schools")
def list_schools(session: Db) -> list[dict]:
    return [_school_wire(item) for item in session.scalars(select(Tenant).order_by(Tenant.name))]


@router.get("/schools/{tenant_id}")
def get_school(tenant_id: str, session: Db) -> dict:
    school = session.get(Tenant, tenant_id.lower().strip())
    if school is None:
        raise HTTPException(status_code=404, detail="School not found")
    return _school_wire(school)


@router.post("/schools", status_code=201)
def create_school(data: SchoolInput, session: Db) -> dict:
    school_id = data.tenant_id.lower().strip()
    if school_id == "platform":
        raise HTTPException(status_code=422, detail="Reserved school code")
    try:
        with session.begin():
            school = Tenant(id=school_id, name=data.name.strip(), city=data.city, board=data.board, active=data.active)
            session.add(school)
            session.flush()
            result = _school_wire(school)
        return result
    except IntegrityError as error:
        raise HTTPException(status_code=409, detail="School code already exists") from error


@router.put("/schools/{tenant_id}/status")
def school_status(tenant_id: str, body: dict[str, bool], session: Db) -> dict:
    with session.begin():
        school = session.get(Tenant, tenant_id.lower().strip())
        if school is None:
            raise HTTPException(status_code=404, detail="School not found")
        school.active = bool(body.get("active"))
        result = _school_wire(school)
    return result


@router.post("/users", status_code=201)
def create_platform_user(data: PlatformUserInput, session: Db) -> dict:
    try:
        with session.begin():
            user = User(
                scope="platform", tenant_id=None, email=data.email,
                password_hash=password_hash(data.password), full_name=data.full_name,
                phone=data.phone, role="SUPER_ADMIN", linked_entity_id=None,
                extra_permissions=[], active=True, created_at=datetime.now(timezone.utc),
            )
            session.add(user)
            session.flush()
            result = user_wire(user)
        return result
    except IntegrityError as error:
        raise HTTPException(status_code=409, detail="Platform email already exists") from error
