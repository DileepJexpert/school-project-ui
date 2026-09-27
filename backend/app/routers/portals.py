from collections import Counter
from datetime import date
from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.access import current_user
from app.db import get_session
from app.models import Attendance, Enrollment, FeeProfile, Student, TimetableDay, User
from app.result_reporting import report_card
from app.serializers import profile_wire
from app.years import normalize_year

student_router = APIRouter(prefix="/student-portal", tags=["student-portal"])
parent_router = APIRouter(prefix="/parent", tags=["parent"])
Db = Annotated[Session, Depends(get_session)]
CurrentUser = Annotated[User, Depends(current_user)]


def _student(session: Session, user: User, student_id: str) -> Student:
    student = session.get(Student, student_id)
    if student is None or student.tenant_id != user.tenant_id:
        raise HTTPException(status_code=404, detail="Student not found")
    return student


def _own_student(session: Session, user: User) -> Student:
    if not user.linked_entity_id:
        raise HTTPException(status_code=403, detail="Student account is not linked")
    return _student(session, user, user.linked_entity_id)


def _child(session: Session, user: User, student_id: str) -> Student:
    linked = {item.strip() for item in (user.linked_entity_id or "").split(",") if item.strip()}
    if student_id not in linked:
        raise HTTPException(status_code=403, detail="Child is not linked to this account")
    return _student(session, user, student_id)


def _enrollment(session: Session, student: Student, year: str) -> Enrollment:
    enrollment = session.scalar(select(Enrollment).where(
        Enrollment.tenant_id == student.tenant_id,
        Enrollment.student_id == student.id,
        Enrollment.academic_year == year,
    ))
    if enrollment is None:
        raise HTTPException(status_code=404, detail="Enrollment not found for year")
    return enrollment


def _attendance(session: Session, student: Student, year: str, month: int | None = None, calendar_year: int | None = None) -> list[dict]:
    from app.routers.attendance import _wire

    enrollment = _enrollment(session, student, year)
    records = list(session.scalars(select(Attendance).where(
        Attendance.tenant_id == student.tenant_id,
        Attendance.enrollment_id == enrollment.id,
        Attendance.voided_at.is_(None),
    ).order_by(Attendance.date)))
    if month is not None:
        records = [item for item in records if item.date.month == month]
    if calendar_year is not None:
        records = [item for item in records if item.date.year == calendar_year]
    return [_wire(item) for item in records]


def _attendance_summary(session: Session, student: Student, year: str) -> dict:
    enrollment = _enrollment(session, student, year)
    records = list(session.scalars(select(Attendance).where(
        Attendance.tenant_id == student.tenant_id,
        Attendance.enrollment_id == enrollment.id,
        Attendance.voided_at.is_(None),
    )))
    counts = Counter(item.status for item in records)
    total = len(records)
    credited = counts["PRESENT"] + counts["LATE"] + counts["HALF_DAY"] * 0.5
    return {
        "studentId": student.id,
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


def _fees(session: Session, student: Student) -> dict:
    enrollment = _enrollment(session, student, student.academic_year)
    profile = session.scalar(select(FeeProfile).where(
        FeeProfile.tenant_id == student.tenant_id,
        FeeProfile.enrollment_id == enrollment.id,
    ))
    if profile is None:
        raise HTTPException(status_code=404, detail="Fee profile not found")
    return profile_wire(profile, student)


def _timetable(session: Session, student: Student) -> list[dict]:
    from app.routers.timetable import _wire, DAYS

    days = list(session.scalars(select(TimetableDay).where(
        TimetableDay.tenant_id == student.tenant_id,
        TimetableDay.class_name == student.class_name,
        TimetableDay.academic_year == student.academic_year,
    )))
    return [_wire(day) for day in sorted(days, key=lambda item: DAYS.index(item.day_of_week))]


def _overview(session: Session, student: Student) -> dict:
    summary = _attendance_summary(session, student, student.academic_year)
    fees = _fees(session, student)
    card = report_card(session, student.tenant_id, _enrollment(session, student, student.academic_year))
    return {
        "studentId": student.id,
        "studentName": student.full_name,
        "className": student.class_name,
        "rollNumber": student.roll_number or "",
        "admissionNumber": student.admission_number or "",
        "attendancePercentage": summary["attendancePercentage"],
        "totalPresent": summary["presentDays"],
        "totalAbsent": summary["absentDays"],
        "overallPercentage": card["cumulativePercentage"],
        "overallGrade": card["overallGrade"],
        "totalFees": fees["totalFees"],
        "paidFees": fees["paidFees"],
        "pendingFees": fees["dueFees"],
    }


def _year(value: str | None, student: Student) -> str:
    try:
        return normalize_year(value) if value else student.academic_year
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error


@student_router.get("/dashboard")
def student_dashboard(session: Db, user: CurrentUser) -> dict:
    return _overview(session, _own_student(session, user))


@student_router.get("/attendance")
def student_attendance(session: Db, user: CurrentUser, month: int | None = Query(None, ge=1, le=12), year: int | None = None) -> list[dict]:
    student = _own_student(session, user)
    return _attendance(session, student, student.academic_year, month, year)


@student_router.get("/attendance/summary")
def student_attendance_summary(session: Db, user: CurrentUser, academic_year: str | None = Query(None, alias="academicYear")) -> dict:
    student = _own_student(session, user)
    return _attendance_summary(session, student, _year(academic_year, student))


@student_router.get("/results")
def student_results(session: Db, user: CurrentUser, academic_year: str | None = Query(None, alias="academicYear")) -> dict:
    student = _own_student(session, user)
    return report_card(session, student.tenant_id, _enrollment(session, student, _year(academic_year, student)))


@student_router.get("/timetable")
def student_timetable(session: Db, user: CurrentUser) -> list[dict]:
    return _timetable(session, _own_student(session, user))


@student_router.get("/fees")
def student_fees(session: Db, user: CurrentUser) -> dict:
    return _fees(session, _own_student(session, user))


@parent_router.get("/dashboard")
def parent_dashboard(session: Db, user: CurrentUser) -> dict:
    ids = [item.strip() for item in (user.linked_entity_id or "").split(",") if item.strip()]
    children = []
    for student_id in ids:
        children.append(_overview(session, _child(session, user, student_id)))
    return {"parentName": user.full_name, "parentEmail": user.email, "children": children}


@parent_router.get("/child/{student_id}/attendance")
def child_attendance(student_id: str, session: Db, user: CurrentUser, month: int | None = Query(None, ge=1, le=12), year: int | None = None) -> list[dict]:
    student = _child(session, user, student_id)
    return _attendance(session, student, student.academic_year, month, year)


@parent_router.get("/child/{student_id}/attendance/summary")
def child_attendance_summary(student_id: str, session: Db, user: CurrentUser, academic_year: str | None = Query(None, alias="academicYear")) -> dict:
    student = _child(session, user, student_id)
    return _attendance_summary(session, student, _year(academic_year, student))


@parent_router.get("/child/{student_id}/results")
def child_results(student_id: str, session: Db, user: CurrentUser, academic_year: str | None = Query(None, alias="academicYear")) -> dict:
    student = _child(session, user, student_id)
    return report_card(session, student.tenant_id, _enrollment(session, student, _year(academic_year, student)))


@parent_router.get("/child/{student_id}/fees")
def child_fees(student_id: str, session: Db, user: CurrentUser) -> dict:
    return _fees(session, _child(session, user, student_id))


@parent_router.get("/child/{student_id}/timetable")
def child_timetable(student_id: str, session: Db, user: CurrentUser) -> list[dict]:
    return _timetable(session, _child(session, user, student_id))
