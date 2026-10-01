"""D1 fee collection, student fee profiles, and search endpoints."""

from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
import json
from typing import Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response
from pydantic import BaseModel, Field

from school_auth import _db, get_current_user
from school_overview import _many, _one, _tenant
from school_setup import _year


router = APIRouter(tags=["fees"])


def _permission(user: dict, action: str) -> None:
    permissions = user.get("permissions") or []
    if "*" not in permissions and f"fees:{action}" not in permissions:
        raise HTTPException(status_code=403, detail=f"Fee {action} access required")


def _minor(amount: Decimal | float | int) -> int:
    scaled = Decimal(str(amount)) * 100
    return int(scaled.to_integral_value())


def _major(amount_cents: int | float | None) -> float:
    if amount_cents is None:
        return 0.0
    return round(float(amount_cents) / 100.0, 2)


async def _get_or_create_profile(db, tenant: str, student: dict) -> tuple[dict, list[dict], dict | None]:
    """Finds or auto-generates fee profile and installments for a student."""
    student_id = student["id"]
    class_name = student["class_name"]
    year = student["academic_year"]

    # Check enrollment
    enrollment = await _one(
        db,
        "SELECT id, class_name, academic_year, roll_number FROM enrollments WHERE tenant_id = ? AND student_id = ? AND academic_year = ?",
        tenant, student_id, year,
    )
    if not enrollment:
        enrollment_id = uuid4().hex
        await db.prepare(
            "INSERT INTO enrollments (id, tenant_id, student_id, class_name, academic_year, roll_number, status) VALUES (?, ?, ?, ?, ?, ?, ?)"
        ).bind(enrollment_id, tenant, student_id, class_name, year, student.get("roll_number") or "", "ACTIVE").run()
        enrollment = {"id": enrollment_id, "class_name": class_name, "academic_year": year, "roll_number": student.get("roll_number") or ""}

    # Check fee profile
    profile = await _one(
        db,
        "SELECT id, enrollment_id, fee_structure_id FROM fee_profiles WHERE tenant_id = ? AND enrollment_id = ?",
        tenant, enrollment["id"],
    )

    if not profile:
        # Look up fee structure for this class and year
        structure = await _one(
            db,
            "SELECT id FROM fee_structures WHERE tenant_id = ? AND class_name = ? AND academic_year = ?",
            tenant, class_name, year,
        )
        if not structure:
            # Fallback to any structure for this class
            structure = await _one(
                db,
                "SELECT id FROM fee_structures WHERE tenant_id = ? AND class_name = ? LIMIT 1",
                tenant, class_name,
            )

        profile_id = uuid4().hex
        struct_id = structure["id"] if structure else uuid4().hex
        if not structure:
            # Create a default structure so foreign key passes
            await db.prepare(
                "INSERT INTO fee_structures (id, tenant_id, class_name, academic_year) VALUES (?, ?, ?, ?)"
            ).bind(struct_id, tenant, class_name, year).run()
            # Insert standard default Tuition Fee component
            await db.prepare(
                "INSERT INTO fee_components (id, tenant_id, structure_id, position, name, amount, frequency, description) VALUES (?, ?, ?, 0, 'Tuition Fee', 1200000, 'YEARLY', 'Standard Tuition Fee')"
            ).bind(uuid4().hex, tenant, struct_id).run()

        await db.prepare(
            "INSERT INTO fee_profiles (id, tenant_id, enrollment_id, fee_structure_id) VALUES (?, ?, ?, ?)"
        ).bind(profile_id, tenant, enrollment["id"], struct_id).run()
        profile = {"id": profile_id, "enrollment_id": enrollment["id"], "fee_structure_id": struct_id}

        # Generate installments from components
        components = await _many(
            db,
            "SELECT name, amount, frequency FROM fee_components WHERE structure_id = ? ORDER BY position",
            struct_id,
        )
        statements = []
        pos = 0
        for comp in components:
            inst_id = uuid4().hex
            statements.append(
                db.prepare(
                    "INSERT INTO fee_installments (id, profile_id, position, name, amount_due, paid_amount, discount_amount, status) VALUES (?, ?, ?, ?, ?, 0, 0, 'UNPAID')"
                ).bind(inst_id, profile_id, pos, comp["name"], comp["amount"])
            )
            pos += 1
        if statements:
            await db.batch(statements)

    # Fetch installments
    installments = await _many(
        db,
        "SELECT id, name, amount_due, paid_amount, discount_amount, status FROM fee_installments WHERE profile_id = ? ORDER BY position",
        profile["id"],
    )

    # Fetch last payment
    last_payment = await _one(
        db,
        "SELECT id, receipt_number, payment_date, amount_paid, discount, payment_mode, remarks FROM payments WHERE profile_id = ? AND voided_at IS NULL ORDER BY payment_date DESC, id DESC LIMIT 1",
        profile["id"],
    )

    return profile, installments, last_payment


