"""D1-backed student attendance management endpoints for Flutter admin and staff."""

from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response
from pydantic import BaseModel, Field

from school_auth import _db, get_current_user
from school_overview import _many, _one, _tenant


router = APIRouter(prefix="/api/attendance", tags=["attendance"])


class AttendanceEntryInput(BaseModel):
    studentId: str
    studentName: str | None = None
    status: str = "PRESENT"
    remarks: str | None = ""


class BulkAttendanceInput(BaseModel):
    className: str
    academicYear: str
    date: str
    markedBy: str = "Staff"
    entries: list[AttendanceEntryInput] = Field(default_factory=list)


def _require_read(user: dict) -> None:
    permissions = user.get("permissions") or []
    role = user.get("role") or ""
    if (
        "*" not in permissions
        and "attendance:read" not in permissions
        and "attendance:write" not in permissions
        and role not in ("ADMIN", "SUPER_ADMIN", "TEACHER", "PRINCIPAL", "STAFF")
    ):
        raise HTTPException(status_code=403, detail="Attendance read access required")


def _require_write(user: dict) -> None:
    permissions = user.get("permissions") or []
    role = user.get("role") or ""
    if (
        "*" not in permissions
        and "attendance:write" not in permissions
        and role not in ("ADMIN", "SUPER_ADMIN", "TEACHER", "PRINCIPAL")
    ):
        raise HTTPException(status_code=403, detail="Attendance write access required")


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _normalize_year(year: str) -> str:
    y = year.strip()
    if len(y) == 7 and y[4] == "-" and y[:4].isdigit() and y[5:].isdigit():
        start = int(y[:4])
        return f"{start}-{start + 1}"
    return y


def _short_year(year: str) -> str:
    y = _normalize_year(year)
    if len(y) == 9 and y[4] == "-":
        return f"{y[:4]}-{y[7:]}"
    return y


@router.get("/class/{class_name}/range")
async def class_attendance_range(
    class_name: str,
    from_date: str = Query(alias="from"),
    to_date: str = Query(alias="to"),
    academic_year: str = Query(alias="academicYear"),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
) -> list[dict]:
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)
    if from_date > to_date:
        raise HTTPException(status_code=422, detail="from must be before to")

    norm_year = _normalize_year(academic_year)
    short_year = _short_year(academic_year)

    return await _many(
        db,
        """
        SELECT a.id,
               e.student_id AS studentId,
               COALESCE(s.full_name, '') AS studentName,
               e.class_name AS className,
               e.academic_year AS academicYear,
               a.date,
               a.status,
               a.marked_by AS markedBy,
               COALESCE(a.remarks, '') AS remarks
        FROM attendance a
        JOIN enrollments e ON e.id = a.enrollment_id AND e.tenant_id = a.tenant_id
        LEFT JOIN students s ON s.id = e.student_id AND s.tenant_id = a.tenant_id
        WHERE a.tenant_id = ?
          AND a.voided_at IS NULL
          AND LOWER(e.class_name) = LOWER(?)
          AND (e.academic_year = ? OR e.academic_year = ?)
          AND a.date >= ?
          AND a.date <= ?
        ORDER BY a.date ASC, s.full_name ASC
        """,
        tenant,
        class_name.strip(),
        norm_year,
        short_year,
        from_date.strip(),
        to_date.strip(),
    )


@router.get("/class/{class_name}")
async def class_attendance_date(
    class_name: str,
    date: str = Query(...),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
) -> list[dict]:
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)

    return await _many(
        db,
        """
        SELECT a.id,
               e.student_id AS studentId,
               COALESCE(s.full_name, '') AS studentName,
               e.class_name AS className,
               e.academic_year AS academicYear,
               a.date,
               a.status,
               a.marked_by AS markedBy,
               COALESCE(a.remarks, '') AS remarks
        FROM attendance a
        JOIN enrollments e ON e.id = a.enrollment_id AND e.tenant_id = a.tenant_id
        LEFT JOIN students s ON s.id = e.student_id AND s.tenant_id = a.tenant_id
        WHERE a.tenant_id = ?
          AND a.voided_at IS NULL
          AND LOWER(e.class_name) = LOWER(?)
          AND a.date = ?
        ORDER BY s.full_name ASC
        """,
        tenant,
        class_name.strip(),
        date.strip(),
    )


