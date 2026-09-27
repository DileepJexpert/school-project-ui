"""Authenticated school profile settings used by the admin UI."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field, field_validator
from sqlalchemy.orm import Session

from app.db import get_session
from app.dependencies import lock_tenant, require_tenant, tenant_id
from app.models import Tenant

router = APIRouter(prefix="/api/school/profile", tags=["school profile"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]


class SchoolProfileInput(BaseModel):
    name: str = Field(min_length=1, max_length=200)

    @field_validator("name")
    @classmethod
    def trim(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("School name cannot be blank")
        return value


@router.get("")
def get_profile(session: Db, tenant: TenantId) -> dict:
    require_tenant(session, tenant)
    school = session.get(Tenant, tenant)
    return {"tenantId": school.id, "name": school.name, "city": school.city, "board": school.board}


@router.put("")
def update_profile(data: SchoolProfileInput, request: Request, session: Db, tenant: TenantId) -> dict:
    if request.state.user_role not in ("SUPER_ADMIN", "SCHOOL_ADMIN"):
        raise HTTPException(status_code=403, detail="School administrator required")
    with session.begin():
        lock_tenant(session, tenant)
        school = session.get(Tenant, tenant)
        school.name = data.name
        session.flush()
    return {"tenantId": school.id, "name": school.name, "city": school.city, "board": school.board}
