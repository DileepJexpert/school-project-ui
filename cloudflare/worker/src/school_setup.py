"""D1-backed first-run school settings and catalogue reads."""

from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel, Field

from school_auth import _db, get_current_user, require_admin
from school_overview import _many, _one, _tenant


router = APIRouter(prefix="/api", tags=["school setup"])


def _current_year() -> str:
    today = date.today()
    start = today.year if today.month >= 4 else today.year - 1
    return f"{start}-{start + 1}"


def _year(value: str | None) -> str:
    year = value or _current_year()
    if len(year) != 9 or year[4] != "-" or not year[:4].isdigit() or not year[5:].isdigit() or int(year[5:]) != int(year[:4]) + 1:
        raise HTTPException(status_code=422, detail="Use academic year YYYY-YYYY")
    return year


class ProfileInput(BaseModel):
    name: str = Field(min_length=1, max_length=200)


@router.get("/school/profile")
async def get_profile(
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    school = await _one(db, "SELECT id, name, city, board FROM tenants WHERE id = ?", tenant)
    return {"tenantId": school["id"], "name": school["name"], "city": school["city"], "board": school["board"]}


@router.put("/school/profile")
async def update_profile(
    data: ProfileInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    name = data.name.strip()
    if not name:
        raise HTTPException(status_code=422, detail="School name cannot be blank")
    await db.prepare("UPDATE tenants SET name = ? WHERE id = ?").bind(name, tenant).run()
    return await get_profile(db, user, x_tenant_id)


@router.get("/master-data")
async def master_data(
    academic_year: str | None = Query(default=None, alias="academicYear"),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    year = _year(academic_year)
    years = await _many(db, "SELECT year, start_date, end_date, status, grade_bands, pass_percentage, exam_order FROM academic_years WHERE tenant_id = ? ORDER BY year", tenant)
    classes = await _many(db, "SELECT class_name, base_class, section FROM school_classes WHERE tenant_id = ? AND active = 1 ORDER BY sort_order", tenant)
    subjects = await _many(db, "SELECT name FROM school_subjects WHERE tenant_id = ? AND active = 1 ORDER BY sort_order", tenant)
    structures = await _many(db, "SELECT class_name FROM fee_structures WHERE tenant_id = ? AND academic_year = ?", tenant, year)
    mapped = await _many(db, "SELECT DISTINCT class_name FROM class_subjects WHERE tenant_id = ? AND academic_year = ?", tenant, year)
    selected = next((item for item in years if item["year"] == year), None)
    configured = {row["class_name"] for row in structures}
    mapped_classes = {row["class_name"] for row in mapped}
    class_names = [row["class_name"] for row in classes]
    return {
        "academicYear": year,
        "gradingPolicyConfigured": bool(selected and selected["grade_bands"] and selected["pass_percentage"] is not None),
        "examWeightagesConfigured": False,
        "years": [{"year": row["year"], "startDate": row["start_date"], "endDate": row["end_date"], "status": row["status"]} for row in years],
        "classes": [{"className": row["class_name"], "baseClass": row["base_class"], "section": row["section"]} for row in classes],
        "subjects": [row["name"] for row in subjects],
        "configuredFeeClasses": [name for name in class_names if name in configured],
        "missingFeeClasses": [name for name in class_names if name not in configured],
        "configuredSubjectClasses": [name for name in class_names if name in mapped_classes],
        "missingSubjectClasses": [name for name in class_names if name not in mapped_classes],
    }