def _build_profile_wire(student: dict, installments: list[dict], last_payment: dict | None) -> dict:
    total_due_cents = 0
    paid_cents = 0
    discount_cents = 0
    net_due_cents = 0

    inst_list = []
    for inst in installments:
        due = inst["amount_due"]
        paid = inst["paid_amount"]
        disc = inst["discount_amount"]
        balance = max(0, due - paid - disc)

        total_due_cents += due
        paid_cents += paid
        discount_cents += disc
        net_due_cents += balance

        inst_list.append({
            "installmentName": inst["name"],
            "amountDue": _major(balance),
            "status": "PAID" if balance == 0 else "PENDING",
        })

    parent_name = ""
    try:
        p = json.loads(student.get("parent_details") or "{}")
        parent_name = p.get("father", {}).get("name") or p.get("fatherName") or p.get("mother", {}).get("name") or p.get("motherName") or ""
    except Exception:
        pass

    last_pay_dict = None
    if last_payment:
        last_pay_dict = {
            "id": last_payment["id"],
            "transactionId": last_payment["id"],
            "receiptNumber": last_payment["receipt_number"],
            "studentId": student["id"],
            "studentName": student["full_name"],
            "paymentDate": last_payment["payment_date"],
            "amountPaid": _major(last_payment["amount_paid"]),
            "discount": _major(last_payment["discount"]),
            "paymentMode": last_payment["payment_mode"],
            "paidForInstallments": [],
            "remarks": last_payment.get("remarks"),
        }

    return {
        "id": student["id"],
        "name": student["full_name"],
        "className": student["class_name"],
        "academicYear": student["academic_year"],
        "rollNumber": student.get("roll_number") or "",
        "parentName": parent_name,
        "feeInstallments": inst_list,
        "lastPayment": last_pay_dict,
        "totalFees": _major(total_due_cents),
        "paidFees": _major(paid_cents),
        "dueFees": _major(net_due_cents),
        "totalDiscountGiven": _major(discount_cents),
    }


# =========================================================================
# ROUTE 1: GET /api/fees/search
# =========================================================================
@router.get("/api/fees/search")
async def search_fee_profiles(
    name: str = Query(default=""),
    className: str | None = Query(default=None),
    rollNumber: str | None = Query(default=None),
    academicYear: str | None = Query(default=None),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user, "read")
    tenant = await _tenant(db, user, x_tenant_id)

    query = "SELECT id, full_name, class_name, academic_year, roll_number, parent_details FROM students WHERE tenant_id = ?"
    params = [tenant]

    if name.strip():
        query += " AND full_name LIKE ?"
        params.append(f"%{name.strip()}%")
    if className and className.strip():
        query += " AND class_name = ?"
        params.append(className.strip())
    if rollNumber and rollNumber.strip():
        query += " AND roll_number = ?"
        params.append(rollNumber.strip())
    if academicYear and academicYear.strip():
        query += " AND academic_year = ?"
        params.append(_year(academicYear.strip()))

    query += " ORDER BY full_name, id LIMIT 50"

    students = await _many(db, query, *params)
    results = []

    for s in students:
        _, installments, last_payment = await _get_or_create_profile(db, tenant, s)
        results.append(_build_profile_wire(s, installments, last_payment))

    return results


# =========================================================================
# ROUTE 2: GET /api/student-fee-profiles/{student_id}
# =========================================================================
@router.get("/api/student-fee-profiles/{student_id}")
async def get_student_fee_profile(
    student_id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user, "read")
    tenant = await _tenant(db, user, x_tenant_id)

    student = await _one(
        db,
        "SELECT id, full_name, class_name, academic_year, roll_number, parent_details FROM students WHERE tenant_id = ? AND id = ?",
        tenant, student_id,
    )
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    _, installments, last_payment = await _get_or_create_profile(db, tenant, student)
    return _build_profile_wire(student, installments, last_payment)


# =========================================================================
# ROUTE 3: POST /api/fees/collect
# =========================================================================
class FeeCollectRequest(BaseModel):
    studentId: str
    amount: Decimal = Field(gt=0)
    discount: Decimal = Field(default=Decimal("0.00"))
    installmentNames: list[str] = Field(min_items=1)
    paymentMode: str = Field(min_length=1)
    remarks: str | None = None
    chequeDetails: str | None = None
    transactionId: str | None = None
    academicYear: str | None = None


