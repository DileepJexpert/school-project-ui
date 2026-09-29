"""D1-backed enquiry and initial admission writes for one school."""

from __future__ import annotations

from calendar import month_abbr
from datetime import date
import json
from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, Response
from pydantic import BaseModel, Field

from school_auth import _db, get_current_user
from school_overview import _many, _one, _tenant
from school_setup import _year
from school_students import _COLUMNS, _wire


router = APIRouter(prefix="/api/students", tags=["admissions"])


class StudentInput(BaseModel):
    fullName: str = Field(min_length=1, max_length=200)
    dateOfBirth: date
    gender: str = ""
    bloodGroup: str = ""
    nationality: str = ""
    religion: str = ""
    motherTongue: str = ""
    aadharNumber: str = ""
    classForAdmission: str = Field(min_length=1, max_length=80)
    academicYear: str
    dateOfAdmission: date
    admissionNumber: str = ""
    rollNumber: str | None = None
    status: Literal["ENQUIRY", "ACTIVE", "INACTIVE", "TC_ISSUED", "LEFT"] = "ACTIVE"
    parentDetails: dict = Field(default_factory=dict)
    contactDetails: dict = Field(default_factory=dict)
    previousSchoolDetails: dict = Field(default_factory=dict)


def _permission(user: dict) -> None:
    permissions = user.get("permissions") or []
    if "*" not in permissions and "students:write" not in permissions:
        raise HTTPException(status_code=403, detail="Student write access required")


async def _validate_context(db, tenant: str, item: StudentInput, *, enquiry: bool = False) -> tuple[str, str]:
    year = _year(item.academicYear)
    class_name = item.classForAdmission.strip()
    if not class_name or not item.fullName.strip():
        raise HTTPException(status_code=422, detail="Student and class names cannot be blank")
    if enquiry:
        # The enquiry form asks for a class of interest before a section is assigned.
        known = await _one(db, "SELECT id FROM school_classes WHERE tenant_id = ? AND active = 1 AND (base_class = ? OR class_name = ?) LIMIT 1", tenant, class_name, class_name)
    else:
        known = await _one(db, "SELECT id FROM school_classes WHERE tenant_id = ? AND class_name = ? AND active = 1", tenant, class_name)
    if not known:
        raise HTTPException(status_code=409, detail="Set up the class first")
    closed = await _one(db, "SELECT id FROM class_year_closures WHERE tenant_id = ? AND class_name = ? AND academic_year = ?", tenant, class_name, year)
    if closed:
        raise HTTPException(status_code=409, detail=f"{class_name} ({year}) is closed after rollover")
    return class_name, year


async def _structure(db, tenant: str, class_name: str, year: str) -> tuple[dict, list[dict]]:
    structure = await _one(db, "SELECT id FROM fee_structures WHERE tenant_id = ? AND class_name = ? AND academic_year = ?", tenant, class_name, year)
    components = await _many(db, "SELECT name, amount, frequency FROM fee_components WHERE structure_id = ? ORDER BY position", structure["id"]) if structure else []
    if not components:
        raise HTTPException(status_code=409, detail=f"Set up fees for {class_name} ({year}) before admission")
    return structure, components


def _student_values(item: StudentInput, tenant: str, student_id: str, admission_number: str, status: str, class_name: str, year: str) -> tuple:
    return (
        student_id, tenant, item.fullName.strip(), item.dateOfBirth.isoformat(),
        item.gender, item.bloodGroup, item.nationality, item.religion,
        item.motherTongue, item.aadharNumber, class_name, year,
        item.dateOfAdmission.isoformat(), admission_number, item.rollNumber or "",
        status, json.dumps(item.parentDetails), json.dumps(item.contactDetails),
        json.dumps(item.previousSchoolDetails),
    )


_INSERT_STUDENT = (
    "INSERT INTO students (id, tenant_id, full_name, date_of_birth, gender, "
    "blood_group, nationality, religion, mother_tongue, aadhar_number, "
    "class_name, academic_year, date_of_admission, admission_number, "
    "roll_number, status, parent_details, contact_details, previous_school_details) "
    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
)


def _profile_statements(db, tenant: str, student_id: str, item: StudentInput, class_name: str, year: str, structure: dict, components: list[dict]):
    enrollment_id = uuid4().hex
    profile_id = uuid4().hex
    statements = [
        db.prepare("INSERT INTO enrollments (id, tenant_id, student_id, academic_year, class_name, roll_number, date_of_admission, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)").bind(enrollment_id, tenant, student_id, year, class_name, item.rollNumber or "", item.dateOfAdmission.isoformat(), "ACTIVE"),
        db.prepare("INSERT INTO fee_profiles (id, tenant_id, enrollment_id, fee_structure_id) VALUES (?, ?, ?, ?)").bind(profile_id, tenant, enrollment_id, structure["id"]),
    ]
    position = 0
    for component in components:
        if component["frequency"] == "MONTHLY":
            for offset in range(12):
                month = (3 + offset) % 12 + 1
                calendar_year = int(year[:4]) + (3 + offset) // 12
                name = f"{component['name']} - {month_abbr[month]} {calendar_year}"
                statements.append(db.prepare("INSERT INTO fee_installments (id, profile_id, position, name, amount_due, paid_amount, discount_amount, status) VALUES (?, ?, ?, ?, ?, 0, 0, 'UNPAID')").bind(uuid4().hex, profile_id, position, name, component["amount"]))
                position += 1
        else:
            statements.append(db.prepare("INSERT INTO fee_installments (id, profile_id, position, name, amount_due, paid_amount, discount_amount, status) VALUES (?, ?, ?, ?, ?, 0, 0, 'UNPAID')").bind(uuid4().hex, profile_id, position, component["name"], component["amount"]))
            position += 1
    return statements


