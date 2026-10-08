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
    parent_phone = ""
    try:
        p = json.loads(student.get("parent_details") or "{}")
        parent_name = p.get("father", {}).get("name") or p.get("fatherName") or p.get("mother", {}).get("name") or p.get("motherName") or ""
        parent_phone = (
            p.get("fatherMobile")
            or p.get("motherMobile")
            or p.get("father", {}).get("mobile")
            or p.get("mother", {}).get("mobile")
            or ""
        )
    except Exception:
        pass
    if not parent_phone:
        try:
            c = json.loads(student.get("contact_details") or "{}")
            parent_phone = c.get("primaryContactNumber") or c.get("phone") or ""
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
            "admissionNumber": student.get("admission_number") or "",
            "className": student.get("class_name") or "",
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
        "admissionNumber": student.get("admission_number") or "",
        "className": student["class_name"],
        "academicYear": student["academic_year"],
        "rollNumber": student.get("roll_number") or "",
        "parentName": parent_name,
        "parentPhone": parent_phone,
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

    query = "SELECT id, full_name, admission_number, class_name, academic_year, roll_number, parent_details, contact_details FROM students WHERE tenant_id = ?"
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
        "SELECT id, full_name, class_name, academic_year, roll_number, parent_details, contact_details FROM students WHERE tenant_id = ? AND id = ?",
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


async def _generate_receipt_number(db, tenant: str, payment_date: datetime | None = None) -> str:
    dt = payment_date or datetime.now(timezone.utc)
    date_code = dt.strftime("%Y%m")
    row = await _one(db, "SELECT COUNT(*) AS total FROM payments WHERE tenant_id = ?", tenant)
    start_seq = max(1, int(row.get("total", 0)) + 1)
    seq = start_seq
    while True:
        candidate = f"REC-{date_code}-{seq:05d}"
        existing = await _one(
            db,
            "SELECT id FROM payments WHERE tenant_id = ? AND receipt_number = ?",
            tenant, candidate,
        )
        if not existing:
            return candidate
        seq += 1


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
            "SELECT id, full_name, admission_number, class_name, academic_year FROM students WHERE tenant_id = ? AND id = ?",
            tenant, data.studentId,
        )
        if not student:
            raise HTTPException(status_code=404, detail="Student not found")

        profile, installments, _ = await _get_or_create_profile(db, tenant, student)
        inst_by_name = {i["name"]: i for i in installments}

        amount_to_allocate = int(_minor(data.amount))
        discount_to_allocate = int(_minor(data.discount))
        payment_id = uuid4().hex
        receipt_number = await _generate_receipt_number(db, tenant)
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
        "admissionNumber": student.get("admission_number") or "",
        "className": student.get("class_name") or "",
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
@router.get("/fees/dues")
async def get_outstanding_dues(
    academicYear: str | None = Query(default=None),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user, "read")
    tenant = await _tenant(db, user, x_tenant_id)

    query = (
        "SELECT fp.id AS profile_id, s.id, s.full_name, s.admission_number, s.class_name, s.academic_year, "
        "s.roll_number, s.parent_details, s.contact_details, "
        "COALESCE(SUM(i.amount_due - i.paid_amount - i.discount_amount), 0) AS due_cents, "
        "COALESCE(SUM(i.amount_due), 0) AS total_cents, "
        "COALESCE(SUM(i.paid_amount), 0) AS paid_cents, "
        "COALESCE(SUM(i.discount_amount), 0) AS disc_cents "
        "FROM fee_profiles fp "
        "JOIN enrollments e ON e.id = fp.enrollment_id "
        "JOIN students s ON s.id = e.student_id "
        "JOIN fee_installments i ON i.profile_id = fp.id "
        "WHERE fp.tenant_id = ? AND s.status = 'ACTIVE' "
    )
    params = [tenant]
    if academicYear:
        query += "AND s.academic_year = ? "
        params.append(_year(academicYear))
    query += "GROUP BY fp.id HAVING due_cents > 0 ORDER BY due_cents DESC LIMIT 100"

    rows = await _many(db, query, *params)
    dues_list = []
    for r in rows:
        parent_name = ""
        parent_phone = ""
        try:
            p = json.loads(r.get("parent_details") or "{}")
            parent_name = p.get("father", {}).get("name") or p.get("fatherName") or p.get("mother", {}).get("name") or p.get("motherName") or ""
            parent_phone = (
                p.get("fatherMobile")
                or p.get("motherMobile")
                or p.get("father", {}).get("mobile")
                or p.get("mother", {}).get("mobile")
                or ""
            )
        except Exception:
            pass
        if not parent_phone:
            try:
                c = json.loads(r.get("contact_details") or "{}")
                parent_phone = c.get("primaryContactNumber") or c.get("phone") or ""
            except Exception:
                pass

        dues_list.append({
            "studentId": r["id"],
            "studentName": r["full_name"],
            "admissionNumber": r.get("admission_number") or "",
            "className": r["class_name"],
            "academicYear": r["academic_year"],
            "rollNumber": r.get("roll_number") or "",
            "parentName": parent_name,
            "parentMobile": parent_phone,
            "totalFees": _major(r["total_cents"]),
            "paidFees": _major(r["paid_cents"]),
            "discountFees": _major(r["disc_cents"]),
            "dueFees": _major(r["due_cents"]),
            "installments": [],
            "lastPayment": None,
        })

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
        "SELECT p.id, p.receipt_number, p.payment_date, p.amount_paid, p.discount, p.payment_mode, p.remarks, "
        "       p.student_name_snapshot, p.profile_id, s.admission_number, s.id AS student_id, e.class_name "
        "FROM payments p "
        "LEFT JOIN fee_profiles fp ON fp.id = p.profile_id "
        "LEFT JOIN enrollments e ON e.id = fp.enrollment_id "
        "LEFT JOIN students s ON s.id = e.student_id "
        "WHERE p.tenant_id = ? AND p.voided_at IS NULL ORDER BY p.payment_date DESC LIMIT 100",
        tenant,
    )

    return [
        {
            "id": p["id"],
            "transactionId": p["id"],
            "receiptNumber": p["receipt_number"],
            "studentId": p.get("student_id") or "",
            "studentName": p.get("student_name_snapshot") or "Student",
            "admissionNumber": p.get("admission_number") or "",
            "className": p.get("class_name") or "",
            "paymentDate": p["payment_date"],
            "amountPaid": _major(p["amount_paid"]),
            "discount": _major(p["discount"]),
            "paymentMode": p["payment_mode"],
            "remarks": p.get("remarks"),
        }
        for p in payments
    ]


