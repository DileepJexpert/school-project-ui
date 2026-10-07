"""D1-backed HR, salary payroll, leave management, and staff attendance endpoints."""

from __future__ import annotations

import json
import secrets
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request, Response
from pydantic import BaseModel, Field

from school_auth import (
    _db,
    get_current_user,
    require_admin,
)
from school_overview import _many, _money, _one, _record, _results, _tenant, _detect_category

router = APIRouter(prefix="/api", tags=["hr"])
root_router = APIRouter(tags=["hr_root"])


# ═════════════════════════════════════════════════════════════════════════════
# MODELS
# ═════════════════════════════════════════════════════════════════════════════

class GenerateSalaryInput(BaseModel):
    month: int = Field(ge=1, le=12)
    year: int = Field(ge=2020, le=2050)


class ApplyLeaveInput(BaseModel):
    staffId: str
    staffName: str = ""
    department: str = "General"
    leaveType: str = "CASUAL"
    fromDate: str
    toDate: str
    totalDays: int = 1
    reason: str = ""


class ApproveLeaveInput(BaseModel):
    action: str = Field(pattern="^(APPROVE|REJECT)$")
    remarks: str | None = None


# ═════════════════════════════════════════════════════════════════════════════
# SALARY / PAYROLL
# ═════════════════════════════════════════════════════════════════════════════

def _wire_salary(r: dict) -> dict:
    category = _detect_category(r.get("designation"), r.get("department"))
    return {
        "id": r["id"],
        "staffId": r["staff_id"],
        "staffName": r["staff_name"],
        "department": r["department"],
        "designation": r["designation"],
        "category": category,
        "month": r["month"],
        "year": r["year"],
        "basicPay": _money(r["basic_pay"]),
        "hra": _money(r["hra"]),
        "da": _money(r["da"]),
        "ta": _money(r["ta"]),
        "otherAllowances": _money(r["other_allowances"]),
        "grossSalary": _money(r["gross_salary"]),
        "pf": _money(r["pf"]),
        "tax": _money(r["tax"]),
        "otherDeductions": _money(r["other_deductions"]),
        "totalDeductions": _money(r["total_deductions"]),
        "netSalary": _money(r["net_salary"]),
        "status": r["status"],
        "paymentMode": r.get("payment_mode") or "BANK_TRANSFER",
        "transactionRef": r.get("transaction_ref"),
        "generatedBy": r["generated_by"],
        "generatedAt": r["generated_at"],
        "paidAt": r.get("paid_at"),
    }


