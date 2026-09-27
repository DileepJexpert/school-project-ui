"""Bus and route management with tenant, capacity and assignment checks."""

from datetime import date, datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth import aware
from app.db import get_session
from app.dependencies import lock_tenant, require_tenant, tenant_id
from app.models import Bus, Student, TransportAssignment, TransportRoute, User
from app.schemas import BusInput, TransportAssignmentInput, TransportRouteInput

router = APIRouter(prefix="/transport", tags=["transport"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]


def _route(session: Session, tenant: str, route_id: str, *, include_deleted: bool = False) -> TransportRoute:
    item = session.get(TransportRoute, route_id)
    if item is None or item.tenant_id != tenant or (item.deleted_at and not include_deleted):
        raise HTTPException(status_code=404, detail="Transport route not found")
    return item


def _bus(session: Session, tenant: str, bus_id: str, *, include_deleted: bool = False) -> Bus:
    item = session.get(Bus, bus_id)
    if item is None or item.tenant_id != tenant or (item.deleted_at and not include_deleted):
        raise HTTPException(status_code=404, detail="Bus not found")
    return item


def _active_count(session: Session, tenant: str, field, identifier: str) -> int:
    return session.scalar(select(func.count()).select_from(TransportAssignment).where(
        TransportAssignment.tenant_id == tenant, field == identifier,
        TransportAssignment.status == "ACTIVE",
    )) or 0


def _route_wire(session: Session, item: TransportRoute) -> dict:
    return {
        "id": item.id, "zoneName": item.zone_name, "displayName": item.display_name,
        "areasCovered": item.areas_covered, "stops": item.stops,
        "firstPickupTime": item.first_pickup_time, "monthlyFee": float(item.monthly_fee),
        "assignedCount": _active_count(session, item.tenant_id, TransportAssignment.route_id, item.id),
        "createdAt": aware(item.created_at).isoformat(),
    }


def _bus_wire(session: Session, item: Bus) -> dict:
    return {
        "id": item.id, "busNumber": item.bus_number, "driverName": item.driver_name,
        "driverMobile": item.driver_mobile, "routeId": item.route_id,
        "capacity": item.capacity, "status": item.status,
        "insuranceExpiry": item.insurance_expiry, "notes": item.notes,
        "assignedCount": _active_count(session, item.tenant_id, TransportAssignment.bus_id, item.id),
        "createdAt": aware(item.created_at).isoformat(),
    }


def _assignment_wire(item: TransportAssignment) -> dict:
    return {
        "id": item.id, "studentId": item.student_id, "studentName": item.student_name,
        "className": item.class_name, "rollNumber": item.roll_number,
        "busId": item.bus_id, "routeId": item.route_id, "pickupStop": item.pickup_stop,
        "status": item.status, "assignedDate": item.assigned_date.isoformat(),
        "createdAt": aware(item.created_at).isoformat(),
    }


@router.get("/buses")
def buses(session: Db, tenant: TenantId) -> list[dict]:
    require_tenant(session, tenant)
    return [_bus_wire(session, item) for item in session.scalars(select(Bus).where(
        Bus.tenant_id == tenant, Bus.deleted_at.is_(None),
    ).order_by(Bus.bus_number))]


@router.post("/buses", status_code=201)
def create_bus(data: BusInput, session: Db, tenant: TenantId) -> dict:
    try:
        with session.begin():
            lock_tenant(session, tenant)
            if data.route_id:
                _route(session, tenant, data.route_id)
            item = Bus(
                tenant_id=tenant, bus_number=data.bus_number.strip(), driver_name=data.driver_name.strip(),
                driver_mobile=data.driver_mobile.strip(), route_id=data.route_id, capacity=data.capacity,
                status=data.status, insurance_expiry=data.insurance_expiry, notes=data.notes,
                created_at=datetime.now(timezone.utc),
            )
            session.add(item)
            session.flush()
            result = _bus_wire(session, item)
        return result
    except IntegrityError as error:
        raise HTTPException(status_code=409, detail="Bus number already exists") from error


@router.put("/buses/{bus_id}")
def update_bus(bus_id: str, data: BusInput, session: Db, tenant: TenantId) -> dict:
    try:
        with session.begin():
            lock_tenant(session, tenant)
            item = _bus(session, tenant, bus_id)
            count = _active_count(session, tenant, TransportAssignment.bus_id, bus_id)
            if count and (data.route_id != item.route_id or data.status != "ACTIVE" or data.capacity < count):
                raise HTTPException(status_code=409, detail="Bus has active assignments")
            if data.route_id:
                _route(session, tenant, data.route_id)
            item.bus_number = data.bus_number.strip()
            item.driver_name = data.driver_name.strip()
            item.driver_mobile = data.driver_mobile.strip()
            item.route_id = data.route_id
            item.capacity = data.capacity
            item.status = data.status
            item.insurance_expiry = data.insurance_expiry
            item.notes = data.notes
            session.flush()
            result = _bus_wire(session, item)
        return result
    except IntegrityError as error:
        raise HTTPException(status_code=409, detail="Bus number already exists") from error


@router.delete("/buses/{bus_id}", status_code=204)
def delete_bus(bus_id: str, session: Db, tenant: TenantId) -> Response:
    with session.begin():
        lock_tenant(session, tenant)
        item = _bus(session, tenant, bus_id)
        if _active_count(session, tenant, TransportAssignment.bus_id, bus_id):
            raise HTTPException(status_code=409, detail="Bus has active assignments")
        item.deleted_at = datetime.now(timezone.utc)
        item.status = "RETIRED"
    return Response(status_code=204)


@router.get("/routes")
def routes(session: Db, tenant: TenantId) -> list[dict]:
    require_tenant(session, tenant)
    return [_route_wire(session, item) for item in session.scalars(select(TransportRoute).where(
        TransportRoute.tenant_id == tenant, TransportRoute.deleted_at.is_(None),
    ).order_by(TransportRoute.zone_name))]


@router.post("/routes", status_code=201)
def create_route(data: TransportRouteInput, session: Db, tenant: TenantId) -> dict:
    try:
        with session.begin():
            lock_tenant(session, tenant)
            item = TransportRoute(
                tenant_id=tenant, zone_name=data.zone_name.strip(), display_name=data.display_name,
                areas_covered=data.areas_covered, stops=data.stops,
                first_pickup_time=data.first_pickup_time, monthly_fee=data.monthly_fee,
                created_at=datetime.now(timezone.utc),
            )
            session.add(item)
            session.flush()
            result = _route_wire(session, item)
        return result
    except IntegrityError as error:
        raise HTTPException(status_code=409, detail="Zone name already exists") from error


@router.put("/routes/{route_id}")
def update_route(route_id: str, data: TransportRouteInput, session: Db, tenant: TenantId) -> dict:
    try:
        with session.begin():
            lock_tenant(session, tenant)
            item = _route(session, tenant, route_id)
            active_stops = set(session.scalars(select(TransportAssignment.pickup_stop).where(
                TransportAssignment.tenant_id == tenant, TransportAssignment.route_id == route_id,
                TransportAssignment.status == "ACTIVE", TransportAssignment.pickup_stop.is_not(None),
            )))
            if not active_stops.issubset(set(data.stops)):
                raise HTTPException(status_code=409, detail="Route has assigned pickup stops")
            item.zone_name = data.zone_name.strip()
            item.display_name = data.display_name
            item.areas_covered = data.areas_covered
            item.stops = data.stops
            item.first_pickup_time = data.first_pickup_time
            item.monthly_fee = data.monthly_fee
            session.flush()
            result = _route_wire(session, item)
        return result
    except IntegrityError as error:
        raise HTTPException(status_code=409, detail="Zone name already exists") from error


@router.delete("/routes/{route_id}", status_code=204)
def delete_route(route_id: str, session: Db, tenant: TenantId) -> Response:
    with session.begin():
        lock_tenant(session, tenant)
        item = _route(session, tenant, route_id)
        if _active_count(session, tenant, TransportAssignment.route_id, route_id):
            raise HTTPException(status_code=409, detail="Route has active assignments")
        if session.scalar(select(Bus).where(Bus.tenant_id == tenant, Bus.route_id == route_id, Bus.deleted_at.is_(None))):
            raise HTTPException(status_code=409, detail="Route is used by a bus")
        item.deleted_at = datetime.now(timezone.utc)
    return Response(status_code=204)


@router.get("/assignments")
def assignments(session: Db, tenant: TenantId) -> list[dict]:
    require_tenant(session, tenant)
    return [_assignment_wire(item) for item in session.scalars(select(TransportAssignment).where(
        TransportAssignment.tenant_id == tenant, TransportAssignment.status == "ACTIVE",
    ).order_by(TransportAssignment.student_name))]


@router.get("/assignments/bus/{bus_id}")
def bus_roster(bus_id: str, session: Db, tenant: TenantId) -> list[dict]:
    _bus(session, tenant, bus_id)
    return [_assignment_wire(item) for item in session.scalars(select(TransportAssignment).where(
        TransportAssignment.tenant_id == tenant, TransportAssignment.bus_id == bus_id,
        TransportAssignment.status == "ACTIVE",
    ).order_by(TransportAssignment.student_name))]


@router.get("/assignments/student/{student_id}", response_model=None)
def student_assignment(student_id: str, request: Request, session: Db, tenant: TenantId) -> dict | Response:
    student = session.get(Student, student_id)
    if student is None or student.tenant_id != tenant:
        raise HTTPException(status_code=404, detail="Student not found")
    if request.state.user_role in ("STUDENT", "PARENT"):
        user = session.get(User, request.state.user_id)
        linked = {part.strip() for part in (user.linked_entity_id or "").split(",") if part.strip()}
        if student_id not in linked:
            raise HTTPException(status_code=403, detail="Student is not linked to account")
    item = session.scalar(select(TransportAssignment).where(
        TransportAssignment.tenant_id == tenant, TransportAssignment.student_id == student_id,
        TransportAssignment.status == "ACTIVE",
    ))
    return _assignment_wire(item) if item else Response(status_code=204)


@router.post("/assignments", status_code=201)
def assign_student(data: TransportAssignmentInput, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        lock_tenant(session, tenant)
        student = session.get(Student, data.student_id)
        if student is None or student.tenant_id != tenant or student.status != "ACTIVE":
            raise HTTPException(status_code=404, detail="Active student not found")
        bus = _bus(session, tenant, data.bus_id)
        route = _route(session, tenant, data.route_id)
        if bus.status != "ACTIVE" or bus.route_id != route.id:
            raise HTTPException(status_code=409, detail="Bus is not active on this route")
        if data.pickup_stop and data.pickup_stop not in route.stops:
            raise HTTPException(status_code=422, detail="Pickup stop is not on route")
        previous = session.scalar(select(TransportAssignment).where(
            TransportAssignment.tenant_id == tenant, TransportAssignment.student_id == student.id,
            TransportAssignment.status == "ACTIVE",
        ))
        if previous and previous.bus_id == bus.id and previous.route_id == route.id and previous.pickup_stop == data.pickup_stop:
            return _assignment_wire(previous)
        occupied = _active_count(session, tenant, TransportAssignment.bus_id, bus.id)
        if occupied - int(previous is not None and previous.bus_id == bus.id) >= bus.capacity:
            raise HTTPException(status_code=409, detail="Bus is at capacity")
        if previous:
            previous.status = "INACTIVE"
            session.flush()
        item = TransportAssignment(
            tenant_id=tenant, student_id=student.id, student_name=student.full_name,
            class_name=student.class_name, roll_number=student.roll_number,
            bus_id=bus.id, route_id=route.id, pickup_stop=data.pickup_stop,
            status="ACTIVE", assigned_date=date.today(), created_at=datetime.now(timezone.utc),
        )
        session.add(item)
        session.flush()
        result = _assignment_wire(item)
    return result


@router.delete("/assignments/{assignment_id}", status_code=204)
def remove_assignment(assignment_id: str, session: Db, tenant: TenantId) -> Response:
    with session.begin():
        lock_tenant(session, tenant)
        item = session.get(TransportAssignment, assignment_id)
        if item is None or item.tenant_id != tenant or item.status != "ACTIVE":
            raise HTTPException(status_code=404, detail="Active assignment not found")
        item.status = "INACTIVE"
    return Response(status_code=204)


@router.get("/stats")
def stats(session: Db, tenant: TenantId) -> dict:
    require_tenant(session, tenant)
    all_buses = list(session.scalars(select(Bus).where(Bus.tenant_id == tenant, Bus.deleted_at.is_(None))))
    return {
        "totalBuses": len(all_buses),
        "activeBuses": sum(item.status == "ACTIVE" for item in all_buses),
        "maintenanceBuses": sum(item.status == "MAINTENANCE" for item in all_buses),
        "totalRoutes": session.scalar(select(func.count()).select_from(TransportRoute).where(
            TransportRoute.tenant_id == tenant, TransportRoute.deleted_at.is_(None),
        )) or 0,
        "totalStudentsAssigned": session.scalar(select(func.count()).select_from(TransportAssignment).where(
            TransportAssignment.tenant_id == tenant, TransportAssignment.status == "ACTIVE",
        )) or 0,
    }
