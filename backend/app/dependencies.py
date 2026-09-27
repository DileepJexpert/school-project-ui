from typing import Annotated

from fastapi import Header, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Tenant


def tenant_id(x_tenant_id: Annotated[str | None, Header()] = None) -> str:
    if not x_tenant_id or not x_tenant_id.strip():
        raise HTTPException(status_code=400, detail="X-Tenant-ID is required")
    return x_tenant_id.strip().lower()


def require_tenant(session: Session, tenant: str) -> None:
    if session.get(Tenant, tenant) is None:
        raise HTTPException(status_code=404, detail="School not found")


def lock_tenant(session: Session, tenant: str) -> None:
    school = session.scalar(select(Tenant).where(Tenant.id == tenant).with_for_update())
    if school is None:
        raise HTTPException(status_code=404, detail="School not found")