async def get_salaries(
    month: int = Query(..., ge=1, le=12),
    year: int = Query(..., ge=2020, le=2050),
    category: str | None = Query(default=None),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        rows = await _many(
            db,
            "SELECT * FROM salary_records WHERE tenant_id = ? AND month = ? AND year = ? "
            "ORDER BY staff_name ASC",
            tenant, month, year,
        )
        wired = [_wire_salary(r) for r in rows]
        if category and category.strip() and category.strip().upper() != "ALL":
            cat_target = category.strip().upper()
            wired = [w for w in wired if (w.get("category") or "").upper() == cat_target]
        return wired
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to fetch salaries: {exc}")


async def generate_salaries(
    data: GenerateSalaryInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        month = data.month
        year = data.year
        admin_name = user.get("fullName") or "Administrator"
        now_iso = datetime.now(timezone.utc).isoformat()

        # Fetch all active staff
        staff_rows = await _many(
            db,
            "SELECT * FROM staff WHERE tenant_id = ? AND deleted_at IS NULL AND status = 'ACTIVE'",
            tenant,
        )

        for s in staff_rows:
            staff_id = s["id"]
            # Check if record already exists
            existing = await _one(
                db,
                "SELECT id FROM salary_records WHERE tenant_id = ? AND staff_id = ? AND month = ? AND year = ?",
                tenant, staff_id, month, year,
            )
            if existing:
                continue

            basic = s.get("basic_salary") or 2500000  # Default 25k in minor units
            hra = int(round(basic * 0.20))
            da = int(round(basic * 0.10))
            ta = int(round(basic * 0.05))
            other_allow = 0
            gross = basic + hra + da + ta
            pf = int(round(basic * 0.12))
            tax = int(round(basic * 0.05))
            other_deduct = 0
            total_deduct = pf + tax + other_deduct
            net = gross - total_deduct

            rec_id = f"sal_{secrets.token_hex(12)}"
            await db.prepare(
                "INSERT INTO salary_records (id, tenant_id, staff_id, staff_name, department, designation, "
                "month, year, basic_pay, hra, da, ta, other_allowances, pf, tax, other_deductions, "
                "gross_salary, total_deductions, net_salary, status, payment_mode, generated_by, generated_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'GENERATED', 'BANK_TRANSFER', ?, ?)"
            ).bind(
                rec_id, tenant, staff_id, s["full_name"], s["department"], s["designation"],
                month, year, basic, hra, da, ta, other_allow, pf, tax, other_deduct,
                gross, total_deduct, net, admin_name, now_iso,
            ).run()

        # Return updated records
        rows = await _many(
            db,
            "SELECT * FROM salary_records WHERE tenant_id = ? AND month = ? AND year = ? "
            "ORDER BY staff_name ASC",
            tenant, month, year,
        )
        return [_wire_salary(r) for r in rows]
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to generate salaries: {exc}")


async def mark_salary_paid(
    id: str,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        now_iso = datetime.now(timezone.utc).isoformat()
        await db.prepare(
            "UPDATE salary_records SET status = 'PAID', paid_at = ? WHERE id = ? AND tenant_id = ?"
        ).bind(now_iso, id, tenant).run()

        updated = await _one(
            db,
            "SELECT * FROM salary_records WHERE id = ? AND tenant_id = ?",
            id, tenant,
        )
        if not updated:
            raise HTTPException(status_code=404, detail="Salary record not found")
        return _wire_salary(updated)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to mark salary paid: {exc}")


# ═════════════════════════════════════════════════════════════════════════════
# LEAVE MANAGEMENT
# ═════════════════════════════════════════════════════════════════════════════

def _wire_leave(r: dict) -> dict:
    return {
        "id": r["id"],
        "staffId": r["staff_id"],
        "staffName": r["staff_name"],
        "department": r["department"],
        "leaveType": r["leave_type"],
        "fromDate": r["from_date"],
        "toDate": r["to_date"],
        "totalDays": r["total_days"],
        "reason": r["reason"],
        "status": r["status"],
        "appliedAt": r["applied_at"],
        "approvedBy": r.get("approved_by"),
        "approverRemarks": r.get("approver_remarks"),
        "approvedAt": r.get("approved_at"),
    }


async def get_leaves(
    status: str | None = Query(default=None),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        if status and status.strip():
            rows = await _many(
                db,
                "SELECT * FROM leave_requests WHERE tenant_id = ? AND status = ? ORDER BY applied_at DESC",
                tenant, status.strip().upper(),
            )
        else:
            rows = await _many(
                db,
                "SELECT * FROM leave_requests WHERE tenant_id = ? ORDER BY applied_at DESC",
                tenant,
            )
        return [_wire_leave(r) for r in rows]
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to fetch leaves: {exc}")


async def apply_leave(
    data: ApplyLeaveInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        leave_id = f"lv_{secrets.token_hex(12)}"
        now_iso = datetime.now(timezone.utc).isoformat()

        staff_name = data.staffName.strip()
        dept = data.department.strip()
        if not staff_name:
            staff_row = await _one(db, "SELECT full_name, department FROM staff WHERE id = ? AND tenant_id = ?", data.staffId, tenant)
            if staff_row:
                staff_name = staff_row.get("full_name") or "Staff Member"
                dept = staff_row.get("department") or dept

        await db.prepare(
            "INSERT INTO leave_requests (id, tenant_id, staff_id, staff_name, department, leave_type, "
            "from_date, to_date, total_days, reason, status, applied_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'PENDING', ?)"
        ).bind(
            leave_id, tenant, data.staffId, staff_name, dept,
            data.leaveType.strip().upper(), data.fromDate, data.toDate,
            data.totalDays, data.reason.strip(), now_iso,
        ).run()

        created = await _one(db, "SELECT * FROM leave_requests WHERE id = ?", leave_id)
        return _wire_leave(created)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to apply leave: {exc}")


async def approve_leave(
    id: str,
    data: ApproveLeaveInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        admin_name = user.get("fullName") or "Administrator"
        now_iso = datetime.now(timezone.utc).isoformat()
        new_status = "APPROVED" if data.action == "APPROVE" else "REJECTED"

        await db.prepare(
            "UPDATE leave_requests SET status = ?, approved_by = ?, approver_remarks = ?, approved_at = ? "
            "WHERE id = ? AND tenant_id = ?"
        ).bind(new_status, admin_name, data.remarks or "", now_iso, id, tenant).run()

        updated = await _one(db, "SELECT * FROM leave_requests WHERE id = ? AND tenant_id = ?", id, tenant)
        if not updated:
            raise HTTPException(status_code=404, detail="Leave request not found")
        return _wire_leave(updated)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to approve/reject leave: {exc}")


# ═════════════════════════════════════════════════════════════════════════════
# STAFF ATTENDANCE
# ═════════════════════════════════════════════════════════════════════════════

def _wire_attendance(r: dict) -> dict:
    return {
        "id": r["id"],
        "staffId": r["staff_id"],
        "staffName": r["staff_name"],
        "department": r["department"],
        "date": r["date"],
        "status": r["status"],
        "checkInTime": r.get("check_in_time"),
        "checkOutTime": r.get("check_out_time"),
        "remarks": r.get("remarks") or "",
        "markedBy": r.get("marked_by") or "",
        "markedAt": r.get("marked_at") or "",
    }


async def get_staff_attendance_by_date(
    date: str = Query(..., pattern=r"^\d{4}-\d{2}-\d{2}$"),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        rows = await _many(
            db,
            "SELECT * FROM staff_attendance WHERE tenant_id = ? AND date = ?",
            tenant, date,
        )
        return [_wire_attendance(r) for r in rows]
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to fetch staff attendance: {exc}")


async def mark_staff_attendance(
    records: list[dict],
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        admin_name = user.get("fullName") or "Administrator"
        now_iso = datetime.now(timezone.utc).isoformat()

        for rec in records:
            staff_id = rec.get("staffId") or ""
            staff_name = rec.get("staffName") or ""
            date_str = rec.get("date") or datetime.now(timezone.utc).strftime("%Y-%m-%d")
            status = (rec.get("status") or "PRESENT").upper()

            existing = await _one(
                db,
                "SELECT id FROM staff_attendance WHERE tenant_id = ? AND staff_id = ? AND date = ?",
                tenant, staff_id, date_str,
            )
            if existing:
                await db.prepare(
                    "UPDATE staff_attendance SET status = ?, marked_by = ?, marked_at = ? WHERE id = ?"
                ).bind(status, admin_name, now_iso, existing["id"]).run()
            else:
                att_id = f"sa_{secrets.token_hex(12)}"
                await db.prepare(
                    "INSERT INTO staff_attendance (id, tenant_id, staff_id, staff_name, department, "
                    "date, status, remarks, marked_by, marked_at) "
                    "VALUES (?, ?, ?, ?, 'General', ?, ?, '', ?, ?)"
                ).bind(att_id, tenant, staff_id, staff_name, date_str, status, admin_name, now_iso).run()

        return {"message": "Attendance marked successfully", "count": len(records)}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to mark staff attendance: {exc}")


# ═════════════════════════════════════════════════════════════════════════════
# ROUTER REGISTRATION
# ═════════════════════════════════════════════════════════════════════════════

def _register_hr_routes(r: APIRouter):
    r.add_api_route("/salary", get_salaries, methods=["GET"])
    r.add_api_route("/salary/generate", generate_salaries, methods=["POST"])
    r.add_api_route("/salary/{id}/pay", mark_salary_paid, methods=["PUT"])

    r.add_api_route("/leave", get_leaves, methods=["GET"])
    r.add_api_route("/leave/apply", apply_leave, methods=["POST"])
    r.add_api_route("/leave/{id}/approve", approve_leave, methods=["PUT"])

    r.add_api_route("/staff-attendance/date", get_staff_attendance_by_date, methods=["GET"])
    r.add_api_route("/staff-attendance/mark", mark_staff_attendance, methods=["POST"])


_register_hr_routes(router)
_register_hr_routes(root_router)
