import hashlib
import json
from datetime import datetime, timezone
from decimal import Decimal
from typing import Annotated, Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db import get_session
from app.dependencies import lock_tenant, require_tenant, tenant_id
from app.models import Enrollment, FeeProfile, Payment, PaymentAllocation, Student
from app.schemas import FeePaymentInput
from app.serializers import payment_wire, profile_wire
from app.years import normalize_year

router = APIRouter(prefix="/fees", tags=["fees"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]


class VoidPaymentInput(BaseModel):
    reason: str = Field(min_length=8, max_length=500)


def _fingerprint(data: FeePaymentInput) -> str:
    payload = json.dumps(data.model_dump(mode="json", by_alias=True), sort_keys=True)
    return hashlib.sha256(payload.encode()).hexdigest()


def _replay(session: Session, tenant: str, key: str, fingerprint: str) -> dict | None:
    payment = session.scalar(
        select(Payment).where(Payment.tenant_id == tenant, Payment.idempotency_key == key)
    )
    if payment is None:
        return None
    if payment.request_fingerprint != fingerprint:
        raise HTTPException(status_code=409, detail="Idempotency key was used for another payment")
    student = payment.profile.enrollment.student
    return payment_wire(payment, student)


def _generate_receipt_number(session: Session, tenant: str, payment_date: datetime | None = None) -> str:
    dt = payment_date or datetime.now(timezone.utc)
    date_code = dt.strftime("%Y%m")
    count = session.scalar(
        select(func.count(Payment.id)).where(Payment.tenant_id == tenant)
    ) or 0
    start_seq = max(1, count + 1)
    seq = start_seq
    while True:
        candidate = f"REC-{date_code}-{seq:05d}"
        existing = session.scalar(
            select(Payment.id).where(Payment.tenant_id == tenant, Payment.receipt_number == candidate)
        )
        if not existing:
            return candidate
        seq += 1


@router.post("/collect", status_code=201)
def collect_fee(
    data: FeePaymentInput,
    request: Request,
    session: Db,
    tenant: TenantId,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key", min_length=8, max_length=128),
) -> dict:
    fingerprint = _fingerprint(data)
    try:
        with session.begin():
            require_tenant(session, tenant)
            if idempotency_key:
                replay = _replay(session, tenant, idempotency_key, fingerprint)
                if replay is not None:
                    return replay

            student = session.get(Student, data.student_id)
            if student is None or student.tenant_id != tenant:
                raise HTTPException(status_code=404, detail="Student not found")
            year = data.academic_year or student.academic_year
            profile = session.scalar(
                select(FeeProfile)
                .join(Enrollment)
                .where(
                    FeeProfile.tenant_id == tenant,
                    Enrollment.tenant_id == tenant,
                    Enrollment.student_id == student.id,
                    Enrollment.academic_year == year,
                )
                .with_for_update()
            )
            if profile is None:
                raise HTTPException(status_code=404, detail="Fee profile not found for this year")

            by_name = {item.name: item for item in profile.installments}
            try:
                selected = [by_name[name] for name in data.installment_names]
            except KeyError as error:
                raise HTTPException(status_code=422, detail=f"Unknown installment: {error.args[0]}") from error
            balances = [item.amount_due - item.paid_amount - item.discount_amount for item in selected]
            if any(balance <= 0 for balance in balances):
                raise HTTPException(status_code=409, detail="An installment is already settled")
            selected_total = sum(balances, Decimal("0.00"))
            if data.amount + data.discount != selected_total:
                raise HTTPException(
                    status_code=422,
                    detail="Amount plus discount must equal selected installment balances",
                )

            payment_dt = datetime.now(timezone.utc)
            payment = Payment(
                tenant_id=tenant,
                profile=profile,
                receipt_number=_generate_receipt_number(session, tenant, payment_dt),
                payment_date=payment_dt,
                amount_paid=data.amount,
                discount=data.discount,
                payment_mode=data.payment_mode,
                transaction_reference=(data.transaction_id or "").strip() or None,
                cheque_details=(data.cheque_details or "").strip() or None,
                remarks=data.remarks,
                idempotency_key=idempotency_key,
                request_fingerprint=fingerprint if idempotency_key else None,
                collected_by_user_id=request.state.user_id,
                student_name_snapshot=student.full_name,
            )
            discount_left = data.discount
            payment.allocations = []
            for index, (item, balance) in enumerate(zip(selected, balances)):
                allocation_discount = min(discount_left, balance)
                allocation_paid = balance - allocation_discount
                item.paid_amount += allocation_paid
                item.discount_amount += allocation_discount
                item.status = "PAID"
                payment.allocations.append(
                    PaymentAllocation(
                        position=index,
                        installment=item,
                        amount_paid=allocation_paid,
                        discount=allocation_discount,
                    )
                )
                discount_left -= allocation_discount
            session.add(payment)
            session.flush()
            result = payment_wire(payment, student)
        return result
    except IntegrityError as error:
        session.rollback()
        if idempotency_key:
            replay = _replay(session, tenant, idempotency_key, fingerprint)
            if replay is not None:
                return replay
        raise HTTPException(status_code=409, detail="Duplicate payment reference or receipt") from error


@router.get("/payments/{payment_id}")
def get_payment(payment_id: str, session: Db, tenant: TenantId) -> dict:
    require_tenant(session, tenant)
    payment = session.get(Payment, payment_id)
    if payment is None or payment.tenant_id != tenant:
        raise HTTPException(status_code=404, detail="Payment not found")
    return payment_wire(payment, payment.profile.enrollment.student)


@router.get("/payments")
def list_payments(
    session: Db, tenant: TenantId,
    academic_year: str | None = Query(None, alias="academicYear"),
    student_id: str | None = Query(None, alias="studentId"),
    status: Literal["ALL", "POSTED", "VOIDED"] = "ALL",
    page: int = Query(0, ge=0), size: int = Query(100, ge=1, le=500),
) -> dict:
    require_tenant(session, tenant)
    statement = select(Payment).join(FeeProfile).join(Enrollment).where(
        Payment.tenant_id == tenant, FeeProfile.tenant_id == tenant,
        Enrollment.tenant_id == tenant,
    )
    if academic_year:
        try:
            statement = statement.where(Enrollment.academic_year == normalize_year(academic_year))
        except ValueError as error:
            raise HTTPException(status_code=422, detail=str(error)) from error
    if student_id:
        statement = statement.where(Enrollment.student_id == student_id)
    if status == "POSTED":
        statement = statement.where(Payment.voided_at.is_(None))
    elif status == "VOIDED":
        statement = statement.where(Payment.voided_at.is_not(None))
    total = session.scalar(select(func.count()).select_from(statement.order_by(None).subquery())) or 0
    payments = session.scalars(
        statement.order_by(Payment.payment_date.desc(), Payment.id.desc())
        .offset(page * size).limit(size)
    )
    return {
        "content": [payment_wire(item, item.profile.enrollment.student) for item in payments],
        "number": page, "size": size, "totalElements": total,
        "totalPages": (total + size - 1) // size,
    }


@router.post("/payments/{payment_id}/void")
def void_payment(
    payment_id: str, data: VoidPaymentInput, request: Request, session: Db, tenant: TenantId,
) -> dict:
    reason = data.reason.strip()
    if len(reason) < 8:
        raise HTTPException(status_code=422, detail="Give a specific reversal reason")
    with session.begin():
        lock_tenant(session, tenant)
        payment = session.scalar(select(Payment).where(
            Payment.id == payment_id, Payment.tenant_id == tenant,
        ).with_for_update())
        if payment is None:
            raise HTTPException(status_code=404, detail="Payment not found")
        if payment.voided_at is not None:
            if payment.void_reason != reason:
                raise HTTPException(status_code=409, detail="Payment was already voided for another reason")
            return payment_wire(payment, payment.profile.enrollment.student)
        profile = session.scalar(select(FeeProfile).where(
            FeeProfile.id == payment.profile_id, FeeProfile.tenant_id == tenant,
        ).with_for_update())
        if profile is None:
            raise HTTPException(status_code=409, detail="Payment profile is missing")
        for allocation in payment.allocations:
            installment = allocation.installment
            installment.paid_amount -= allocation.amount_paid
            installment.discount_amount -= allocation.discount
            if installment.paid_amount < 0 or installment.discount_amount < 0:
                raise HTTPException(status_code=409, detail="Payment allocation no longer matches the fee balance")
            installment.status = (
                "PAID" if installment.paid_amount + installment.discount_amount == installment.amount_due
                else "PENDING"
            )
        payment.voided_at = datetime.now(timezone.utc)
        payment.void_reason = reason
        payment.voided_by_user_id = request.state.user_id
        session.flush()
        result = payment_wire(payment, profile.enrollment.student)
    return result


@router.get("/search")
def search_fee_profiles(
    session: Db,
    tenant: TenantId,
    name: str = "",
    class_name: str | None = Query(None, alias="className"),
    roll_number: str | None = Query(None, alias="rollNumber"),
    academic_year: str | None = Query(None, alias="academicYear"),
) -> list[dict]:
    require_tenant(session, tenant)
    statement = (
        select(FeeProfile, Student)
        .join(Enrollment, FeeProfile.enrollment_id == Enrollment.id)
        .join(Student, Enrollment.student_id == Student.id)
        .where(FeeProfile.tenant_id == tenant, Student.tenant_id == tenant)
    )
    if academic_year:
        try:
            year = normalize_year(academic_year)
        except ValueError as error:
            raise HTTPException(status_code=422, detail=str(error)) from error
        statement = statement.where(Enrollment.academic_year == year)
    else:
        statement = statement.where(Enrollment.academic_year == Student.academic_year)
    if name:
        statement = statement.where(Student.full_name.ilike(f"%{name}%"))
    if class_name:
        statement = statement.where(Enrollment.class_name == class_name)
    if roll_number:
        statement = statement.where(Enrollment.roll_number == roll_number)
    return [profile_wire(profile, student) for profile, student in session.execute(statement.order_by(Student.full_name))]


@router.get("/dues")
def outstanding_dues(
    session: Db,
    tenant: TenantId,
    academic_year: str | None = Query(None, alias="academicYear"),
) -> list[dict]:
    require_tenant(session, tenant)
    statement = (
        select(FeeProfile, Student)
        .join(Enrollment, FeeProfile.enrollment_id == Enrollment.id)
        .join(Student, Enrollment.student_id == Student.id)
        .where(FeeProfile.tenant_id == tenant, Student.tenant_id == tenant)
    )
    if academic_year:
        try:
            statement = statement.where(Enrollment.academic_year == normalize_year(academic_year))
        except ValueError as error:
            raise HTTPException(status_code=422, detail=str(error)) from error
    profiles = [profile_wire(profile, student) for profile, student in session.execute(statement)]
    return sorted((item for item in profiles if item["dueFees"] > 0), key=lambda item: -item["dueFees"])
