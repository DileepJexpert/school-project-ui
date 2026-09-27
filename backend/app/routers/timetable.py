from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.admissions import require_open_class_year
from app.db import get_session
from app.dependencies import lock_tenant, require_tenant, tenant_id
from app.models import TimetableDay, TimetablePeriod
from app.schemas import TimetableDayInput
from app.years import normalize_year

router = APIRouter(prefix="/timetable", tags=["timetable"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]
DAYS = ("MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY")


def _wire(day: TimetableDay) -> dict:
    return {
        "id": day.id,
        "className": day.class_name,
        "academicYear": day.academic_year,
        "dayOfWeek": day.day_of_week,
        "periods": [
            {
                "periodNumber": period.period_number,
                "subject": period.subject,
                "teacherName": period.teacher_name,
                "startTime": period.start_time.strftime("%H:%M"),
                "endTime": period.end_time.strftime("%H:%M"),
            }
            for period in day.periods
        ],
    }


@router.get("/{class_name}")
def class_timetable(class_name: str, session: Db, tenant: TenantId, academic_year: str = Query(alias="academicYear")) -> list[dict]:
    require_tenant(session, tenant)
    try:
        year = normalize_year(academic_year)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    days = list(session.scalars(select(TimetableDay).where(
        TimetableDay.tenant_id == tenant,
        TimetableDay.class_name == class_name,
        TimetableDay.academic_year == year,
    )))
    return [_wire(item) for item in sorted(days, key=lambda item: DAYS.index(item.day_of_week))]


@router.post("")
def save_day(data: TimetableDayInput, session: Db, tenant: TenantId) -> dict:
    try:
        with session.begin():
            lock_tenant(session, tenant)
            require_open_class_year(session, tenant, data.class_name, data.academic_year)
            day = session.scalar(select(TimetableDay).where(
                TimetableDay.tenant_id == tenant,
                TimetableDay.class_name == data.class_name,
                TimetableDay.academic_year == data.academic_year,
                TimetableDay.day_of_week == data.day_of_week,
            ))
            if data.id:
                by_id = session.get(TimetableDay, data.id)
                if by_id is None or by_id.tenant_id != tenant:
                    raise HTTPException(status_code=404, detail="Timetable day not found")
                if by_id.class_name != data.class_name or by_id.academic_year != data.academic_year:
                    raise HTTPException(status_code=409, detail="Timetable ID belongs to another class or year")
                if day is not None and day.id != by_id.id:
                    raise HTTPException(status_code=409, detail="Target day already has a timetable")
                day = by_id
            if day is None:
                day = TimetableDay(
                    tenant_id=tenant,
                    class_name=data.class_name,
                    academic_year=data.academic_year,
                    day_of_week=data.day_of_week,
                )
                session.add(day)

            others = list(session.scalars(
                select(TimetablePeriod).join(TimetableDay).where(
                    TimetableDay.tenant_id == tenant,
                    TimetableDay.academic_year == data.academic_year,
                    TimetableDay.day_of_week == data.day_of_week,
                    TimetableDay.id != day.id,
                )
            ))
            for period in data.periods:
                for other in others:
                    if (
                        period.teacher_name.casefold() == other.teacher_name.casefold()
                        and period.start_time < other.end_time
                        and other.start_time < period.end_time
                    ):
                        raise HTTPException(status_code=409, detail=f"Teacher {period.teacher_name} has an overlapping period")
            day.day_of_week = data.day_of_week
            day.periods.clear()
            session.flush()
            day.periods = [
                TimetablePeriod(
                    period_number=item.period_number,
                    subject=item.subject,
                    teacher_name=item.teacher_name,
                    start_time=item.start_time,
                    end_time=item.end_time,
                )
                for item in data.periods
            ]
            session.flush()
            result = _wire(day)
        return result
    except IntegrityError as error:
        raise HTTPException(status_code=409, detail="Timetable conflicts with an existing entry") from error


@router.delete("/entry/{day_id}", status_code=204)
def delete_day(day_id: str, session: Db, tenant: TenantId) -> Response:
    with session.begin():
        lock_tenant(session, tenant)
        day = session.get(TimetableDay, day_id)
        if day is None or day.tenant_id != tenant:
            raise HTTPException(status_code=404, detail="Timetable day not found")
        require_open_class_year(session, tenant, day.class_name, day.academic_year)
        session.delete(day)
    return Response(status_code=204)


@router.delete("/{class_name}", status_code=204)
def delete_class(class_name: str, session: Db, tenant: TenantId, academic_year: str = Query(alias="academicYear")) -> Response:
    try:
        year = normalize_year(academic_year)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    with session.begin():
        lock_tenant(session, tenant)
        require_open_class_year(session, tenant, class_name, year)
        days = list(session.scalars(select(TimetableDay).where(
            TimetableDay.tenant_id == tenant,
            TimetableDay.class_name == class_name,
            TimetableDay.academic_year == year,
        )))
        for day in days:
            session.delete(day)
    return Response(status_code=204)
