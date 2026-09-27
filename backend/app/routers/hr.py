"""Staff, leave, payroll and staff attendance compatible with the Java routes."""

import uuid
from datetime import date, datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth import aware
from app.db import get_session
from app.dependencies import lock_tenant, require_tenant, tenant_id
from app.models import LeaveRequest, SalaryRecord, Staff, StaffAttendance
from app.schemas import LeaveDecisionInput, LeaveInput, SalaryGenerateInput, SalaryPayInput, StaffAttendanceInput, StaffInput, camel

Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]
staff_router = APIRouter(prefix="/staff", tags=["staff"])
leave_router = APIRouter(prefix="/leave", tags=["leave"])
salary_router = APIRouter(prefix="/salary", tags=["salary"])
attendance_router = APIRouter(prefix="/staff-attendance", tags=["staff attendance"])

STAFF_DETAILS = (
    "gender", "date_of_birth", "qualification", "specialization", "bank_account_number",
    "bank_name", "pan_number", "address", "emergency_contact", "emergency_contact_name",
    "blood_group", "aadhar_number", "profile_photo_url",
)


def _staff(session: Session, tenant: str, staff_id: str, *, include_deleted: bool = False) -> Staff:
    item = session.get(Staff, staff_id)
    if item is None or item.tenant_id != tenant or (item.deleted_at and not include_deleted):
        raise HTTPException(status_code=404, detail="Staff not found")
    return item


def _staff_wire(item: Staff) -> dict:
    details = {camel(key): value for key, value in (item.details or {}).items()}
    return {
        "id": item.id, "employeeId": item.employee_id, "fullName": item.full_name,
        "email": item.email, "phone": item.phone, "department": item.department,
        "designation": item.designation, "dateOfJoining": item.date_of_joining.isoformat(),
        "dateOfLeaving": item.date_of_leaving.isoformat() if item.date_of_leaving else None,
        "basicSalary": float(item.basic_salary), "status": item.status,
        "createdAt": aware(item.created_at).isoformat(),
        "updatedAt": aware(item.updated_at).isoformat() if item.updated_at else None,
        **details,
    }


def _leave_wire(item: LeaveRequest) -> dict:
    return {
        "id": item.id, "staffId": item.staff_id, "staffName": item.staff_name,
        "department": item.department, "leaveType": item.leave_type,
        "fromDate": item.from_date.isoformat(), "toDate": item.to_date.isoformat(),
        "totalDays": item.total_days, "reason": item.reason, "status": item.status,
        "approvedBy": item.approved_by, "approverRemarks": item.approver_remarks,
        "approvedAt": aware(item.approved_at).isoformat() if item.approved_at else None,
        "appliedAt": aware(item.applied_at).isoformat(),
    }


def _salary_wire(item: SalaryRecord) -> dict:
    result = {
        "id": item.id, "staffId": item.staff_id, "staffName": item.staff_name,
        "department": item.department, "designation": item.designation,
        "month": item.month, "year": item.year, "status": item.status,
        "paymentMode": item.payment_mode, "transactionRef": item.transaction_ref,
        "generatedBy": item.generated_by, "generatedAt": aware(item.generated_at).isoformat(),
        "paidAt": aware(item.paid_at).isoformat() if item.paid_at else None,
    }
    for key in ("basic_pay", "hra", "da", "ta", "other_allowances", "pf", "tax", "other_deductions", "gross_salary", "total_deductions", "net_salary"):
        result[camel(key)] = float(getattr(item, key))
    return result


def _attendance_wire(item: StaffAttendance) -> dict:
    return {
        "id": item.id, "staffId": item.staff_id, "staffName": item.staff_name,
        "department": item.department, "date": item.date.isoformat(),
        "status": item.status, "checkInTime": item.check_in_time,
        "checkOutTime": item.check_out_time, "remarks": item.remarks,
        "markedBy": item.marked_by, "markedAt": aware(item.marked_at).isoformat(),
    }


@staff_router.get("/dashboard")
def dashboard(session: Db, tenant: TenantId) -> dict:
    require_tenant(session, tenant)
    staff = list(session.scalars(select(Staff).where(Staff.tenant_id == tenant, Staff.deleted_at.is_(None))))
    leaves = list(session.scalars(select(LeaveRequest).where(LeaveRequest.tenant_id == tenant)))
    today = date.today()
    departments: dict[str, int] = {}
    for item in staff:
        departments[item.department] = departments.get(item.department, 0) + 1
    return {
        "totalStaff": len(staff),
        "activeStaff": sum(item.status == "ACTIVE" for item in staff),
        "onLeaveToday": sum(item.status == "ACTIVE" and any(
            leave.staff_id == item.id and leave.status == "APPROVED" and leave.from_date <= today <= leave.to_date
            for leave in leaves
        ) for item in staff),
        "pendingLeaveRequests": sum(item.status == "PENDING" for item in leaves),
        "departmentWise": departments,
        "totalMonthlyPayroll": float(sum((item.basic_salary for item in staff if item.status == "ACTIVE"), Decimal("0.00"))),
    }


