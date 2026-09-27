"""Public contact submission and authenticated office enquiry listing."""

from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_session
from app.models import ContactEnquiry, Tenant

router = APIRouter(prefix="/api/contact", tags=["contact"])
Db = Annotated[Session, Depends(get_session)]


def _school(session: Session, requested: str | None) -> str:
    code = (requested or "").strip().lower()
    if code and code != "default":
        school = session.get(Tenant, code)
        if school is None or not school.active:
            raise HTTPException(status_code=404, detail="School not found")
        return code
    schools = list(session.scalars(select(Tenant).where(Tenant.active.is_(True)).limit(2)))
    if len(schools) != 1:
        raise HTTPException(status_code=400, detail="Choose a school code")
    return schools[0].id


class ContactEnquiryInput(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    email: str = Field(min_length=3, max_length=320)
    phone: str = Field(min_length=1, max_length=40)
    gradeInterested: str = Field(default="", max_length=80)
    message: str = Field(min_length=1, max_length=4000)

    @field_validator("name", "email", "phone", "gradeInterested", "message")
    @classmethod
    def trim(cls, value: str) -> str:
        return value.strip()


@router.post("/enquiry", status_code=201)
def submit_contact(
    data: ContactEnquiryInput, session: Db,
    x_tenant_id: str | None = Header(default=None),
) -> dict:
    if not data.name or not data.phone or not data.message or "@" not in data.email:
        raise HTTPException(status_code=422, detail="Name, valid email, phone and message are required")
    with session.begin():
        tenant = _school(session, x_tenant_id)
        enquiry = ContactEnquiry(
            tenant_id=tenant, name=data.name, email=data.email,
            phone=data.phone, grade_interested=data.gradeInterested,
            message=data.message, created_at=datetime.now(timezone.utc),
        )
        session.add(enquiry)
        session.flush()
        return {"id": enquiry.id, "status": "RECEIVED"}


@router.get("/enquiries")
def list_contact_enquiries(
    request: Request, session: Db,
    x_tenant_id: str | None = Header(default=None),
) -> list[dict]:
    if request.state.user_role not in ("SUPER_ADMIN", "SCHOOL_ADMIN"):
        raise HTTPException(status_code=403, detail="School administrator required")
    tenant = _school(session, x_tenant_id)
    return [
        {"id": item.id, "name": item.name, "email": item.email,
         "phone": item.phone, "gradeInterested": item.grade_interested,
         "message": item.message, "createdAt": item.created_at.isoformat()}
        for item in session.scalars(select(ContactEnquiry).where(
            ContactEnquiry.tenant_id == tenant,
        ).order_by(ContactEnquiry.created_at.desc()))
    ]
