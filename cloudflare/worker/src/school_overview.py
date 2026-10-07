"""D1-backed admin overview endpoints used by the Flutter dashboard."""

from __future__ import annotations

from datetime import date
import json

from fastapi import APIRouter, Depends, Header, HTTPException

from school_auth import _db, require_admin

router = APIRouter(prefix="/api", tags=["overview"])
root_router = APIRouter(tags=["overview_root"])


def _detect_category(designation: str | None, department: str | None, explicit_cat: str | None = None) -> str:
    if explicit_cat and explicit_cat.strip():
        c = explicit_cat.strip().upper()
        if c in ("TEACHER", "DRIVER", "PEON", "ADMIN", "ACCOUNTANT", "SECURITY", "OTHER"):
            return c
    text = f"{(designation or '').lower()} {(department or '').lower()}".strip()
    if any(k in text for k in ("driver", "conductor", "transport", "bus", "van")):
        return "DRIVER"
    if any(k in text for k in ("peon", "helper", "attendant", "cleaner", "sweeper", "maid", "support", "ayah", "cook", "peon")):
        return "PEON"
    if any(k in text for k in ("teacher", "faculty", "lecturer", "educator", "prt", "tgt", "pgt", "headmaster", "teaching", "academic", "math", "science", "english", "hindi", "social", "art", "music", "computer")):
        return "TEACHER"
    if any(k in text for k in ("account", "cashier", "finance", "billing")):
        return "ACCOUNTANT"
    if any(k in text for k in ("security", "guard", "watchman")):
        return "SECURITY"
    if any(k in text for k in ("admin", "clerk", "principal", "manager", "office", "receptionist", "director")):
        return "ADMIN"
    return "OTHER"


def _record(value) -> dict:
    if value is None:
        return {}
    if hasattr(value, "to_py"):
        value = value.to_py()
    return dict(value)


def _results(value) -> list[dict]:
    if hasattr(value, "to_py"):
        value = value.to_py()
    if isinstance(value, dict):
        value = value.get("results", [])
    return [_record(item) for item in value]


def _prepare_sql(sql: str, params: list | tuple) -> tuple[str, list]:
    new_params = []
    parts = sql.split("?")
    if len(parts) - 1 != len(params):
        return sql, list(params)
    out_sql = []
    for i, p in enumerate(params):
        out_sql.append(parts[i])
        if p is None:
            out_sql.append("NULL")
        else:
            out_sql.append("?")
            new_params.append(p)
    out_sql.append(parts[-1])
    return "".join(out_sql), new_params


async def _run(db, sql: str, *bindings):
    s, b = _prepare_sql(sql, bindings)
    stmt = db.prepare(s)
    if b:
        stmt = stmt.bind(*b)
    return await stmt.run()


async def _one(db, sql: str, *bindings) -> dict:
    s, b = _prepare_sql(sql, bindings)
    stmt = db.prepare(s)
    if b:
        stmt = stmt.bind(*b)
    return _record(await stmt.first())


async def _many(db, sql: str, *bindings) -> list[dict]:
    s, b = _prepare_sql(sql, bindings)
    stmt = db.prepare(s)
    if b:
        stmt = stmt.bind(*b)
    return _results(await stmt.all())


_TENANT_CACHE: dict[str, tuple[bool, float]] = {}


async def _tenant(db, user: dict, requested: str | None) -> str:
    # get_current_user already rejects a school token paired with another
    # X-Tenant-ID. A platform admin can explicitly select an active school.
    user_tenant = user.get("tenantId")
    requested_tenant = (requested or "").strip().lower()
    if user_tenant and requested_tenant and requested_tenant != user_tenant:
        raise HTTPException(status_code=403, detail="Tenant does not match token")
    tenant = user_tenant or requested_tenant
    if not tenant:
        raise HTTPException(status_code=400, detail="School code required")
    if user_tenant == tenant:
        return tenant
    import time
    now = time.time()
    cached = _TENANT_CACHE.get(tenant)
    if cached and now < cached[1]:
        if not cached[0]:
            raise HTTPException(status_code=404, detail="School not found")
        return tenant
    school = await _one(db, "SELECT active FROM tenants WHERE id = ?", tenant)
    is_active = bool(school and school.get("active"))
    _TENANT_CACHE[tenant] = (is_active, now + 300.0)
    if not is_active:
        raise HTTPException(status_code=404, detail="School not found")
    return tenant


def _money(minor_units: int | None) -> float:
    return (minor_units or 0) / 100.0