@staff_router.get("")
def list_staff(session: Db, tenant: TenantId, department: str | None = None) -> list[dict]:
    require_tenant(session, tenant)
    query = select(Staff).where(Staff.tenant_id == tenant, Staff.deleted_at.is_(None))
    if department:
        query = query.where(Staff.department == department)
    return [_staff_wire(item) for item in session.scalars(query.order_by(Staff.full_name, Staff.id))]


@staff_router.get("/search")
def search_staff(session: Db, tenant: TenantId, name: str = "") -> list[dict]:
    return [item for item in list_staff(session, tenant) if name.casefold() in item["fullName"].casefold()]


@staff_router.get("/{staff_id}")
def get_staff(staff_id: str, session: Db, tenant: TenantId) -> dict:
    return _staff_wire(_staff(session, tenant, staff_id))


@staff_router.post("", status_code=201)
def create_staff(data: StaffInput, session: Db, tenant: TenantId) -> dict:
    try:
        with session.begin():
            lock_tenant(session, tenant)
            item = Staff(
                tenant_id=tenant, employee_id=data.employee_id or f"EMP-{uuid.uuid4().hex[:10].upper()}",
                full_name=data.full_name, email=data.email.strip().lower(), phone=data.phone,
                department=data.department, designation=data.designation,
                date_of_joining=data.date_of_joining, date_of_leaving=data.date_of_leaving,
                basic_salary=data.basic_salary, status=data.status,
                details={key: value.isoformat() if isinstance(value, date) else value for key, value in data.model_dump(include=set(STAFF_DETAILS)).items()},
                created_at=datetime.now(timezone.utc),
            )
            session.add(item)
            session.flush()
            result = _staff_wire(item)
        return result
    except IntegrityError as error:
        raise HTTPException(status_code=409, detail="Employee ID already exists") from error


