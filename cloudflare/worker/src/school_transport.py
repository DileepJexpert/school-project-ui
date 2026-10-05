"""D1-backed bus, route, and student transport management endpoints."""

from __future__ import annotations

from datetime import datetime, timezone
import json
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response
from pydantic import BaseModel, Field

from school_auth import _db, get_current_user
from school_overview import _many, _one, _tenant


router = APIRouter(prefix="/api/transport", tags=["transport"])


class BusInput(BaseModel):
    busNumber: str = Field(min_length=1, max_length=80)
    driverName: str = Field(min_length=1, max_length=200)
    driverMobile: str = Field(min_length=1, max_length=40)
    routeId: str | None = None
    capacity: int = Field(gt=0)
    status: str = Field(default="ACTIVE")
    insuranceExpiry: str | None = None
    notes: str | None = None


class RouteInput(BaseModel):
    zoneName: str = Field(min_length=1, max_length=120)
    displayName: str | None = None
    areasCovered: str = Field(default="", max_length=1000)
    stops: list[str] = Field(default_factory=list)
    firstPickupTime: str = Field(min_length=1, max_length=40)
    monthlyFee: float = Field(ge=0)


class AssignmentInput(BaseModel):
    studentId: str
    studentName: str
    className: str
    rollNumber: str | None = None
    busId: str
    routeId: str
    pickupStop: str | None = None
    status: str = Field(default="ACTIVE")


def _require_read(user: dict) -> None:
    permissions = user.get("permissions") or []
    role = user.get("role") or ""
    if (
        "*" not in permissions
        and "transport:read" not in permissions
        and role not in ("ADMIN", "SUPER_ADMIN", "TRANSPORT_MANAGER", "STAFF")
    ):
        raise HTTPException(status_code=403, detail="Transport read access required")


def _require_write(user: dict) -> None:
    permissions = user.get("permissions") or []
    role = user.get("role") or ""
    if (
        "*" not in permissions
        and "transport:write" not in permissions
        and role not in ("ADMIN", "SUPER_ADMIN", "TRANSPORT_MANAGER")
    ):
        raise HTTPException(status_code=403, detail="Transport write access required")


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


# ── Buses ──────────────────────────────────────────────────────────────────

@router.get("/buses")
async def list_buses(
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
) -> list[dict]:
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)

    rows = await _many(
        db,
        """
        SELECT b.id, b.bus_number AS busNumber, b.driver_name AS driverName,
               b.driver_mobile AS driverMobile, b.route_id AS routeId,
               b.capacity, b.status, b.insurance_expiry AS insuranceExpiry,
               b.notes, b.created_at AS createdAt,
               (SELECT COUNT(*) FROM transport_assignments a 
                WHERE a.tenant_id = b.tenant_id AND a.bus_id = b.id AND a.status = 'ACTIVE') AS assignedCount
        FROM buses b
        WHERE b.tenant_id = ? AND b.deleted_at IS NULL
        ORDER BY b.bus_number ASC
        """,
        tenant,
    )
    return rows