@router.post("/mark")
async def mark_bulk_attendance(
    data: BulkAttendanceInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
) -> list[dict]:
    _require_write(user)
    tenant = await _tenant(db, user, x_tenant_id)

    class_name = data.className.strip()
    academic_year = data.academicYear.strip()
    date_str = data.date.strip()
    marked_by = data.markedBy.strip() or (user.get("fullName") or "Staff")

    if not data.entries:
        return []

    norm_year = _normalize_year(academic_year)
    short_year = _short_year(academic_year)

    # Get student IDs from entries
    student_ids = [e.studentId for e in data.entries]
    placeholders = ",".join(["?"] * len(student_ids))

    # Fetch existing enrollments for these students in this academic year
    enrollment_rows = await _many(
        db,
        f"""
        SELECT id, student_id, class_name
        FROM enrollments
        WHERE tenant_id = ? AND (academic_year = ? OR academic_year = ?) AND student_id IN ({placeholders})
        """,
        tenant,
        norm_year,
        short_year,
        *student_ids,
    )
    enrollment_map = {row["student_id"]: row["id"] for row in enrollment_rows}

    now_iso = _utc_now()
    batch_statements = []

    # Check for missing enrollments and auto-create them if needed
    for entry in data.entries:
        if entry.studentId not in enrollment_map:
            # Check student details
            st = await _one(
                db,
                "SELECT id, class_name, roll_number, date_of_admission FROM students WHERE tenant_id = ? AND id = ?",
                tenant,
                entry.studentId,
            )
            enrollment_id = uuid4().hex
            date_of_admission = (st.get("date_of_admission") if st else None) or date_str
            roll_no = (st.get("roll_number") if st else "") or ""
            c_name = (st.get("class_name") if st else None) or class_name

            await db.prepare(
                """
                INSERT INTO enrollments (id, tenant_id, student_id, academic_year, class_name, roll_number, date_of_admission, status)
                VALUES (?, ?, ?, ?, ?, ?, ?, 'ACTIVE')
                """
            ).bind(enrollment_id, tenant, entry.studentId, academic_year, c_name, roll_no, date_of_admission).run()
            enrollment_map[entry.studentId] = enrollment_id

    # Now prepare upsert statements for attendance
    for entry in data.entries:
        enrollment_id = enrollment_map[entry.studentId]
        record_id = uuid4().hex
        status = (entry.status or "PRESENT").strip().upper()
        remarks = (entry.remarks or "").strip()

        batch_statements.append(
            db.prepare(
                """
                INSERT INTO attendance (id, tenant_id, enrollment_id, date, status, marked_by, remarks, updated_at, voided_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)
                ON CONFLICT(tenant_id, enrollment_id, date) DO UPDATE SET
                    status = excluded.status,
                    marked_by = excluded.marked_by,
                    remarks = excluded.remarks,
                    updated_at = excluded.updated_at,
                    voided_at = NULL
                """
            ).bind(record_id, tenant, enrollment_id, date_str, status, marked_by, remarks, now_iso)
        )

    if batch_statements:
        await db.batch(batch_statements)

    # Return refreshed attendance for this class and date
    return await _many(
        db,
        """
        SELECT a.id,
               e.student_id AS studentId,
               COALESCE(s.full_name, '') AS studentName,
               e.class_name AS className,
               e.academic_year AS academicYear,
               a.date,
               a.status,
               a.marked_by AS markedBy,
               COALESCE(a.remarks, '') AS remarks
        FROM attendance a
        JOIN enrollments e ON e.id = a.enrollment_id AND e.tenant_id = a.tenant_id
        LEFT JOIN students s ON s.id = e.student_id AND s.tenant_id = a.tenant_id
        WHERE a.tenant_id = ?
          AND a.voided_at IS NULL
          AND LOWER(e.class_name) = LOWER(?)
          AND a.date = ?
        ORDER BY s.full_name ASC
        """,
        tenant,
        class_name,
        date_str,
    )