_PAYMENTS = (
    "FROM payments p "
    "JOIN fee_profiles fp ON fp.id = p.profile_id "
    "JOIN enrollments e ON e.id = fp.enrollment_id "
    "WHERE p.tenant_id = ? AND fp.tenant_id = ? AND e.tenant_id = ? "
    "AND p.voided_at IS NULL"
)


@router.get("/reports/school-summary")
async def school_summary(
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    students = await _one(
        db, "SELECT COUNT(*) AS total FROM students WHERE tenant_id = ? AND status = 'ACTIVE'",
        tenant,
    )
    classes = await _many(
        db, "SELECT class_name, COUNT(*) AS total FROM students "
        "WHERE tenant_id = ? AND status = 'ACTIVE' GROUP BY class_name ORDER BY class_name",
        tenant,
    )
    totals = await _one(
        db, "SELECT COUNT(*) AS transactions, COALESCE(SUM(p.amount_paid), 0) AS collected, "
        "COALESCE(SUM(p.discount), 0) AS discounts " + _PAYMENTS,
        tenant, tenant, tenant,
    )
    outstanding = await _one(
        db, "SELECT COALESCE(SUM(i.amount_due - i.paid_amount - i.discount_amount), 0) AS due "
        "FROM fee_installments i JOIN fee_profiles fp ON fp.id = i.profile_id "
        "JOIN enrollments e ON e.id = fp.enrollment_id "
        "WHERE fp.tenant_id = ? AND e.tenant_id = ?",
        tenant, tenant,
    )
    months = await _many(
        db, "SELECT substr(p.payment_date, 1, 7) AS period, "
        "SUM(p.amount_paid) AS amount " + _PAYMENTS +
        " GROUP BY substr(p.payment_date, 1, 7) ORDER BY period",
        tenant, tenant, tenant,
    )
    modes = await _many(
        db, "SELECT p.payment_mode AS mode, SUM(p.amount_paid) AS amount " + _PAYMENTS +
        " GROUP BY p.payment_mode ORDER BY p.payment_mode",
        tenant, tenant, tenant,
    )
    return {
        "totalStudents": students.get("total", 0),
        "enrollmentByClass": {r["class_name"]: r["total"] for r in classes},
        "totalFeesCollected": _money(totals.get("collected")),
        "totalFeesDue": _money(outstanding.get("due")),
        "totalDiscountGiven": _money(totals.get("discounts")),
        "totalTransactions": totals.get("transactions", 0),
        "monthlyCollections": [
            {
                "month": int(r["period"][5:7]),
                "year": int(r["period"][:4]),
                "label": r["period"],
                "amount": _money(r["amount"]),
            }
            for r in months
        ],
        "paymentModeSummary": [
            {"paymentMode": r["mode"], "totalAmount": _money(r["amount"])}
            for r in modes
        ],
    }


@router.get("/staff/dashboard")
async def staff_dashboard(
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    tenant = await _tenant(db, user, x_tenant_id)
    today = date.today().isoformat()
    s1, b1 = _prepare_sql(
        "SELECT id, full_name, department, designation, basic_salary, status, details "
        "FROM staff WHERE tenant_id = ? AND deleted_at IS NULL",
        [tenant],
    )
    s2, b2 = _prepare_sql(
        "SELECT COUNT(*) AS total FROM leave_requests WHERE tenant_id = ? AND status = 'PENDING'",
        [tenant],
    )
    s3, b3 = _prepare_sql(
        "SELECT staff_id FROM leave_requests WHERE tenant_id = ? AND status = 'APPROVED' "
        "AND from_date <= ? AND to_date >= ?",
        [tenant, today, today],
    )

    try:
        res = await db.batch([
            db.prepare(s1).bind(*b1),
            db.prepare(s2).bind(*b2),
            db.prepare(s3).bind(*b3),
        ])
        res_py = res.to_py() if hasattr(res, "to_py") else res
        all_staff = _results(res_py[0]) if len(res_py) > 0 else []
        leaves_rows = _results(res_py[1]) if len(res_py) > 1 else []
        pending_leaves_count = leaves_rows[0].get("total", 0) if leaves_rows else 0
        approved_leaves = _results(res_py[2]) if len(res_py) > 2 else []
    except Exception:
        all_staff = await _many(db, s1, *b1)
        leaves_rows = await _many(db, s2, *b2)
        pending_leaves_count = leaves_rows[0].get("total", 0) if leaves_rows else 0
        approved_leaves = await _many(db, s3, *b3)

    on_leave_ids = {r.get("staff_id") for r in approved_leaves if r.get("staff_id")}

    cat_keys = ["TEACHER", "DRIVER", "PEON", "ADMIN", "ACCOUNTANT", "SECURITY", "OTHER"]
    cat_meta = {
        "TEACHER": {"label": "Teachers", "icon": "school"},
        "DRIVER": {"label": "Drivers & Transport", "icon": "directions_bus"},
        "PEON": {"label": "Peons & Support Staff", "icon": "handyman"},
        "ADMIN": {"label": "Administration", "icon": "admin_panel_settings"},
        "ACCOUNTANT": {"label": "Accounts & Finance", "icon": "account_balance"},
        "SECURITY": {"label": "Security Staff", "icon": "shield"},
        "OTHER": {"label": "Other Staff", "icon": "badge"},
    }

    groups: dict[str, dict] = {
        k: {
            "category": k,
            "label": cat_meta[k]["label"],
            "icon": cat_meta[k]["icon"],
            "count": 0,
            "activeCount": 0,
            "onLeaveToday": 0,
            "presentToday": 0,
            "totalSalary": 0.0,
            "avgSalary": 0.0,
            "staffPercentage": 0.0,
            "payrollPercentage": 0.0,
        }
        for k in cat_keys
    }

    total_staff_count = len(all_staff)
    active_staff_count = 0
    total_payroll_amount = 0.0
    department_counts: dict[str, int] = {}

    on_leave_today_count = 0
    for s in all_staff:
        dep = s.get("department") or "General"
        department_counts[dep] = department_counts.get(dep, 0) + 1
        det = {}
        if s.get("details"):
            try:
                det = json.loads(s["details"])
            except Exception:
                det = {}
        cat = _detect_category(s.get("designation"), s.get("department"), det.get("category"))
        if cat not in groups:
            groups[cat] = {
                "category": cat,
                "label": cat.replace("_", " ").title(),
                "icon": "badge",
                "count": 0,
                "activeCount": 0,
                "onLeaveToday": 0,
                "presentToday": 0,
                "totalSalary": 0.0,
                "avgSalary": 0.0,
                "staffPercentage": 0.0,
                "payrollPercentage": 0.0,
            }
        g = groups[cat]
        g["count"] += 1
        is_active = (s.get("status") or "ACTIVE").upper() == "ACTIVE"
        if is_active:
            active_staff_count += 1
            g["activeCount"] += 1
            salary_val = (s.get("basic_salary") or 0) / 100.0
            g["totalSalary"] += salary_val
            total_payroll_amount += salary_val
            if s.get("id") in on_leave_ids:
                g["onLeaveToday"] += 1
                on_leave_today_count += 1
            else:
                g["presentToday"] += 1

    category_breakdown = []
    always_include = {"TEACHER", "DRIVER", "PEON", "ADMIN"}
    for k in cat_keys:
        if k in groups:
            g = groups[k]
            if g["count"] > 0 or k in always_include:
                if g["activeCount"] > 0:
                    g["avgSalary"] = round(g["totalSalary"] / g["activeCount"], 2)
                g["totalSalary"] = round(g["totalSalary"], 2)
                if total_staff_count > 0:
                    g["staffPercentage"] = round((g["count"] / total_staff_count) * 100, 1)
                if total_payroll_amount > 0:
                    g["payrollPercentage"] = round((g["totalSalary"] / total_payroll_amount) * 100, 1)
                category_breakdown.append(g)

    for k, g in groups.items():
        if k not in cat_keys and g["count"] > 0:
            if g["activeCount"] > 0:
                g["avgSalary"] = round(g["totalSalary"] / g["activeCount"], 2)
            g["totalSalary"] = round(g["totalSalary"], 2)
            if total_staff_count > 0:
                g["staffPercentage"] = round((g["count"] / total_staff_count) * 100, 1)
            if total_payroll_amount > 0:
                g["payrollPercentage"] = round((g["totalSalary"] / total_payroll_amount) * 100, 1)
            category_breakdown.append(g)

    return {
        "totalStaff": total_staff_count,
        "activeStaff": active_staff_count,
        "onLeaveToday": on_leave_today_count,
        "pendingLeaveRequests": pending_leaves_count,
        "departmentWise": department_counts,
        "totalMonthlyPayroll": round(total_payroll_amount, 2),
        "categoryBreakdown": category_breakdown,
    }


root_router.add_api_route("/staff/dashboard", staff_dashboard, methods=["GET"])
