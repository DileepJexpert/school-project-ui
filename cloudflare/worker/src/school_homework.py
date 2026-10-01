"""D1 homework management endpoints for admin, teacher, and student portal."""

from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response
from pydantic import BaseModel, Field

from school_auth import _db, get_current_user
from school_overview import _many, _one, _tenant
from school_setup import _year


router = APIRouter(tags=["homework"])


class HomeworkInput(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str = Field(default="", max_length=4000)
    className: str = Field(min_length=1, max_length=80)
    subject: str = Field(min_length=1, max_length=120)
    dueDate: str = Field(min_length=8, max_length=20)
    assignedDate: str | None = None
    academicYear: str | None = None
    status: str | None = "ASSIGNED"


def _require_read(user: dict) -> None:
    permissions = user.get("permissions") or []
    if "*" not in permissions and "homework:read" not in permissions and "homework:read:own" not in permissions:
        raise HTTPException(status_code=403, detail="Homework read access required")


def _require_write(user: dict) -> None:
    permissions = user.get("permissions") or []
    if "*" not in permissions and "homework:write" not in permissions:
        raise HTTPException(status_code=403, detail="Homework write access required")


def _wire(row: dict) -> dict:
    return {
        "id": row["id"],
        "title": row["title"],
        "description": row.get("description") or "",
        "className": row["class_name"],
        "subject": row["subject"],
        "teacherId": row["teacher_id"],
        "teacherName": row["teacher_name"],
        "dueDate": row["due_date"],
        "assignedDate": row["assigned_date"],
        "academicYear": row["academic_year"],
        "status": row.get("status") or "ASSIGNED",
        "createdAt": row["created_at"],
    }


# =========================================================================
# ROUTE 1: GET /api/homework
# =========================================================================
@router.get("/api/homework")
async def get_all_homework(
    className: str | None = Query(default=None),
    academicYear: str | None = Query(default=None),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)

    query = (
        "SELECT id, tenant_id, title, description, class_name, subject, "
        "teacher_id, teacher_name, due_date, assigned_date, academic_year, "
        "status, created_at "
        "FROM homework WHERE tenant_id = ? AND deleted_at IS NULL"
    )
    params = [tenant]

    if className and className.strip() and className.strip() != "All Classes":
        query += " AND class_name = ?"
        params.append(className.strip())

    if academicYear and academicYear.strip():
        query += " AND academic_year = ?"
        params.append(_year(academicYear.strip()))

    query += " ORDER BY due_date DESC, created_at DESC"

    rows = await _many(db, query, *params)
    return [_wire(r) for r in rows]


# =========================================================================
# ROUTE 2: POST /api/homework
# =========================================================================
@router.post("/api/homework", status_code=201)
async def create_homework(
    data: HomeworkInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _require_write(user)
    tenant = await _tenant(db, user, x_tenant_id)

    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()
    today_str = now.strftime("%Y-%m-%d")

    assigned_date = (data.assignedDate or today_str).strip()
    year = _year(data.academicYear or "2026-2027")
    hw_id = uuid4().hex
    teacher_id = user.get("id") or user.get("sub") or "admin"
    teacher_name = user.get("fullName") or user.get("name") or "Administrator"

    await db.prepare(
        "INSERT INTO homework (id, tenant_id, title, description, class_name, "
        "subject, teacher_id, teacher_name, due_date, assigned_date, "
        "academic_year, status, created_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    ).bind(
        hw_id,
        tenant,
        data.title.strip(),
        data.description.strip(),
        data.className.strip(),
        data.subject.strip(),
        teacher_id,
        teacher_name,
        data.dueDate.strip(),
        assigned_date,
        year,
        data.status or "ASSIGNED",
        now_iso,
    ).run()

    created = await _one(
        db,
        "SELECT * FROM homework WHERE tenant_id = ? AND id = ?",
        tenant, hw_id,
    )
    return _wire(created) if created else {
        "id": hw_id,
        "title": data.title,
        "description": data.description,
        "className": data.className,
        "subject": data.subject,
        "teacherId": teacher_id,
        "teacherName": teacher_name,
        "dueDate": data.dueDate,
        "assignedDate": assigned_date,
        "academicYear": year,
        "status": data.status or "ASSIGNED",
        "createdAt": now_iso,
    }


# =========================================================================
# ROUTE 3: PUT /api/homework/{id}
# =========================================================================
@router.put("/api/homework/{id}")
async def update_homework(
    id: str,
    data: HomeworkInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _require_write(user)
    tenant = await _tenant(db, user, x_tenant_id)

    existing = await _one(
        db,
        "SELECT id FROM homework WHERE tenant_id = ? AND id = ? AND deleted_at IS NULL",
        tenant, id,
    )
    if not existing:
        raise HTTPException(status_code=404, detail="Homework not found")

    year = _year(data.academicYear or "2026-2027")

    await db.prepare(
        "UPDATE homework SET title = ?, description = ?, class_name = ?, "
        "subject = ?, due_date = ?, academic_year = ?, status = ? "
        "WHERE tenant_id = ? AND id = ?"
    ).bind(
        data.title.strip(),
        data.description.strip(),
        data.className.strip(),
        data.subject.strip(),
        data.dueDate.strip(),
        year,
        data.status or "ASSIGNED",
        tenant,
        id,
    ).run()

    updated = await _one(
        db,
        "SELECT * FROM homework WHERE tenant_id = ? AND id = ?",
        tenant, id,
    )
    return _wire(updated)


# =========================================================================
# ROUTE 4: DELETE /api/homework/{id}
# =========================================================================
@router.delete("/api/homework/{id}")
async def delete_homework(
    id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _require_write(user)
    tenant = await _tenant(db, user, x_tenant_id)

    now_iso = datetime.now(timezone.utc).isoformat()
    await db.prepare(
        "UPDATE homework SET deleted_at = ? WHERE tenant_id = ? AND id = ?"
    ).bind(now_iso, tenant, id).run()

    return {"success": True, "message": "Homework deleted"}


# =========================================================================
# ROUTE 5: GET /api/student-portal/homework
# =========================================================================
@router.get("/api/student-portal/homework")
async def get_student_portal_homework(
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)

    student_id = user.get("linkedEntityId")
    class_name = None
    if student_id:
        student = await _one(
            db,
            "SELECT class_name FROM students WHERE tenant_id = ? AND id = ?",
            tenant, student_id,
        )
        if student:
            class_name = student.get("class_name")

    query = (
        "SELECT id, tenant_id, title, description, class_name, subject, "
        "teacher_id, teacher_name, due_date, assigned_date, academic_year, "
        "status, created_at "
        "FROM homework WHERE tenant_id = ? AND deleted_at IS NULL"
    )
    params = [tenant]

    if class_name:
        query += " AND class_name = ?"
        params.append(class_name)

    query += " ORDER BY due_date DESC, created_at DESC LIMIT 50"

    rows = await _many(db, query, *params)
    return [_wire(r) for r in rows]