@router.get("/student/{student_id}/summary")
async def student_attendance_summary(
    student_id: str,
    academic_year: str = Query(alias="academicYear"),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
) -> dict:
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)

    student = await _one(
        db,
        "SELECT id, full_name, class_name FROM students WHERE tenant_id = ? AND id = ?",
        tenant,
        student_id,
    )
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    norm_year = _normalize_year(academic_year)
    short_year = _short_year(academic_year)

    records = await _many(
        db,
        """
        SELECT a.status
        FROM attendance a
        JOIN enrollments e ON e.id = a.enrollment_id AND e.tenant_id = a.tenant_id
        WHERE a.tenant_id = ?
          AND a.voided_at IS NULL
          AND e.student_id = ?
          AND (e.academic_year = ? OR e.academic_year = ?)
        """,
        tenant,
        student_id,
        norm_year,
        short_year,
    )

    total = len(records)
    present = sum(1 for r in records if r["status"] == "PRESENT")
    absent = sum(1 for r in records if r["status"] == "ABSENT")
    late = sum(1 for r in records if r["status"] == "LATE")
    half = sum(1 for r in records if r["status"] == "HALF_DAY")
    credited = present + late + (0.5 * half)
    percentage = round((100.0 * credited / total), 2) if total > 0 else 0.0

    return {
        "studentId": student_id,
        "studentName": student.get("full_name") or "",
        "className": student.get("class_name") or "",
        "academicYear": academic_year.strip(),
        "totalDays": total,
        "presentDays": present,
        "absentDays": absent,
        "lateDays": late,
        "halfDays": half,
        "attendancePercentage": percentage,
    }


@router.get("/student/{student_id}")
async def student_attendance_range(
    student_id: str,
    from_date: str = Query(alias="from"),
    to_date: str = Query(alias="to"),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
) -> list[dict]:
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)
    if from_date > to_date:
        raise HTTPException(status_code=422, detail="from must be before to")

    return await _many(
        db,
        """
        SELECT a.id,
               e.student_id AS studentId,
               COALESCE(s.full_name, '') AS studentName,
               e.class_name AS className,
               e.academic_year AS academicYear,
               a.date,
               a.status,
               a.marked_by AS markedBy,
               COALESCE(a.remarks, '') AS remarks
        FROM attendance a
        JOIN enrollments e ON e.id = a.enrollment_id AND e.tenant_id = a.tenant_id
        LEFT JOIN students s ON s.id = e.student_id AND s.tenant_id = a.tenant_id
        WHERE a.tenant_id = ?
          AND a.voided_at IS NULL
          AND e.student_id = ?
          AND a.date >= ?
          AND a.date <= ?
        ORDER BY a.date ASC
        """,
        tenant,
        student_id,
        from_date.strip(),
        to_date.strip(),
    )


@router.delete("/{record_id}", status_code=204)
async def delete_attendance_record(
    record_id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _require_write(user)
    tenant = await _tenant(db, user, x_tenant_id)

    rec = await _one(
        db,
        "SELECT id FROM attendance WHERE tenant_id = ? AND id = ? AND voided_at IS NULL",
        tenant,
        record_id,
    )
    if not rec:
        raise HTTPException(status_code=404, detail="Attendance record not found")

    await db.prepare(
        "UPDATE attendance SET voided_at = ? WHERE tenant_id = ? AND id = ?"
    ).bind(_utc_now(), tenant, record_id).run()

    return Response(status_code=204)