async def _created(db, tenant: str, student_id: str) -> dict:
    row = await _one(db, f"SELECT {_COLUMNS} FROM students WHERE tenant_id = ? AND id = ?", tenant, student_id)
    return _wire(row)


@router.post("/enquiry", status_code=201)
async def create_enquiry(
    item: StudentInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user)
    tenant = await _tenant(db, user, x_tenant_id)
    class_name, year = await _validate_context(db, tenant, item, enquiry=True)
    student_id = uuid4().hex
    admission_number = f"ENQ-{uuid4().hex[:16].upper()}"
    await db.prepare(_INSERT_STUDENT).bind(*_student_values(item, tenant, student_id, admission_number, "ENQUIRY", class_name, year)).run()
    return await _created(db, tenant, student_id)


@router.post("/add", status_code=201)
async def admit_student(
    item: StudentInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user)
    tenant = await _tenant(db, user, x_tenant_id)
    class_name, year = await _validate_context(db, tenant, item)
    structure, components = await _structure(db, tenant, class_name, year)
    student_id = uuid4().hex
    admission_number = item.admissionNumber.strip() or f"ADM-{uuid4().hex[:16].upper()}"
    existing = await _one(db, "SELECT id FROM students WHERE tenant_id = ? AND admission_number = ?", tenant, admission_number)
    if existing:
        raise HTTPException(status_code=409, detail="Duplicate admission number")
    statements = [db.prepare(_INSERT_STUDENT).bind(*_student_values(item, tenant, student_id, admission_number, "ACTIVE", class_name, year))]
    statements.extend(_profile_statements(db, tenant, student_id, item, class_name, year, structure, components))
    await db.batch(statements)
    return await _created(db, tenant, student_id)


@router.delete("/{student_id}", status_code=204)
async def delete_enquiry(
    student_id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user)
    tenant = await _tenant(db, user, x_tenant_id)
    student = await _one(db, "SELECT status FROM students WHERE tenant_id = ? AND id = ?", tenant, student_id)
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    if student["status"] != "ENQUIRY":
        raise HTTPException(status_code=409, detail="Only enquiries can be deleted")
    enrolled = await _one(db, "SELECT id FROM enrollments WHERE tenant_id = ? AND student_id = ?", tenant, student_id)
    if enrolled:
        raise HTTPException(status_code=409, detail="Enquiry has an enrollment")
    await db.prepare("DELETE FROM students WHERE tenant_id = ? AND id = ? AND status = 'ENQUIRY'").bind(tenant, student_id).run()
    return Response(status_code=204)


@router.put("/{student_id}")
async def save_student(
    student_id: str,
    item: StudentInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user)
    tenant = await _tenant(db, user, x_tenant_id)
    old = await _one(db, "SELECT status, class_name, academic_year, admission_number FROM students WHERE tenant_id = ? AND id = ?", tenant, student_id)
    if not old:
        raise HTTPException(status_code=404, detail="Student not found")
    class_name, year = await _validate_context(db, tenant, item, enquiry=old["status"] == "ENQUIRY" and item.status == "ENQUIRY")
    activating_enquiry = old["status"] == "ENQUIRY" and item.status == "ACTIVE"
    if old["status"] != "ENQUIRY" and (old["class_name"] != class_name or old["academic_year"] != year):
        raise HTTPException(status_code=409, detail="Class/year change requires the atomic rollover workflow")
    if old["status"] == "ENQUIRY" and item.status not in ("ENQUIRY", "ACTIVE"):
        raise HTTPException(status_code=409, detail="An enquiry must be admitted before changing status")
    enrollment = await _one(db, "SELECT id FROM enrollments WHERE tenant_id = ? AND student_id = ? AND academic_year = ?", tenant, student_id, year)
    if old["status"] != "ENQUIRY" and not enrollment:
        raise HTTPException(status_code=409, detail="Student enrollment is missing")
    structure, components = await _structure(db, tenant, class_name, year) if activating_enquiry else (None, [])
    admission_number = item.admissionNumber.strip() or old["admission_number"]
    if activating_enquiry and admission_number.startswith("ENQ-"):
        admission_number = f"ADM-{uuid4().hex[:16].upper()}"
    duplicate = await _one(db, "SELECT id FROM students WHERE tenant_id = ? AND admission_number = ? AND id <> ?", tenant, admission_number, student_id)
    if duplicate:
        raise HTTPException(status_code=409, detail="Duplicate admission number")
    values = _student_values(item, tenant, student_id, admission_number, item.status, class_name, year)
    statements = [db.prepare(
        "UPDATE students SET full_name = ?, date_of_birth = ?, gender = ?, blood_group = ?, "
        "nationality = ?, religion = ?, mother_tongue = ?, aadhar_number = ?, "
        "class_name = ?, academic_year = ?, date_of_admission = ?, admission_number = ?, "
        "roll_number = ?, status = ?, parent_details = ?, contact_details = ?, "
        "previous_school_details = ? WHERE tenant_id = ? AND id = ?"
    ).bind(*values[2:], tenant, student_id)]
    if activating_enquiry:
        statements.extend(_profile_statements(db, tenant, student_id, item, class_name, year, structure, components))
    elif enrollment:
        enrollment_status = "ACTIVE" if item.status == "ACTIVE" else "INACTIVE"
        statements.append(db.prepare("UPDATE enrollments SET status = ?, roll_number = ? WHERE tenant_id = ? AND id = ?").bind(enrollment_status, item.rollNumber or "", tenant, enrollment["id"]))
    await db.batch(statements)
    return await _created(db, tenant, student_id)
