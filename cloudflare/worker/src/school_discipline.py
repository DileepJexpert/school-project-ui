"""Discipline and incident reporting endpoints for student conduct tracking."""

from __future__ import annotations

from datetime import datetime, timezone
import uuid

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel, Field

from school_auth import _db, get_current_user, require_admin
from school_overview import _many, _one, _tenant

router = APIRouter(prefix="/api/discipline", tags=["discipline"])
root_router = APIRouter(prefix="/discipline", tags=["discipline_root"])


def _wire_incident(row: dict) -> dict:
    return {
        "id": row["id"],
        "studentId": row["student_id"],
        "studentName": row["student_name"],
        "className": row["class_name"],
        "academicYear": row["academic_year"],
        "severity": (row.get("severity") or "MINOR").upper(),
        "category": (row.get("category") or "BEHAVIORAL").upper(),
        "description": row.get("description") or "",
        "actionTaken": row.get("action_taken") or "",
        "reportedBy": row.get("reported_by") or "",
        "incidentDate": row.get("incident_date") or "",
        "parentNotified": bool(row.get("parent_notified")),
        "parentNotifiedAt": row.get("parent_notified_at"),
        "followUpNotes": row.get("follow_up_notes") or "",
        "resolution": row.get("follow_up_notes") or "",
        "resolved": bool(row.get("resolved")),
        "resolvedAt": row.get("resolved_at"),
        "createdAt": row.get("created_at") or "",
    }


class CreateIncidentInput(BaseModel):
    studentId: str = Field(min_length=1)
    studentName: str = Field(default="")
    className: str = Field(default="General")
    academicYear: str = Field(default="2026-2027")
    severity: str = Field(default="MINOR")
    category: str = Field(default="BEHAVIORAL")
    description: str = Field(min_length=1)
    actionTaken: str = Field(default="")
    reportedBy: str = Field(default="")
    incidentDate: str | None = None
    parentNotified: bool = Field(default=False)


class ResolveIncidentInput(BaseModel):
    resolution: str = Field(min_length=1)


async def _handle_list_incidents(
    className: str | None = Query(default=None),
    severity: str | None = Query(default=None),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    query = "SELECT * FROM incidents WHERE tenant_id = ?"
    params = [tenant]

    if className and className.strip() and className.strip().upper() != "ALL":
        query += " AND class_name = ?"
        params.append(className.strip())

    if severity and severity.strip() and severity.strip().upper() != "ALL":
        query += " AND UPPER(severity) = ?"
        params.append(severity.strip().upper())

    query += " ORDER BY incident_date DESC, created_at DESC"
    rows = await _many(db, query, *params)
    return [_wire_incident(r) for r in rows]


async def _handle_get_summary(
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    all_rows = await _many(db, "SELECT severity, category, resolved FROM incidents WHERE tenant_id = ?", tenant)

    total = len(all_rows)
    open_count = sum(1 for r in all_rows if not r.get("resolved"))
    resolved_count = sum(1 for r in all_rows if r.get("resolved"))

    severities = ["WARNING", "MINOR", "MAJOR", "CRITICAL"]
    by_severity = {s: 0 for s in severities}
    for r in all_rows:
        sev = (r.get("severity") or "MINOR").upper()
        if sev in by_severity:
            by_severity[sev] += 1
        else:
            by_severity[sev] = 1

    by_category: dict[str, int] = {}
    for r in all_rows:
        cat = (r.get("category") or "OTHER").upper()
        by_category[cat] = by_category.get(cat, 0) + 1

    return {
        "total": total,
        "open": open_count,
        "resolved": resolved_count,
        "bySeverity": by_severity,
        "byCategory": by_category,
    }


async def _handle_create_incident(
    data: CreateIncidentInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    student_id = data.studentId.strip()

    # Lookup student if name/class not passed
    student = await _one(
        db,
        "SELECT id, full_name, class_name, academic_year FROM students WHERE tenant_id = ? AND (id = ? OR admission_number = ?)",
        tenant, student_id, student_id,
    )
    student_name = data.studentName.strip() or (student.get("full_name") if student else "Student")
    class_name = data.className.strip() or (student.get("class_name") if student else "General")
    academic_year = data.academicYear.strip() or (student.get("academic_year") if student else "2026-2027")
    actual_student_id = student["id"] if student else student_id

    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()
    incident_date = data.incidentDate or now.strftime("%Y-%m-%d")
    incident_id = f"inc_{uuid.uuid4().hex[:16]}"
    reported_by = data.reportedBy.strip() or user.get("fullName") or "Staff"

    await db.prepare(
        "INSERT INTO incidents ("
        "id, tenant_id, student_id, student_name, class_name, academic_year, "
        "severity, category, description, action_taken, reported_by, incident_date, "
        "parent_notified, parent_notified_at, follow_up_notes, resolved, resolved_at, created_at"
        ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    ).bind(
        incident_id,
        tenant,
        actual_student_id,
        student_name,
        class_name,
        academic_year,
        data.severity.strip().upper(),
        data.category.strip().upper(),
        data.description.strip(),
        data.actionTaken.strip(),
        reported_by,
        incident_date,
        1 if data.parentNotified else 0,
        now_iso if data.parentNotified else None,
        "",
        0,
        None,
        now_iso,
    ).run()

    created = await _one(db, "SELECT * FROM incidents WHERE id = ? AND tenant_id = ?", incident_id, tenant)
    return _wire_incident(created)


async def _handle_get_student_incidents(
    student_id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    rows = await _many(
        db,
        "SELECT * FROM incidents WHERE tenant_id = ? AND student_id = ? ORDER BY incident_date DESC",
        tenant, student_id.strip(),
    )
    return [_wire_incident(r) for r in rows]


async def _handle_resolve_incident(
    id: str,
    data: ResolveIncidentInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    now_iso = datetime.now(timezone.utc).isoformat()
    await db.prepare(
        "UPDATE incidents SET resolved = 1, resolved_at = ?, follow_up_notes = ? WHERE id = ? AND tenant_id = ?"
    ).bind(now_iso, data.resolution.strip(), id.strip(), tenant).run()

    row = await _one(db, "SELECT * FROM incidents WHERE id = ? AND tenant_id = ?", id.strip(), tenant)
    if not row:
        raise HTTPException(status_code=404, detail="Incident not found")
    return _wire_incident(row)


# Routes
for r in (router, root_router):
    r.add_api_route("", _handle_list_incidents, methods=["GET"])
    r.add_api_route("", _handle_create_incident, methods=["POST"], status_code=201)
    r.add_api_route("/summary", _handle_get_summary, methods=["GET"])
    r.add_api_route("/student/{student_id}", _handle_get_student_incidents, methods=["GET"])
    r.add_api_route("/{id}/resolve", _handle_resolve_incident, methods=["PUT"])
