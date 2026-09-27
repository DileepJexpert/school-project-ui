from collections import Counter
from datetime import date, datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_session
from app.dependencies import lock_tenant, require_tenant, tenant_id
from app.models import Attendance, Enrollment, Student
from app.schemas import AttendanceBulkInput
from app.years import academic_year_for_date, normalize_year

router = APIRouter(prefix="/attendance", tags=["attendance"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]


def _wire(record: Attendance) -> dict:
    enrollment = record.enrollment
    return {
        "id": record.id,
        "studentId": enrollment.student_id,
        "studentName": enrollment.student.full_name,
        "className": enrollment.class_name,
        "academicYear": enrollment.academic_year,
        "date": record.date.isoformat(),
        "status": record.status,
        "markedBy": record.marked_by,
        "remarks": record.remarks,
    }


def _range_is_valid(from_date: date, to_date: date) -> None:
    if from_date > to_date:
        raise HTTPException(status_code=422, detail="from must be before to")


@router.post("/mark")
def mark_bulk(data: AttendanceBulkInput, session: Db, tenant: TenantId) -> list[dict]:
    if academic_year_for_date(data.date) != data.academic_year:
        raise HTTPException(status_code=422, detail="Attendance date does not match academic year")
    with session.begin():
        lock_tenant(session, tenant)
        enrollments = list(session.scalars(
            select(Enrollment).where(
                Enrollment.tenant_id == tenant,
                Enrollment.class_name == data.class_name,
                Enrollment.academic_year == data.academic_year,
                Enrollment.date_of_admission <= data.date,
            ).order_by(Enrollment.student_id)
        ))
        expected = {item.student_id for item in enrollments}
        submitted = {item.student_id for item in data.entries}
        if not expected or submitted != expected:
            raise HTTPException(status_code=409, detail="Roster does not match class and academic year")
        by_student = {item.student_id: item for item in enrollments}
        existing = {
            record.enrollment_id: record
            for record in session.scalars(
                select(Attendance).where(
                    Attendance.tenant_id == tenant,
                    Attendance.date == data.date,
                    Attendance.enrollment_id.in_([item.id for item in enrollments]),
                ).with_for_update()
            )
        }
        saved = []
        for entry in data.entries:
            enrollment = by_student[entry.student_id]
            record = existing.get(enrollment.id)
            if record is None:
                record = Attendance(tenant_id=tenant, enrollment=enrollment, date=data.date)
                session.add(record)
            record.status = entry.status
            record.marked_by = data.marked_by.strip()
            record.remarks = entry.remarks
            record.updated_at = datetime.now(timezone.utc)
            record.voided_at = None
            saved.append(record)
        session.flush()
        result = [_wire(item) for item in saved]
    return result


@router.get("/class/{class_name}/range")
def class_range(
    class_name: str,
    session: Db,
    tenant: TenantId,
    from_date: date = Query(alias="from"),
    to_date: date = Query(alias="to"),
    academic_year: str = Query(alias="academicYear"),
) -> list[dict]:
    require_tenant(session, tenant)
    _range_is_valid(from_date, to_date)
    try:
        year = normalize_year(academic_year)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    return [_wire(record) for record in session.scalars(
        select(Attendance).join(Enrollment).where(
            Attendance.tenant_id == tenant,
            Attendance.voided_at.is_(None),
            Attendance.date >= from_date,
            Attendance.date <= to_date,
            Enrollment.tenant_id == tenant,
            Enrollment.class_name == class_name,
            Enrollment.academic_year == year,
        ).order_by(Attendance.date, Enrollment.student_id)
    )]


@router.get("/class/{class_name}")
def class_date(class_name: str, date: date, session: Db, tenant: TenantId) -> list[dict]:
    require_tenant(session, tenant)
    year = academic_year_for_date(date)
    return [_wire(record) for record in session.scalars(
        select(Attendance).join(Enrollment).where(
            Attendance.tenant_id == tenant,
            Attendance.voided_at.is_(None),
            Attendance.date == date,
            Enrollment.tenant_id == tenant,
            Enrollment.class_name == class_name,
            Enrollment.academic_year == year,
        ).order_by(Enrollment.student_id)
    )]


@router.get("/student/{student_id}/summary")
def student_summary(
    student_id: str, session: Db, tenant: TenantId,
    academic_year: str = Query(alias="academicYear"),
) -> dict:
    require_tenant(session, tenant)
    try:
        year = normalize_year(academic_year)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    student = session.get(Student, student_id)
    if student is None or student.tenant_id != tenant:
        raise HTTPException(status_code=404, detail="Student not found")
    enrollment = session.scalar(select(Enrollment).where(
        Enrollment.tenant_id == tenant,
        Enrollment.student_id == student_id,
        Enrollment.academic_year == year,
    ))
    if enrollment is None:
        raise HTTPException(status_code=404, detail="Enrollment not found for year")
    records = list(session.scalars(select(Attendance).where(
        Attendance.tenant_id == tenant,
        Attendance.enrollment_id == enrollment.id,
        Attendance.voided_at.is_(None),
    )))
    counts = Counter(item.status for item in records)
    total = len(records)
    credited = counts["PRESENT"] + counts["LATE"] + 0.5 * counts["HALF_DAY"]
    return {
        "studentId": student_id,
        "studentName": student.full_name,
        "className": enrollment.class_name,
        "academicYear": year,
        "totalDays": total,
        "presentDays": counts["PRESENT"],
        "absentDays": counts["ABSENT"],
        "lateDays": counts["LATE"],
        "halfDays": counts["HALF_DAY"],
        "attendancePercentage": round(100 * credited / total, 2) if total else 0.0,
    }


@router.get("/student/{student_id}")
def student_range(
    student_id: str, session: Db, tenant: TenantId,
    from_date: date = Query(alias="from"), to_date: date = Query(alias="to"),
) -> list[dict]:
    require_tenant(session, tenant)
    _range_is_valid(from_date, to_date)
    student = session.get(Student, student_id)
    if student is None or student.tenant_id != tenant:
        raise HTTPException(status_code=404, detail="Student not found")
    return [_wire(record) for record in session.scalars(
        select(Attendance).join(Enrollment).where(
            Attendance.tenant_id == tenant,
            Attendance.voided_at.is_(None),
            Attendance.date >= from_date,
            Attendance.date <= to_date,
            Enrollment.tenant_id == tenant,
            Enrollment.student_id == student_id,
        ).order_by(Attendance.date)
    )]


@router.delete("/{record_id}", status_code=204)
def void_attendance(record_id: str, session: Db, tenant: TenantId) -> Response:
    with session.begin():
        require_tenant(session, tenant)
        record = session.scalar(select(Attendance).where(
            Attendance.id == record_id, Attendance.tenant_id == tenant,
            Attendance.voided_at.is_(None),
        ).with_for_update())
        if record is None:
            raise HTTPException(status_code=404, detail="Attendance not found")
        record.voided_at = datetime.now(timezone.utc)
    return Response(status_code=204)
