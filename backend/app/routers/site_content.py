"""Per-school public website copy and lists, configured during first run."""

import json
from datetime import datetime, timezone
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field, model_validator
from sqlalchemy.orm import Session

from app.db import get_session
from app.dependencies import lock_tenant
from app.models import SchoolSiteContent, Tenant
from app.routers.public import _school

router = APIRouter(prefix="/api/site-content", tags=["site content"])
Db = Annotated[Session, Depends(get_session)]

SCALARS = {
    "schoolShortName", "tagline", "accreditation", "founded",
    "phone", "email", "address", "officeHours",
    "admissionCtaTitle", "admissionCtaSubtitle",
    "feeStructureTitle", "feeStructureNote", "mapUrl",
    "announcement", "facebookUrl",
    "principalName", "principalTitle", "principalImagePath", "heroBannerImagePath",
    "principalMessage", "mission", "vision",
}
LISTS = {
    "stats", "coreValues", "achievements", "testimonials", "events", "notices",
    "academicLevels", "coCurriculars", "feeStructure", "admissionSteps",
    "importantDates", "forms", "galleryCategories", "galleryImages",
    "transportZones", "transportFeatures", "timeline",
}


class SiteContentInput(BaseModel):
    content: dict[str, Any] = Field(default_factory=dict)

    @model_validator(mode="after")
    def valid_content(self):
        if set(self.content) - (SCALARS | LISTS):
            raise ValueError("Unknown website content field")
        if any(not isinstance(self.content[key], str) for key in self.content if key in SCALARS):
            raise ValueError("Website text fields must be strings")
        if any(not isinstance(self.content[key], list) for key in self.content if key in LISTS):
            raise ValueError("Website list fields must be arrays")
        if len(json.dumps(self.content, ensure_ascii=False)) > 256_000:
            raise ValueError("Website content exceeds 256 KB")
        return self


@router.get("")
def get_site_content(session: Db, x_tenant_id: str | None = Header(default=None)) -> dict:
    tenant = _school(session, x_tenant_id)
    school = session.get(Tenant, tenant)
    record = session.get(SchoolSiteContent, tenant)
    return {"schoolName": school.name, **(record.content if record else {})}


@router.put("")
def save_site_content(data: SiteContentInput, request: Request, session: Db,
                      x_tenant_id: str | None = Header(default=None)) -> dict:
    if request.state.user_role not in ("SUPER_ADMIN", "SCHOOL_ADMIN"):
        raise HTTPException(status_code=403, detail="School administrator required")
    with session.begin():
        tenant = _school(session, x_tenant_id)
        lock_tenant(session, tenant)
        record = session.get(SchoolSiteContent, tenant)
        if record is None:
            record = SchoolSiteContent(tenant_id=tenant)
            session.add(record)
        record.content = data.content
        record.updated_at = datetime.now(timezone.utc)
        session.flush()
    return {"schoolName": session.get(Tenant, tenant).name, **data.content}