@router.post("/buses", status_code=201)
async def create_bus(
    data: BusInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
) -> dict:
    _require_write(user)
    tenant = await _tenant(db, user, x_tenant_id)

    bus_num = data.busNumber.strip().upper()
    existing = await _one(
        db,
        "SELECT id FROM buses WHERE tenant_id = ? AND bus_number = ? AND deleted_at IS NULL",
        tenant, bus_num,
    )
    if existing:
        raise HTTPException(status_code=409, detail="Bus number already exists")

    bus_id = uuid4().hex
    now = _utc_now()
    await db.prepare(
        """
        INSERT INTO buses (id, tenant_id, bus_number, driver_name, driver_mobile,
                           route_id, capacity, status, insurance_expiry, notes, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
    ).bind(
        bus_id, tenant, bus_num, data.driverName.strip(),
        data.driverMobile.strip(), data.routeId, data.capacity,
        data.status, data.insuranceExpiry, data.notes, now
    ).run()

    return {
        "id": bus_id,
        "busNumber": bus_num,
        "driverName": data.driverName.strip(),
        "driverMobile": data.driverMobile.strip(),
        "routeId": data.routeId,
        "capacity": data.capacity,
        "assignedCount": 0,
        "status": data.status,
        "insuranceExpiry": data.insuranceExpiry,
        "notes": data.notes,
        "createdAt": now,
    }


@router.put("/buses/{bus_id}")
async def update_bus(
    bus_id: str,
    data: BusInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
) -> dict:
    _require_write(user)
    tenant = await _tenant(db, user, x_tenant_id)

    bus = await _one(
        db,
        "SELECT id FROM buses WHERE tenant_id = ? AND id = ? AND deleted_at IS NULL",
        tenant, bus_id,
    )
    if not bus:
        raise HTTPException(status_code=404, detail="Bus not found")

    bus_num = data.busNumber.strip().upper()
    conflict = await _one(
        db,
        "SELECT id FROM buses WHERE tenant_id = ? AND bus_number = ? AND id != ? AND deleted_at IS NULL",
        tenant, bus_num, bus_id,
    )
    if conflict:
        raise HTTPException(status_code=409, detail="Bus number already in use by another bus")

    await db.prepare(
        """
        UPDATE buses SET bus_number = ?, driver_name = ?, driver_mobile = ?,
                         route_id = ?, capacity = ?, status = ?,
                         insurance_expiry = ?, notes = ?
        WHERE tenant_id = ? AND id = ?
        """
    ).bind(
        bus_num, data.driverName.strip(), data.driverMobile.strip(),
        data.routeId, data.capacity, data.status,
        data.insuranceExpiry, data.notes, tenant, bus_id
    ).run()

    return {
        "id": bus_id,
        "busNumber": bus_num,
        "driverName": data.driverName.strip(),
        "driverMobile": data.driverMobile.strip(),
        "routeId": data.routeId,
        "capacity": data.capacity,
        "status": data.status,
        "insuranceExpiry": data.insuranceExpiry,
        "notes": data.notes,
    }


@router.delete("/buses/{bus_id}", status_code=204)
async def delete_bus(
    bus_id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _require_write(user)
    tenant = await _tenant(db, user, x_tenant_id)

    bus = await _one(
        db,
        "SELECT id FROM buses WHERE tenant_id = ? AND id = ? AND deleted_at IS NULL",
        tenant, bus_id,
    )
    if not bus:
        raise HTTPException(status_code=404, detail="Bus not found")

    await db.prepare(
        "UPDATE buses SET deleted_at = ? WHERE tenant_id = ? AND id = ?"
    ).bind(_utc_now(), tenant, bus_id).run()

    return Response(status_code=204)


# ── Routes ─────────────────────────────────────────────────────────────────

@router.get("/routes")
async def list_routes(
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
) -> list[dict]:
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)

    rows = await _many(
        db,
        """
        SELECT r.id, r.zone_name AS zoneName, r.display_name AS displayName,
               r.areas_covered AS areasCovered, r.stops, r.first_pickup_time AS firstPickupTime,
               ROUND(r.monthly_fee / 100.0, 2) AS monthlyFee, r.created_at AS createdAt,
               (SELECT COUNT(*) FROM transport_assignments a 
                WHERE a.tenant_id = r.tenant_id AND a.route_id = r.id AND a.status = 'ACTIVE') AS assignedCount
        FROM transport_routes r
        WHERE r.tenant_id = ? AND r.deleted_at IS NULL
        ORDER BY r.zone_name ASC
        """,
        tenant,
    )
    for row in rows:
        if isinstance(row.get("stops"), str):
            try:
                row["stops"] = json.loads(row["stops"])
            except Exception:
                row["stops"] = [s.strip() for s in row["stops"].split(",") if s.strip()]
        elif not isinstance(row.get("stops"), list):
            row["stops"] = []
    return rows


@router.post("/routes", status_code=201)
async def create_route(
    data: RouteInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
) -> dict:
    _require_write(user)
    tenant = await _tenant(db, user, x_tenant_id)

    zone_name = data.zoneName.strip()
    existing = await _one(
        db,
        "SELECT id FROM transport_routes WHERE tenant_id = ? AND zone_name = ? AND deleted_at IS NULL",
        tenant, zone_name,
    )
    if existing:
        raise HTTPException(status_code=409, detail="Zone name already exists")

    route_id = uuid4().hex
    now = _utc_now()
    fee_cents = int(round(data.monthlyFee * 100))
    stops_json = json.dumps(data.stops)

    await db.prepare(
        """
        INSERT INTO transport_routes (id, tenant_id, zone_name, display_name,
                                      areas_covered, stops, first_pickup_time,
                                      monthly_fee, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
    ).bind(
        route_id, tenant, zone_name, data.displayName or zone_name,
        data.areasCovered, stops_json, data.firstPickupTime.strip(),
        fee_cents, now
    ).run()

    return {
        "id": route_id,
        "zoneName": zone_name,
        "displayName": data.displayName or zone_name,
        "areasCovered": data.areasCovered,
        "stops": data.stops,
        "firstPickupTime": data.firstPickupTime.strip(),
        "monthlyFee": data.monthlyFee,
        "assignedCount": 0,
        "createdAt": now,
    }


@router.put("/routes/{route_id}")
async def update_route(
    route_id: str,
    data: RouteInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
) -> dict:
    _require_write(user)
    tenant = await _tenant(db, user, x_tenant_id)

    route = await _one(
        db,
        "SELECT id FROM transport_routes WHERE tenant_id = ? AND id = ? AND deleted_at IS NULL",
        tenant, route_id,
    )
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")

    zone_name = data.zoneName.strip()
    fee_cents = int(round(data.monthlyFee * 100))
    stops_json = json.dumps(data.stops)

    await db.prepare(
        """
        UPDATE transport_routes SET zone_name = ?, display_name = ?, areas_covered = ?,
                                    stops = ?, first_pickup_time = ?, monthly_fee = ?
        WHERE tenant_id = ? AND id = ?
        """
    ).bind(
        zone_name, data.displayName or zone_name, data.areasCovered,
        stops_json, data.firstPickupTime.strip(), fee_cents,
        tenant, route_id
    ).run()

    return {
        "id": route_id,
        "zoneName": zone_name,
        "displayName": data.displayName or zone_name,
        "areasCovered": data.areasCovered,
        "stops": data.stops,
        "firstPickupTime": data.firstPickupTime.strip(),
        "monthlyFee": data.monthlyFee,
    }


@router.delete("/routes/{route_id}", status_code=204)
async def delete_route(
    route_id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _require_write(user)
    tenant = await _tenant(db, user, x_tenant_id)

    route = await _one(
        db,
        "SELECT id FROM transport_routes WHERE tenant_id = ? AND id = ? AND deleted_at IS NULL",
        tenant, route_id,
    )
    if not route:
        raise HTTPException(status_code=404, detail="Route not found")

    await db.prepare(
        "UPDATE transport_routes SET deleted_at = ? WHERE tenant_id = ? AND id = ?"
    ).bind(_utc_now(), tenant, route_id).run()

    return Response(status_code=204)


# ── Assignments ────────────────────────────────────────────────────────────

@router.get("/assignments")
async def list_assignments(
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
) -> list[dict]:
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)

    return await _many(
        db,
        """
        SELECT a.id, a.student_id AS studentId, a.student_name AS studentName,
               a.class_name AS className, a.roll_number AS rollNumber,
               a.bus_id AS busId, a.route_id AS routeId, a.pickup_stop AS pickupStop,
               a.status, a.assigned_date AS assignedDate, a.created_at AS createdAt
        FROM transport_assignments a
        WHERE a.tenant_id = ? AND a.status = 'ACTIVE'
        ORDER BY a.class_name, a.student_name ASC
        """,
        tenant,
    )


@router.get("/assignments/bus/{bus_id}")
async def bus_roster(
    bus_id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
) -> list[dict]:
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)

    return await _many(
        db,
        """
        SELECT a.id, a.student_id AS studentId, a.student_name AS studentName,
               a.class_name AS className, a.roll_number AS rollNumber,
               a.bus_id AS busId, a.route_id AS routeId, a.pickup_stop AS pickupStop,
               a.status, a.assigned_date AS assignedDate, a.created_at AS createdAt
        FROM transport_assignments a
        WHERE a.tenant_id = ? AND a.bus_id = ? AND a.status = 'ACTIVE'
        ORDER BY a.class_name, a.student_name ASC
        """,
        tenant, bus_id,
    )


