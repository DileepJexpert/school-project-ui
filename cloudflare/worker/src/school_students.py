"""Tenant-scoped student read endpoints for the Flutter Students page."""

from __future__ import annotations

import json

from fastapi import APIRouter, Depends, Header, HTTPException, Query

from school_auth import _db, get_current_user
from school_overview import _many, _one, _tenant


router = APIRouter(prefix="/api/students", tags=["students"])
root_router = APIRouter(prefix="/students", tags=["students_root"])


def _require_read(user: dict) -> None:
    permissions = user.get("permissions") or []
    if "*" not in permissions and "students:read" not in permissions:
        raise HTTPException(status_code=403, detail="Student read access required")


def _safe_json(val, default=None):
    if not val:
        return default or {}
    try:
        return json.loads(val)
    except Exception:
        return default or {}


def _wire(row: dict) -> dict:
    return {
        "id": row["id"],
        "fullName": row["full_name"],
        "dateOfBirth": row["date_of_birth"],
        "gender": row["gender"],
        "bloodGroup": row["blood_group"],
        "nationality": row["nationality"],
        "religion": row["religion"],
        "motherTongue": row["mother_tongue"],
        "aadharNumber": row["aadhar_number"],
        "classForAdmission": row["class_name"],
        "academicYear": row["academic_year"],
        "dateOfAdmission": row["date_of_admission"],
        "admissionNumber": row["admission_number"],
        "rollNumber": row["roll_number"],
        "status": row["status"],
        "parentDetails": _safe_json(row.get("parent_details")),
        "contactDetails": _safe_json(row.get("contact_details")),
        "previousSchoolDetails": _safe_json(row.get("previous_school_details")),
    }


_COLUMNS = (
    "id, full_name, date_of_birth, gender, blood_group, nationality, religion, "
    "mother_tongue, aadhar_number, class_name, academic_year, date_of_admission, "
    "admission_number, roll_number, status, parent_details, contact_details, "
    "previous_school_details"
)


async def _handle_list_students(
    className: str | None = Query(default=None),
    academicYear: str | None = Query(default=None),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)
    query = f"SELECT {_COLUMNS} FROM students WHERE tenant_id = ?"
    params = [tenant]

    if className and className.strip() and className.strip().upper() != "ALL":
        query += " AND class_name = ?"
        params.append(className.strip())

    if academicYear and academicYear.strip() and academicYear.strip().upper() != "ALL":
        query += " AND academic_year = ?"
        params.append(academicYear.strip())

    query += " ORDER BY full_name, id"
    rows = await _many(db, query, *params)
    return [_wire(row) for row in rows]


async def _handle_search_students(
    name: str = Query(default="", max_length=200),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)
    rows = await _many(
        db,
        f"SELECT {_COLUMNS} FROM students WHERE tenant_id = ? "
        "AND full_name LIKE ? ORDER BY full_name, id",
        tenant, f"%{name.strip()}%",
    )
    return [_wire(row) for row in rows]


async def _handle_get_student(
    student_id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)
    row = await _one(
        db,
        f"SELECT {_COLUMNS} FROM students WHERE tenant_id = ? AND id = ?",
        tenant, student_id,
    )
    if not row:
        raise HTTPException(status_code=404, detail="Student not found")
    return _wire(row)


for rtr in (router, root_router):
    rtr.add_api_route("", _handle_list_students, methods=["GET"])
    rtr.add_api_route("/search", _handle_search_students, methods=["GET"])
    rtr.add_api_route("/{student_id}", _handle_get_student, methods=["GET"])