@router.post("/api/fees/collect", status_code=201)
async def collect_fee(
    data: FeeCollectRequest,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user, "write")
    tenant = await _tenant(db, user, x_tenant_id)

    try:
        student = await _one(
            db,
            "SELECT id, full_name, class_name, academic_year FROM students WHERE tenant_id = ? AND id = ?",
            tenant, data.studentId,
        )
        if not student:
            raise HTTPException(status_code=404, detail="Student not found")

        profile, installments, _ = await _get_or_create_profile(db, tenant, student)
        inst_by_name = {i["name"]: i for i in installments}

        amount_to_allocate = int(_minor(data.amount))
        discount_to_allocate = int(_minor(data.discount))
        payment_id = uuid4().hex
        receipt_number = f"REC-{uuid4().hex[:10].upper()}"
        now_iso = datetime.now(timezone.utc).isoformat()

        statements = []
        # Insert payment record
        # Note: Do not pass None to .bind() as Pyodide converts None to undefined which causes D1_TYPE_ERROR
        cols = [
            "id", "tenant_id", "profile_id", "receipt_number", "payment_date",
            "amount_paid", "discount", "payment_mode", "remarks", "student_name_snapshot"
        ]
        vals = [
            payment_id, tenant, profile["id"], receipt_number, now_iso,
            amount_to_allocate, discount_to_allocate, data.paymentMode,
            data.remarks or "", student["full_name"]
        ]

        if data.transactionId and data.transactionId.strip():
            cols.append("transaction_reference")
            vals.append(data.transactionId.strip())
        if data.chequeDetails and data.chequeDetails.strip():
            cols.append("cheque_details")
            vals.append(data.chequeDetails.strip())
        user_id = user.get("id") or user.get("sub")
        if user_id:
            cols.append("collected_by_user_id")
            vals.append(str(user_id))

        col_str = ", ".join(cols)
        placeholder_str = ", ".join(["?"] * len(cols))
        statements.append(
            db.prepare(f"INSERT INTO payments ({col_str}) VALUES ({placeholder_str})").bind(*vals)
        )

        pos = 0
        rem_amount = amount_to_allocate
        rem_disc = discount_to_allocate

        for name in data.installmentNames:
            inst = inst_by_name.get(name)
            if not inst:
                continue
            due = inst["amount_due"]
            current_paid = inst["paid_amount"]
            current_disc = inst["discount_amount"]
            balance = max(0, due - current_paid - current_disc)

            alloc_disc = min(rem_disc, balance)
            rem_disc -= alloc_disc
            balance_after_disc = max(0, balance - alloc_disc)

            alloc_paid = min(rem_amount, balance_after_disc)
            rem_amount -= alloc_paid

            new_paid = current_paid + alloc_paid
            new_disc = current_disc + alloc_disc
            new_status = "PAID" if (new_paid + new_disc >= due) else "PARTIAL"

            statements.append(
                db.prepare(
                    "UPDATE fee_installments SET paid_amount = ?, discount_amount = ?, status = ? WHERE id = ?"
                ).bind(int(new_paid), int(new_disc), new_status, inst["id"])
            )

            statements.append(
                db.prepare(
                    "INSERT INTO payment_allocations (id, payment_id, installment_id, position, amount_paid, discount) VALUES (?, ?, ?, ?, ?, ?)"
                ).bind(uuid4().hex, payment_id, inst["id"], int(pos), int(alloc_paid), int(alloc_disc))
            )
            pos += 1

        await db.batch(statements)
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        err = traceback.format_exc()
        raise HTTPException(status_code=500, detail=f"Collect error: {str(e)} -> {err}")

    return {
        "id": payment_id,
        "transactionId": payment_id,
        "receiptNumber": receipt_number,
        "studentId": student["id"],
        "studentName": student["full_name"],
        "paymentDate": now_iso,
        "amountPaid": float(data.amount),
        "discount": float(data.discount),
        "paymentMode": data.paymentMode,
        "paidForInstallments": data.installmentNames,
        "remarks": data.remarks,
    }


# =========================================================================
# ROUTE 4: GET /api/fees/dues
# =========================================================================
@router.get("/api/fees/dues")
async def get_outstanding_dues(
    academicYear: str | None = Query(default=None),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user, "read")
    tenant = await _tenant(db, user, x_tenant_id)

    query = "SELECT id, full_name, class_name, academic_year, roll_number, parent_details FROM students WHERE tenant_id = ? AND status = 'ACTIVE'"
    params = [tenant]
    if academicYear:
        query += " AND academic_year = ?"
        params.append(_year(academicYear))

    students = await _many(db, query, *params)
    dues_list = []

    for s in students:
        _, installments, last_payment = await _get_or_create_profile(db, tenant, s)
        profile_data = _build_profile_wire(s, installments, last_payment)
        if profile_data["dueFees"] > 0:
            dues_list.append(profile_data)

    dues_list.sort(key=lambda x: -x["dueFees"])
    return dues_list


# =========================================================================
# ROUTE 5: GET /api/fees/payments
# =========================================================================
@router.get("/api/fees/payments")
async def list_payments(
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user, "read")
    tenant = await _tenant(db, user, x_tenant_id)

    payments = await _many(
        db,
        "SELECT p.id, p.receipt_number, p.payment_date, p.amount_paid, p.discount, p.payment_mode, p.remarks, p.student_name_snapshot, p.profile_id "
        "FROM payments p WHERE p.tenant_id = ? AND p.voided_at IS NULL ORDER BY p.payment_date DESC LIMIT 100",
        tenant,
    )

    return [
        {
            "id": p["id"],
            "transactionId": p["id"],
            "receiptNumber": p["receipt_number"],
            "studentName": p.get("student_name_snapshot") or "Student",
            "paymentDate": p["payment_date"],
            "amountPaid": _major(p["amount_paid"]),
            "discount": _major(p["discount"]),
            "paymentMode": p["payment_mode"],
            "remarks": p.get("remarks"),
        }
        for p in payments
    ]