@router.get("/assignments/student/{student_id}")
async def student_assignment(
    student_id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
) -> dict | None:
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)

    row = await _one(
        db,
        """
        SELECT a.id, a.student_id AS studentId, a.student_name AS studentName,
               a.class_name AS className, a.roll_number AS rollNumber,
               a.bus_id AS busId, a.route_id AS routeId, a.pickup_stop AS pickupStop,
               a.status, a.assigned_date AS assignedDate, a.created_at AS createdAt
        FROM transport_assignments a
        WHERE a.tenant_id = ? AND a.student_id = ? AND a.status = 'ACTIVE'
        LIMIT 1
        """,
        tenant, student_id,
    )
    if not row:
        return Response(status_code=204)
    return row


@router.post("/assignments", status_code=201)
async def assign_student(
    data: AssignmentInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
) -> dict:
    _require_write(user)
    tenant = await _tenant(db, user, x_tenant_id)

    # Deactivate existing assignment if any
    now = _utc_now()
    today_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    await db.prepare(
        "UPDATE transport_assignments SET status = 'INACTIVE' WHERE tenant_id = ? AND student_id = ?"
    ).bind(tenant, data.studentId).run()

    assign_id = uuid4().hex
    await db.prepare(
        """
        INSERT INTO transport_assignments (id, tenant_id, student_id, student_name,
                                           class_name, roll_number, bus_id, route_id,
                                           pickup_stop, status, assigned_date, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
    ).bind(
        assign_id, tenant, data.studentId, data.studentName.strip(),
        data.className.strip(), data.rollNumber or "", data.busId, data.routeId,
        data.pickupStop or "", "ACTIVE", today_date, now
    ).run()

    return {
        "id": assign_id,
        "studentId": data.studentId,
        "studentName": data.studentName.strip(),
        "className": data.className.strip(),
        "rollNumber": data.rollNumber,
        "busId": data.busId,
        "routeId": data.routeId,
        "pickupStop": data.pickupStop,
        "status": "ACTIVE",
        "assignedDate": today_date,
        "createdAt": now,
    }


@router.delete("/assignments/{assignment_id}", status_code=204)
async def remove_assignment(
    assignment_id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _require_write(user)
    tenant = await _tenant(db, user, x_tenant_id)

    await db.prepare(
        "UPDATE transport_assignments SET status = 'INACTIVE' WHERE tenant_id = ? AND id = ?"
    ).bind(tenant, assignment_id).run()

    return Response(status_code=204)


# ── Transport Stats & Overview ─────────────────────────────────────────────

@router.get("/stats")
async def transport_stats(
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
) -> dict:
    _require_read(user)
    tenant = await _tenant(db, user, x_tenant_id)

    total_buses = (await _one(
        db, "SELECT COUNT(*) AS c FROM buses WHERE tenant_id = ? AND deleted_at IS NULL", tenant
    )).get("c", 0)

    active_buses = (await _one(
        db, "SELECT COUNT(*) AS c FROM buses WHERE tenant_id = ? AND status = 'ACTIVE' AND deleted_at IS NULL", tenant
    )).get("c", 0)

    maintenance_buses = (await _one(
        db, "SELECT COUNT(*) AS c FROM buses WHERE tenant_id = ? AND status = 'MAINTENANCE' AND deleted_at IS NULL", tenant
    )).get("c", 0)

    total_routes = (await _one(
        db, "SELECT COUNT(*) AS c FROM transport_routes WHERE tenant_id = ? AND deleted_at IS NULL", tenant
    )).get("c", 0)

    total_students = (await _one(
        db, "SELECT COUNT(*) AS c FROM transport_assignments WHERE tenant_id = ? AND status = 'ACTIVE'", tenant
    )).get("c", 0)

    return {
        "totalBuses": total_buses,
        "activeBuses": active_buses,
        "maintenanceBuses": maintenance_buses,
        "totalRoutes": total_routes,
        "totalStudentsAssigned": total_students,
    }