@staff_router.put("/{staff_id}")
def update_staff(staff_id: str, data: StaffInput, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        lock_tenant(session, tenant)
        item = _staff(session, tenant, staff_id)
        item.full_name = data.full_name
        item.email = data.email.strip().lower()
        item.phone = data.phone
        item.department = data.department
        item.designation = data.designation
        item.date_of_joining = data.date_of_joining
        item.date_of_leaving = data.date_of_leaving
        item.basic_salary = data.basic_salary
        item.status = data.status
        item.details = {key: value.isoformat() if isinstance(value, date) else value for key, value in data.model_dump(include=set(STAFF_DETAILS)).items()}
        item.updated_at = datetime.now(timezone.utc)
        result = _staff_wire(item)
    return result


@staff_router.delete("/{staff_id}", status_code=204)
def delete_staff(staff_id: str, session: Db, tenant: TenantId) -> Response:
    with session.begin():
        lock_tenant(session, tenant)
        item = _staff(session, tenant, staff_id)
        item.deleted_at = datetime.now(timezone.utc)
        item.status = "TERMINATED"
    return Response(status_code=204)


@leave_router.post("/apply", status_code=201)
def apply_leave(data: LeaveInput, request: Request, session: Db, tenant: TenantId) -> dict:
    role = request.state.user_role
    if role not in ("SUPER_ADMIN", "SCHOOL_ADMIN", "TEACHER", "ACCOUNTANT", "TRANSPORT_MANAGER"):
        raise HTTPException(status_code=403, detail="Staff role required")
    with session.begin():
        lock_tenant(session, tenant)
        staff = _staff(session, tenant, data.staff_id)
        if role not in ("SUPER_ADMIN", "SCHOOL_ADMIN"):
            from app.models import User
            user = session.get(User, request.state.user_id)
            if user.linked_entity_id != staff.id:
                raise HTTPException(status_code=403, detail="Can apply only for linked staff")
        if staff.status not in ("ACTIVE", "ON_LEAVE"):
            raise HTTPException(status_code=409, detail="Staff member is inactive")
        overlapping = session.scalar(select(LeaveRequest).where(
            LeaveRequest.tenant_id == tenant, LeaveRequest.staff_id == staff.id,
            LeaveRequest.status.in_(["PENDING", "APPROVED"]),
            LeaveRequest.from_date <= data.to_date, LeaveRequest.to_date >= data.from_date,
        ))
        if overlapping:
            raise HTTPException(status_code=409, detail="Overlapping leave exists")
        item = LeaveRequest(
            tenant_id=tenant, staff_id=staff.id, staff_name=staff.full_name,
            department=staff.department, leave_type=data.leave_type,
            from_date=data.from_date, to_date=data.to_date,
            total_days=(data.to_date - data.from_date).days + 1,
            reason=data.reason.strip(), status="PENDING", applied_at=datetime.now(timezone.utc),
        )
        session.add(item)
        session.flush()
        result = _leave_wire(item)
    return result


@leave_router.get("")
def list_leaves(session: Db, tenant: TenantId, status: str | None = None) -> list[dict]:
    require_tenant(session, tenant)
    query = select(LeaveRequest).where(LeaveRequest.tenant_id == tenant)
    if status:
        query = query.where(LeaveRequest.status == status.upper())
    return [_leave_wire(item) for item in session.scalars(query.order_by(LeaveRequest.applied_at.desc(), LeaveRequest.id))]


@leave_router.get("/staff/{staff_id}")
def staff_leaves(staff_id: str, request: Request, session: Db, tenant: TenantId) -> list[dict]:
    _staff(session, tenant, staff_id, include_deleted=True)
    if request.state.user_role not in ("SUPER_ADMIN", "SCHOOL_ADMIN"):
        from app.models import User
        user = session.get(User, request.state.user_id)
        if user.linked_entity_id != staff_id:
            raise HTTPException(status_code=403, detail="Can read only linked staff leave")
    return [_leave_wire(item) for item in session.scalars(select(LeaveRequest).where(
        LeaveRequest.tenant_id == tenant, LeaveRequest.staff_id == staff_id,
    ).order_by(LeaveRequest.applied_at.desc()))]


@leave_router.put("/{leave_id}/approve")
def decide_leave(leave_id: str, data: LeaveDecisionInput, request: Request, session: Db, tenant: TenantId) -> dict:
    with session.begin():
        lock_tenant(session, tenant)
        item = session.get(LeaveRequest, leave_id)
        if item is None or item.tenant_id != tenant:
            raise HTTPException(status_code=404, detail="Leave request not found")
        target = "APPROVED" if data.action == "approve" else "REJECTED"
        if item.status != "PENDING":
            if item.status != target:
                raise HTTPException(status_code=409, detail="Leave decision is final")
        else:
            item.status = target
            item.approved_by = request.state.user_id
            item.approver_remarks = data.remarks
            item.approved_at = datetime.now(timezone.utc)
        result = _leave_wire(item)
    return result


@leave_router.delete("/{leave_id}", status_code=204)
def cancel_leave(leave_id: str, session: Db, tenant: TenantId) -> Response:
    with session.begin():
        lock_tenant(session, tenant)
        item = session.get(LeaveRequest, leave_id)
        if item is None or item.tenant_id != tenant:
            raise HTTPException(status_code=404, detail="Leave request not found")
        if item.status != "PENDING":
            raise HTTPException(status_code=409, detail="Only pending leave may be cancelled")
        item.status = "CANCELLED"
    return Response(status_code=204)


def _round(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


@salary_router.post("/generate")
def generate_salary(data: SalaryGenerateInput, request: Request, session: Db, tenant: TenantId) -> list[dict]:
    with session.begin():
        lock_tenant(session, tenant)
        staff = list(session.scalars(select(Staff).where(
            Staff.tenant_id == tenant, Staff.deleted_at.is_(None), Staff.status == "ACTIVE",
        )))
        generated = []
        for person in staff:
            existing = session.scalar(select(SalaryRecord).where(
                SalaryRecord.tenant_id == tenant, SalaryRecord.staff_id == person.id,
                SalaryRecord.month == data.month, SalaryRecord.year == data.year,
            ))
            if existing:
                continue
            basic = _round(person.basic_salary)
            hra, da, ta, pf = (_round(basic * rate) for rate in (Decimal("0.20"), Decimal("0.10"), Decimal("0.05"), Decimal("0.12")))
            gross = basic + hra + da + ta
            item = SalaryRecord(
                tenant_id=tenant, staff_id=person.id, staff_name=person.full_name,
                department=person.department, designation=person.designation,
                month=data.month, year=data.year, basic_pay=basic, hra=hra, da=da, ta=ta,
                other_allowances=Decimal("0.00"), pf=pf, tax=Decimal("0.00"),
                other_deductions=Decimal("0.00"), gross_salary=gross,
                total_deductions=pf, net_salary=gross - pf, status="GENERATED",
                generated_by=request.state.user_id, generated_at=datetime.now(timezone.utc),
            )
            session.add(item)
            session.flush()
            generated.append(_salary_wire(item))
    return generated


@salary_router.get("")
def salaries(session: Db, tenant: TenantId, month: int = Query(ge=1, le=12), year: int = Query(ge=2000, le=2200)) -> list[dict]:
    require_tenant(session, tenant)
    return [_salary_wire(item) for item in session.scalars(select(SalaryRecord).where(
        SalaryRecord.tenant_id == tenant, SalaryRecord.month == month, SalaryRecord.year == year,
    ).order_by(SalaryRecord.staff_name, SalaryRecord.id))]


@salary_router.get("/staff/{staff_id}")
def staff_salaries(staff_id: str, session: Db, tenant: TenantId) -> list[dict]:
    _staff(session, tenant, staff_id, include_deleted=True)
    return [_salary_wire(item) for item in session.scalars(select(SalaryRecord).where(
        SalaryRecord.tenant_id == tenant, SalaryRecord.staff_id == staff_id,
    ).order_by(SalaryRecord.year.desc(), SalaryRecord.month.desc()))]


@salary_router.put("/{salary_id}/pay")
def pay_salary(salary_id: str, session: Db, tenant: TenantId, data: SalaryPayInput | None = None) -> dict:
    data = data or SalaryPayInput()
    with session.begin():
        lock_tenant(session, tenant)
        item = session.get(SalaryRecord, salary_id)
        if item is None or item.tenant_id != tenant:
            raise HTTPException(status_code=404, detail="Salary record not found")
        if item.status == "PAID":
            if item.payment_mode != data.payment_mode or (data.transaction_ref and item.transaction_ref != data.transaction_ref):
                raise HTTPException(status_code=409, detail="Salary already paid with different details")
        elif item.status != "GENERATED":
            raise HTTPException(status_code=409, detail="Salary is not payable")
        else:
            item.status = "PAID"
            item.payment_mode = data.payment_mode
            item.transaction_ref = data.transaction_ref
            item.paid_at = datetime.now(timezone.utc)
        result = _salary_wire(item)
    return result


@attendance_router.post("/mark", status_code=201)
def mark_staff_attendance(data: list[StaffAttendanceInput], request: Request, session: Db, tenant: TenantId) -> list[dict]:
    if not data or len({(item.staff_id, item.date) for item in data}) != len(data):
        raise HTTPException(status_code=422, detail="Nonempty unique staff/date entries required")
    with session.begin():
        lock_tenant(session, tenant)
        result = []
        for entry in data:
            staff = _staff(session, tenant, entry.staff_id)
            existing = session.scalar(select(StaffAttendance).where(
                StaffAttendance.tenant_id == tenant, StaffAttendance.staff_id == staff.id,
                StaffAttendance.date == entry.date,
            ))
            item = existing or StaffAttendance(tenant_id=tenant, staff_id=staff.id, date=entry.date)
            item.staff_name = staff.full_name
            item.department = staff.department
            item.status = entry.status
            item.check_in_time = entry.check_in_time
            item.check_out_time = entry.check_out_time
            item.remarks = entry.remarks
            item.marked_by = request.state.user_id
            item.marked_at = datetime.now(timezone.utc)
            if not existing:
                session.add(item)
            session.flush()
            result.append(_attendance_wire(item))
    return result


def _attendance_for_date(session: Session, tenant: str, day: date, department: str | None = None) -> list[dict]:
    require_tenant(session, tenant)
    query = select(StaffAttendance).where(StaffAttendance.tenant_id == tenant, StaffAttendance.date == day)
    if department:
        query = query.where(StaffAttendance.department == department)
    return [_attendance_wire(item) for item in session.scalars(query.order_by(StaffAttendance.staff_name))]


@attendance_router.get("")
@attendance_router.get("/date")
def staff_attendance_by_date(session: Db, tenant: TenantId, date: date) -> list[dict]:
    return _attendance_for_date(session, tenant, date)


@attendance_router.get("/staff/{staff_id}")
def attendance_by_staff(staff_id: str, session: Db, tenant: TenantId, from_date: date = Query(alias="from"), to_date: date = Query(alias="to")) -> list[dict]:
    _staff(session, tenant, staff_id, include_deleted=True)
    if from_date > to_date:
        raise HTTPException(status_code=422, detail="from must be before to")
    return [_attendance_wire(item) for item in session.scalars(select(StaffAttendance).where(
        StaffAttendance.tenant_id == tenant, StaffAttendance.staff_id == staff_id,
        StaffAttendance.date >= from_date, StaffAttendance.date <= to_date,
    ).order_by(StaffAttendance.date))]


@attendance_router.get("/department/{department}")
def attendance_by_department(department: str, session: Db, tenant: TenantId, date: date) -> list[dict]:
    return _attendance_for_date(session, tenant, date, department)