# =========================================================================
# ROUTE 6: GET /api/reports/fees/report-summary
# =========================================================================
@router.get("/api/reports/fees/report-summary")
async def fee_report_summary(
    startDate: str | None = Query(default=None),
    endDate: str | None = Query(default=None),
    className: str | None = Query(default=None),
    paymentMode: str | None = Query(default=None),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    _permission(user, "read")
    tenant = await _tenant(db, user, x_tenant_id)

    sql = (
        "SELECT p.id, p.receipt_number, p.payment_date, p.amount_paid, p.discount, p.payment_mode, p.remarks, "
        "       s.id AS student_id, s.admission_number, s.full_name AS student_name, e.class_name, "
        "       COALESCE(e.roll_number, s.roll_number, '') AS roll_number, "
        "       s.parent_details, s.contact_details, u.full_name AS collector_name "
        "FROM payments p "
        "JOIN fee_profiles fp ON fp.id = p.profile_id "
        "JOIN enrollments e ON e.id = fp.enrollment_id "
        "JOIN students s ON s.id = e.student_id "
        "LEFT JOIN users u ON u.id = p.collected_by_user_id "
        "WHERE p.tenant_id = ? AND p.voided_at IS NULL"
    )
    params = [tenant]

    if startDate:
        sql += " AND p.payment_date >= ?"
        params.append(startDate)
    if endDate:
        sql += " AND p.payment_date <= ?"
        params.append(endDate + "T23:59:59")
    if className and className.strip():
        sql += " AND e.class_name = ?"
        params.append(className.strip())
    if paymentMode and paymentMode.strip() and paymentMode.upper() != "ALL":
        sql += " AND p.payment_mode = ?"
        params.append(paymentMode.strip().upper())

    sql += " ORDER BY p.payment_date DESC, p.id DESC"

    payments = await _many(db, sql, *params)

    alloc_map = {}
    if payments:
        allocations = await _many(
            db,
            "SELECT pa.payment_id, fi.name "
            "FROM payment_allocations pa "
            "JOIN fee_installments fi ON fi.id = pa.installment_id "
            "JOIN payments p ON p.id = pa.payment_id "
            "WHERE p.tenant_id = ? "
            "ORDER BY pa.position",
            tenant,
        )
        for a in allocations:
            alloc_map.setdefault(a["payment_id"], []).append(a["name"])

    total_collected_cents = 0
    total_discount_cents = 0
    class_totals = {}
    mode_totals = {}

    content = []
    for p in payments:
        paid_cents = int(p.get("amount_paid") or 0)
        disc_cents = int(p.get("discount") or 0)
        mode = p.get("payment_mode") or "CASH"
        c_name = p.get("class_name") or "Unknown"

        total_collected_cents += paid_cents
        total_discount_cents += disc_cents

        if c_name not in class_totals:
            class_totals[c_name] = [0, 0, 0]
        class_totals[c_name][0] += paid_cents
        class_totals[c_name][1] += disc_cents
        class_totals[c_name][2] += 1

        mode_totals[mode] = mode_totals.get(mode, 0) + paid_cents

        p_phone = ""
        try:
            pd = json.loads(p.get("parent_details") or "{}")
            p_phone = (
                pd.get("fatherMobile")
                or pd.get("motherMobile")
                or pd.get("father", {}).get("mobile")
                or pd.get("mother", {}).get("mobile")
                or ""
            )
        except Exception:
            pass
        if not p_phone:
            try:
                cd = json.loads(p.get("contact_details") or "{}")
                p_phone = cd.get("primaryContactNumber") or cd.get("phone") or ""
            except Exception:
                pass

        inst_names = alloc_map.get(p["id"]) or []

        content.append({
            "id": p["id"],
            "studentId": p.get("student_id") or "",
            "studentName": p.get("student_name") or "Student",
            "admissionNumber": p.get("admission_number") or "",
            "className": c_name,
            "rollNumber": p.get("roll_number") or "",
            "receiptNumber": p.get("receipt_number") or "",
            "paymentDate": p.get("payment_date") or "",
            "amountPaid": _major(paid_cents),
            "discount": _major(disc_cents),
            "paymentMode": mode,
            "paidForMonths": inst_names,
            "paidForInstallments": inst_names,
            "collectedBy": p.get("collector_name") or "Admin",
            "remarks": p.get("remarks"),
            "parentPhone": p_phone,
        })

    due_res = await _one(
        db,
        "SELECT COALESCE(SUM(i.amount_due - i.paid_amount - i.discount_amount), 0) AS due "
        "FROM fee_installments i JOIN fee_profiles fp ON fp.id = i.profile_id "
        "WHERE fp.tenant_id = ?",
        tenant,
    )
    total_due_cents = int(due_res.get("due") or 0)

    class_summaries = [
        {
            "classForAdmission": c_name,
            "totalCollectedInClass": _major(vals[0]),
            "totalDiscountInClass": _major(vals[1]),
            "transactionCountInClass": vals[2],
        }
        for c_name, vals in sorted(class_totals.items())
    ]

    payment_mode_summary = [
        {"paymentMode": mode, "totalAmount": _major(amt)}
        for mode, amt in sorted(mode_totals.items())
    ]

    return {
        "summary": {
            "totalCollected": _major(total_collected_cents),
            "totalDue": _major(total_due_cents),
            "totalDiscountGiven": _major(total_discount_cents),
            "totalTransactions": len(payments),
        },
        "classSummaries": class_summaries,
        "paymentModeSummary": payment_mode_summary,
        "transactionsPage": {
            "content": content,
            "number": 0,
            "size": len(content),
            "totalElements": len(content),
            "totalPages": 1,
        },
        "transactions": content,
    }

