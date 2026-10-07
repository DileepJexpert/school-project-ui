"""Timetable and schedule management endpoints for classes and subjects."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel, Field

from school_auth import _db, get_current_user, require_admin
from school_overview import _many, _one, _tenant

router = APIRouter(prefix="/api/timetable", tags=["timetable"])
root_router = APIRouter(prefix="/timetable", tags=["timetable_root"])


class PeriodInput(BaseModel):
    periodNumber: int = Field(ge=1, le=15)
    subject: str = Field(min_length=1, max_length=120)
    teacherName: str = Field(min_length=1, max_length=200)
    startTime: str = Field(min_length=1, max_length=10)
    endTime: str = Field(min_length=1, max_length=10)


class TimetableInput(BaseModel):
    id: str | None = None
    className: str = Field(min_length=1, max_length=80)
    academicYear: str = Field(min_length=1, max_length=9)
    dayOfWeek: str = Field(min_length=1, max_length=16)
    periods: list[PeriodInput] = Field(default_factory=list)


def _wire_period(p: dict) -> dict:
    return {
        "id": p.get("id"),
        "periodNumber": p["period_number"],
        "subject": p["subject"],
        "teacherName": p["teacher_name"],
        "startTime": p["start_time"],
        "endTime": p["end_time"],
    }


async def _handle_get_class_timetable(
    className: str,
    academicYear: str | None = Query(default=None),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    year = academicYear.strip() if academicYear and academicYear.strip() else "2026-2027"

    day_rows = await _many(
        db,
        "SELECT * FROM timetable_days WHERE tenant_id = ? AND class_name = ? AND academic_year = ?",
        tenant, className.strip(), year,
    )
    if not day_rows:
        return []

    day_ids = [d["id"] for d in day_rows]
    placeholders = ",".join("?" for _ in day_ids)
    periods_rows = await _many(
        db,
        f"SELECT * FROM timetable_periods WHERE day_id IN ({placeholders}) ORDER BY period_number ASC",
        *day_ids,
    )

    periods_by_day: dict[str, list[dict]] = {d["id"]: [] for d in day_rows}
    for p in periods_rows:
        did = p.get("day_id")
        if did in periods_by_day:
            periods_by_day[did].append(_wire_period(p))

    day_order = {"Monday": 1, "Tuesday": 2, "Wednesday": 3, "Thursday": 4, "Friday": 5, "Saturday": 6, "Sunday": 7}
    result = []
    for d in day_rows:
        result.append({
            "id": d["id"],
            "className": d["class_name"],
            "academicYear": d["academic_year"],
            "dayOfWeek": d["day_of_week"],
            "periods": periods_by_day.get(d["id"], []),
        })

    result.sort(key=lambda x: day_order.get(x["dayOfWeek"], 99))
    return result


async def _handle_save_timetable(
    data: TimetableInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    class_name = data.className.strip()
    academic_year = data.academicYear.strip()
    day_of_week = data.dayOfWeek.strip().title()

    existing_day = await _one(
        db,
        "SELECT id FROM timetable_days WHERE tenant_id = ? AND class_name = ? AND academic_year = ? AND day_of_week = ?",
        tenant, class_name, academic_year, day_of_week,
    )

    if existing_day:
        day_id = existing_day["id"]
        # Clear existing periods for this day
        await db.prepare("DELETE FROM timetable_periods WHERE day_id = ?").bind(day_id).run()
    else:
        day_id = f"td_{uuid.uuid4().hex[:16]}"
        await db.prepare(
            "INSERT INTO timetable_days (id, tenant_id, class_name, academic_year, day_of_week) "
            "VALUES (?, ?, ?, ?, ?)"
        ).bind(day_id, tenant, class_name, academic_year, day_of_week).run()

    # Insert new periods
    for p in data.periods:
        pid = f"tp_{uuid.uuid4().hex[:16]}"
        await db.prepare(
            "INSERT INTO timetable_periods (id, day_id, period_number, subject, teacher_name, start_time, end_time) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)"
        ).bind(pid, day_id, p.periodNumber, p.subject.strip(), p.teacherName.strip(), p.startTime.strip(), p.endTime.strip()).run()

    periods_rows = await _many(
        db,
        "SELECT * FROM timetable_periods WHERE day_id = ? ORDER BY period_number ASC",
        day_id,
    )
    return {
        "id": day_id,
        "className": class_name,
        "academicYear": academic_year,
        "dayOfWeek": day_of_week,
        "periods": [_wire_period(p) for p in periods_rows],
    }


async def _handle_delete_entry(
    id: str,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    # Check if it's a period or a day
    period = await _one(db, "SELECT id FROM timetable_periods WHERE id = ?", id.strip())
    if period:
        await db.prepare("DELETE FROM timetable_periods WHERE id = ?").bind(id.strip()).run()
        return {"message": "Period deleted successfully"}

    day = await _one(db, "SELECT id FROM timetable_days WHERE id = ? AND tenant_id = ?", id.strip(), tenant)
    if day:
        await db.prepare("DELETE FROM timetable_periods WHERE day_id = ?").bind(id.strip()).run()
        await db.prepare("DELETE FROM timetable_days WHERE id = ? AND tenant_id = ?").bind(id.strip(), tenant).run()
        return {"message": "Timetable day deleted successfully"}

    return {"message": "Entry deleted"}


async def _handle_delete_class_timetable(
    className: str,
    academicYear: str | None = Query(default=None),
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    year = academicYear.strip() if academicYear and academicYear.strip() else "2026-2027"

    day_rows = await _many(
        db,
        "SELECT id FROM timetable_days WHERE tenant_id = ? AND class_name = ? AND academic_year = ?",
        tenant, className.strip(), year,
    )
    for d in day_rows:
        await db.prepare("DELETE FROM timetable_periods WHERE day_id = ?").bind(d["id"]).run()
    await db.prepare(
        "DELETE FROM timetable_days WHERE tenant_id = ? AND class_name = ? AND academic_year = ?"
    ).bind(tenant, className.strip(), year).run()

    return {"message": "Class timetable deleted successfully"}


# Routes
for r in (router, root_router):
    r.add_api_route("/{className}", _handle_get_class_timetable, methods=["GET"])
    r.add_api_route("", _handle_save_timetable, methods=["POST"])
    r.add_api_route("/entry/{id}", _handle_delete_entry, methods=["DELETE"])
    r.add_api_route("/{className}", _handle_delete_class_timetable, methods=["DELETE"])
