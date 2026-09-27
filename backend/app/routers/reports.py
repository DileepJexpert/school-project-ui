from collections import defaultdict
from datetime import date
from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_session
from app.dependencies import require_tenant, tenant_id
from app.models import Enrollment, FeeInstallment, FeeProfile, Payment, Student, User
from app.serializers import money, payment_wire

router = APIRouter(prefix="/reports", tags=["reports"])
Db = Annotated[Session, Depends(get_session)]
TenantId = Annotated[str, Depends(tenant_id)]
ZERO = Decimal("0.00")


def _outstanding(session: Session, tenant: str, class_name: str | None = None) -> Decimal:
    statement = (
        select(FeeInstallment)
        .join(FeeProfile, FeeInstallment.profile_id == FeeProfile.id)
        .join(Enrollment, FeeProfile.enrollment_id == Enrollment.id)
        .where(FeeProfile.tenant_id == tenant, Enrollment.tenant_id == tenant)
    )
    if class_name:
        statement = statement.where(Enrollment.class_name == class_name)
    return sum(
        (item.amount_due - item.paid_amount - item.discount_amount for item in session.scalars(statement)),
        ZERO,
    )


def _payments(
    session: Session,
    tenant: str,
    start_date: date | None = None,
    end_date: date | None = None,
    class_name: str | None = None,
    payment_mode: str | None = None,
) -> list[Payment]:
    statement = (
        select(Payment)
        .join(FeeProfile, Payment.profile_id == FeeProfile.id)
        .join(Enrollment, FeeProfile.enrollment_id == Enrollment.id)
        .where(
            Payment.tenant_id == tenant, Payment.voided_at.is_(None),
            FeeProfile.tenant_id == tenant, Enrollment.tenant_id == tenant,
        )
    )
    if class_name:
        statement = statement.where(Enrollment.class_name == class_name)
    if payment_mode:
        statement = statement.where(Payment.payment_mode == payment_mode)
    # Date comparison in Python keeps behavior consistent for SQLite tests and PostgreSQL.
    payments = list(session.scalars(statement))
    if start_date:
        payments = [item for item in payments if item.payment_date.date() >= start_date]
    if end_date:
        payments = [item for item in payments if item.payment_date.date() <= end_date]
    return sorted(payments, key=lambda item: (item.payment_date, item.id), reverse=True)


@router.get("/fees/report-summary")
def fee_report(
    session: Db,
    tenant: TenantId,
    start_date: date | None = Query(None, alias="startDate"),
    end_date: date | None = Query(None, alias="endDate"),
    class_name: str | None = Query(None, alias="className"),
    payment_mode: str | None = Query(None, alias="paymentMode"),
    page: int = Query(0, ge=0),
    size: int = Query(100, ge=1, le=500),
) -> dict:
    require_tenant(session, tenant)
    if start_date and end_date and start_date > end_date:
        raise HTTPException(status_code=422, detail="startDate must be before endDate")
    payments = _payments(session, tenant, start_date, end_date, class_name, payment_mode)
    class_totals = defaultdict(lambda: [ZERO, ZERO, 0])
    mode_totals = defaultdict(lambda: ZERO)
    for payment in payments:
        bucket = class_totals[payment.profile.enrollment.class_name]
        bucket[0] += payment.amount_paid
        bucket[1] += payment.discount
        bucket[2] += 1
        mode_totals[payment.payment_mode] += payment.amount_paid

    def transaction(payment: Payment) -> dict:
        enrollment = payment.profile.enrollment
        collector = session.get(User, payment.collected_by_user_id) if payment.collected_by_user_id else None
        item = payment_wire(payment, enrollment.student)
        item.update({
            "className": enrollment.class_name,
            "rollNumber": enrollment.roll_number or "",
            "paidForMonths": item["paidForInstallments"],
            "collectedBy": collector.full_name if collector else "Unknown",
        })
        return item

    start = page * size
    content = [transaction(item) for item in payments[start:start + size]]
    return {
        "summary": {
            "totalCollected": money(sum((item.amount_paid for item in payments), ZERO)),
            "totalDue": money(_outstanding(session, tenant, class_name)),
            "totalDiscountGiven": money(sum((item.discount for item in payments), ZERO)),
            "totalTransactions": len(payments),
        },
        "classSummaries": [
            {
                "classForAdmission": name,
                "totalCollectedInClass": money(values[0]),
                "totalDiscountInClass": money(values[1]),
                "transactionCountInClass": values[2],
            }
            for name, values in sorted(class_totals.items())
        ],
        "paymentModeSummary": [
            {"paymentMode": mode, "totalAmount": money(amount)}
            for mode, amount in sorted(mode_totals.items())
        ],
        "transactionsPage": {
            "content": content,
            "number": page,
            "size": size,
            "totalElements": len(payments),
            "totalPages": (len(payments) + size - 1) // size,
        },
    }


@router.get("/school-summary")
def school_summary(session: Db, tenant: TenantId) -> dict:
    require_tenant(session, tenant)
    students = list(session.scalars(select(Student).where(Student.tenant_id == tenant, Student.status == "ACTIVE")))
    enrollment_by_class = defaultdict(int)
    for student in students:
        enrollment_by_class[student.class_name] += 1
    payments = _payments(session, tenant)
    monthly = defaultdict(lambda: ZERO)
    modes = defaultdict(lambda: ZERO)
    for payment in payments:
        monthly[(payment.payment_date.year, payment.payment_date.month)] += payment.amount_paid
        modes[payment.payment_mode] += payment.amount_paid
    return {
        "totalStudents": len(students),
        "enrollmentByClass": dict(sorted(enrollment_by_class.items())),
        "totalFeesCollected": money(sum((item.amount_paid for item in payments), ZERO)),
        "totalFeesDue": money(_outstanding(session, tenant)),
        "totalDiscountGiven": money(sum((item.discount for item in payments), ZERO)),
        "totalTransactions": len(payments),
        "monthlyCollections": [
            {"month": month, "year": year, "label": f"{year}-{month:02d}", "amount": money(amount)}
            for (year, month), amount in sorted(monthly.items())
        ],
        "paymentModeSummary": [
            {"paymentMode": mode, "totalAmount": money(amount)}
            for mode, amount in sorted(modes.items())
        ],
    }
