"""D1-backed users and staff account management endpoints."""

from __future__ import annotations

import json
import secrets
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request, Response
from pydantic import BaseModel, Field

from school_auth import (
    _db,
    _verify_password,
    _wire,
    get_current_user,
    password_hash,
    require_admin,
)
from school_overview import _many, _one, _record, _results, _tenant, _detect_category, staff_dashboard


class CreateUserInput(BaseModel):
    fullName: str = Field(min_length=1, max_length=200)
    email: str = Field(min_length=3, max_length=320)
    phone: str | None = Field(default="")
    role: str = Field(min_length=1, max_length=40)
    password: str = Field(min_length=1)
    linkedEntityId: str | None = None
    extraPermissions: list[str] = Field(default_factory=list)


class UpdateUserInput(BaseModel):
    fullName: str = Field(min_length=1, max_length=200)
    email: str = Field(min_length=3, max_length=320)
    phone: str | None = Field(default="")
    role: str = Field(min_length=1, max_length=40)
    password: str | None = None
    linkedEntityId: str | None = None
    extraPermissions: list[str] = Field(default_factory=list)


class ChangePasswordInput(BaseModel):
    currentPassword: str = Field(min_length=1)
    newPassword: str = Field(min_length=8)


# ═════════════════════════════════════════════════════════════════════════════
# USERS HANDLERS
# ═════════════════════════════════════════════════════════════════════════════

async def list_users(
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
    role: str | None = Query(default=None),
    search: str | None = Query(default=None),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        sql = "SELECT * FROM users WHERE (tenant_id = ? OR scope = ?)"
        params = [tenant, tenant]

        if role:
            sql += " AND role = ?"
            params.append(role)

        sql += " ORDER BY active DESC, created_at DESC"
        rows = await _many(db, sql, *params)

        if search and search.strip():
            q = search.strip().lower()
            rows = [
                r for r in rows
                if q in (r.get("full_name") or "").lower()
                or q in (r.get("email") or "").lower()
                or q in (r.get("phone") or "").lower()
                or q in (r.get("role") or "").lower()
            ]

        return [_wire(r) for r in rows]
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to list users: {exc}")


async def change_password(
    data: ChangePasswordInput,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
):
    try:
        user_id = user.get("id") or user.get("userId")
        user_row = await _one(db, "SELECT * FROM users WHERE id = ?", user_id)
        if not user_row:
            raise HTTPException(status_code=404, detail="User not found")

        is_valid, _ = _verify_password(data.currentPassword, user_row["password_hash"])
        if not is_valid:
            raise HTTPException(status_code=400, detail="Current password is incorrect")

        new_hash = password_hash(data.newPassword)
        await db.prepare("UPDATE users SET password_hash = ? WHERE id = ?").bind(new_hash, user_id).run()
        return {"message": "Password changed successfully"}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to change password: {exc}")


async def get_user_by_id(
    user_id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        user_row = await _one(
            db,
            "SELECT * FROM users WHERE id = ? AND (tenant_id = ? OR scope = ?)",
            user_id, tenant, tenant,
        )
        if not user_row:
            raise HTTPException(status_code=404, detail="User not found")
        return _wire(user_row)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to get user: {exc}")


async def create_user(
    data: CreateUserInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        email = data.email.strip().lower()
        full_name = data.fullName.strip()
        phone = (data.phone or "").strip()
        role = data.role.strip().upper()

        existing = await _one(
            db,
            "SELECT id, active FROM users WHERE scope = ? AND email = ?",
            tenant, email,
        )
        now_iso = datetime.now(timezone.utc).isoformat()
        pwd_hash = password_hash(data.password)
        extra_perm_str = json.dumps(data.extraPermissions or [])

        if existing:
            if existing.get("active"):
                raise HTTPException(status_code=400, detail="An account with this email already exists")
            user_id = existing["id"]
            if data.linkedEntityId:
                await db.prepare(
                    "UPDATE users SET password_hash = ?, full_name = ?, phone = ?, role = ?, "
                    "linked_entity_id = ?, extra_permissions = ?, active = 1, tenant_id = ? WHERE id = ?"
                ).bind(pwd_hash, full_name, phone, role, data.linkedEntityId, extra_perm_str, tenant, user_id).run()
            else:
                await db.prepare(
                    "UPDATE users SET password_hash = ?, full_name = ?, phone = ?, role = ?, "
                    "linked_entity_id = NULL, extra_permissions = ?, active = 1, tenant_id = ? WHERE id = ?"
                ).bind(pwd_hash, full_name, phone, role, extra_perm_str, tenant, user_id).run()
        else:
            user_id = f"usr_{secrets.token_hex(12)}"
            if data.linkedEntityId:
                await db.prepare(
                    "INSERT INTO users (id, scope, tenant_id, email, password_hash, full_name, phone, "
                    "role, linked_entity_id, extra_permissions, active, created_at) "
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)"
                ).bind(
                    user_id, tenant, tenant, email, pwd_hash, full_name, phone,
                    role, data.linkedEntityId, extra_perm_str, now_iso,
                ).run()
            else:
                await db.prepare(
                    "INSERT INTO users (id, scope, tenant_id, email, password_hash, full_name, phone, "
                    "role, linked_entity_id, extra_permissions, active, created_at) "
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, 1, ?)"
                ).bind(
                    user_id, tenant, tenant, email, pwd_hash, full_name, phone,
                    role, extra_perm_str, now_iso,
                ).run()

        created = await _one(db, "SELECT * FROM users WHERE id = ?", user_id)
        return _wire(created)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to create user: {type(exc).__name__}: {exc}")


async def update_user(
    user_id: str,
    data: UpdateUserInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        existing = await _one(
            db,
            "SELECT * FROM users WHERE id = ? AND (tenant_id = ? OR scope = ?)",
            user_id, tenant, tenant,
        )
        if not existing:
            raise HTTPException(status_code=404, detail="User account not found")

        full_name = data.fullName.strip()
        email = data.email.strip().lower()
        phone = (data.phone or "").strip()
        role = data.role.strip().upper()
        extra_perm_str = json.dumps(data.extraPermissions or [])

        if data.password and data.password.strip():
            new_pwd_hash = password_hash(data.password.strip())
            if data.linkedEntityId:
                await db.prepare(
                    "UPDATE users SET full_name = ?, email = ?, phone = ?, role = ?, "
                    "linked_entity_id = ?, extra_permissions = ?, password_hash = ? WHERE id = ?"
                ).bind(full_name, email, phone, role, data.linkedEntityId, extra_perm_str, new_pwd_hash, user_id).run()
            else:
                await db.prepare(
                    "UPDATE users SET full_name = ?, email = ?, phone = ?, role = ?, "
                    "linked_entity_id = NULL, extra_permissions = ?, password_hash = ? WHERE id = ?"
                ).bind(full_name, email, phone, role, extra_perm_str, new_pwd_hash, user_id).run()
        else:
            if data.linkedEntityId:
                await db.prepare(
                    "UPDATE users SET full_name = ?, email = ?, phone = ?, role = ?, "
                    "linked_entity_id = ?, extra_permissions = ? WHERE id = ?"
                ).bind(full_name, email, phone, role, data.linkedEntityId, extra_perm_str, user_id).run()
            else:
                await db.prepare(
                    "UPDATE users SET full_name = ?, email = ?, phone = ?, role = ?, "
                    "linked_entity_id = NULL, extra_permissions = ? WHERE id = ?"
                ).bind(full_name, email, phone, role, extra_perm_str, user_id).run()

        updated = await _one(db, "SELECT * FROM users WHERE id = ?", user_id)
        return _wire(updated)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to update user: {type(exc).__name__}: {exc}")


async def delete_user(
    user_id: str,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        existing = await _one(
            db,
            "SELECT * FROM users WHERE id = ? AND (tenant_id = ? OR scope = ?)",
            user_id, tenant, tenant,
        )
        if not existing:
            raise HTTPException(status_code=404, detail="User account not found")

        now_iso = datetime.now(timezone.utc).isoformat()
        await db.prepare("UPDATE users SET active = 0 WHERE id = ?").bind(user_id).run()
        await db.prepare("UPDATE auth_sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL").bind(now_iso, user_id).run()
        return {"message": "Staff account deactivated successfully"}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to deactivate user: {type(exc).__name__}: {exc}")


# ═════════════════════════════════════════════════════════════════════════════
# STAFF HR HANDLERS
# ═════════════════════════════════════════════════════════════════════════════

def _wire_staff(s: dict) -> dict:
    details = {}
    if s.get("details"):
        try:
            details = json.loads(s["details"])
        except Exception:
            pass
    category = details.get("category") or _detect_category(s.get("designation"), s.get("department"))
    return {
        "id": s["id"],
        "employeeId": s["employee_id"],
        "fullName": s["full_name"],
        "email": s["email"],
        "phone": s["phone"],
        "department": s["department"],
        "designation": s["designation"],
        "category": category,
        "dateOfJoining": s.get("date_of_joining") or "",
        "dateOfLeaving": s.get("date_of_leaving"),
        "basicSalary": (s.get("basic_salary") or 0) / 100.0,
        "status": s.get("status") or "ACTIVE",
        "qualification": details.get("qualification", ""),
        "details": details,
        "createdAt": s.get("created_at"),
    }


class StaffPayloadInput(BaseModel):
    fullName: str = Field(min_length=1, max_length=200)
    email: str = Field(min_length=3, max_length=320)
    phone: str = Field(default="")
    department: str = Field(default="General")
    designation: str = Field(default="Staff")
    category: str = Field(default="")
    qualification: str = Field(default="")
    basicSalary: float = Field(default=0.0)
    status: str = Field(default="ACTIVE")


async def list_staff(
    category: str | None = Query(default=None),
    department: str | None = Query(default=None),
    search: str | None = Query(default=None),
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        rows = await _many(
            db,
            "SELECT * FROM staff WHERE tenant_id = ? AND deleted_at IS NULL ORDER BY full_name ASC",
            tenant,
        )
        wired = [_wire_staff(r) for r in rows]
        if category and category.strip() and category.strip().upper() != "ALL":
            cat_target = category.strip().upper()
            wired = [w for w in wired if (w.get("category") or "").upper() == cat_target]
        if department and department.strip() and department.strip().upper() != "ALL":
            dept_target = department.strip().lower()
            wired = [w for w in wired if (w.get("department") or "").lower() == dept_target]
        if search and search.strip():
            q = search.strip().lower()
            wired = [
                w for w in wired
                if q in (w.get("fullName") or "").lower()
                or q in (w.get("employeeId") or "").lower()
                or q in (w.get("designation") or "").lower()
                or q in (w.get("department") or "").lower()
            ]
        return wired
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to list staff: {exc}")


async def get_staff_by_id(
    staff_id: str,
    db=Depends(_db),
    user: dict = Depends(get_current_user),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        s = await _one(
            db,
            "SELECT * FROM staff WHERE id = ? AND tenant_id = ? AND deleted_at IS NULL",
            staff_id, tenant,
        )
        if not s:
            raise HTTPException(status_code=404, detail="Staff member not found")
        return _wire_staff(s)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to get staff: {exc}")


async def create_staff(
    data: StaffPayloadInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        staff_id = f"stf_{secrets.token_hex(12)}"
        count_row = await _one(db, "SELECT COUNT(*) AS total FROM staff WHERE tenant_id = ?", tenant)
        total = count_row.get("total", 0) + 1
        emp_id = f"EMP{total:03d}"
        now_iso = datetime.now(timezone.utc).isoformat()
        today_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        scaled_salary = int(round(data.basicSalary * 100))
        cat = data.category.strip().upper() if data.category else _detect_category(data.designation, data.department)
        details_json = json.dumps({"qualification": data.qualification, "category": cat})

        await db.prepare(
            "INSERT INTO staff (id, tenant_id, employee_id, full_name, email, phone, "
            "department, designation, date_of_joining, basic_salary, status, details, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
        ).bind(
            staff_id, tenant, emp_id, data.fullName.strip(), data.email.strip().lower(),
            data.phone.strip(), data.department.strip(), data.designation.strip(),
            today_date, scaled_salary, data.status.strip().upper(), details_json, now_iso,
        ).run()

        created = await _one(db, "SELECT * FROM staff WHERE id = ?", staff_id)
        return _wire_staff(created)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to create staff: {type(exc).__name__}: {exc}")


async def update_staff(
    staff_id: str,
    data: StaffPayloadInput,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        existing = await _one(
            db,
            "SELECT * FROM staff WHERE id = ? AND tenant_id = ? AND deleted_at IS NULL",
            staff_id, tenant,
        )
        if not existing:
            raise HTTPException(status_code=404, detail="Staff member not found")

        now_iso = datetime.now(timezone.utc).isoformat()
        scaled_salary = int(round(data.basicSalary * 100))
        cat = data.category.strip().upper() if data.category else _detect_category(data.designation, data.department)
        details_json = json.dumps({"qualification": data.qualification, "category": cat})

        await db.prepare(
            "UPDATE staff SET full_name = ?, email = ?, phone = ?, department = ?, "
            "designation = ?, basic_salary = ?, status = ?, details = ?, updated_at = ? "
            "WHERE id = ? AND tenant_id = ?"
        ).bind(
            data.fullName.strip(), data.email.strip().lower(), data.phone.strip(),
            data.department.strip(), data.designation.strip(), scaled_salary,
            data.status.strip().upper(), details_json, now_iso, staff_id, tenant,
        ).run()

        updated = await _one(db, "SELECT * FROM staff WHERE id = ?", staff_id)
        return _wire_staff(updated)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to update staff: {type(exc).__name__}: {exc}")


async def delete_staff(
    staff_id: str,
    db=Depends(_db),
    user: dict = Depends(require_admin),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    try:
        tenant = await _tenant(db, user, x_tenant_id)
        now_iso = datetime.now(timezone.utc).isoformat()
        await db.prepare(
            "UPDATE staff SET deleted_at = ?, status = 'INACTIVE' WHERE id = ? AND tenant_id = ?"
        ).bind(now_iso, staff_id, tenant).run()
        return Response(status_code=204)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to delete staff: {type(exc).__name__}: {exc}")


# ═════════════════════════════════════════════════════════════════════════════
# ROUTER REGISTRATION (Both /api/users and /users paths)
# ═════════════════════════════════════════════════════════════════════════════

def _register_routes(r: APIRouter):
    r.add_api_route("/users", list_users, methods=["GET"])
    r.add_api_route("/users", create_user, methods=["POST"], status_code=201)
    r.add_api_route("/users/change-password", change_password, methods=["POST"])
    r.add_api_route("/users/{user_id}", get_user_by_id, methods=["GET"])
    r.add_api_route("/users/{user_id}", update_user, methods=["PUT"])
    r.add_api_route("/users/{user_id}", delete_user, methods=["DELETE"])

    r.add_api_route("/staff", list_staff, methods=["GET"])
    r.add_api_route("/staff/dashboard", staff_dashboard, methods=["GET"])
    r.add_api_route("/staff", create_staff, methods=["POST"], status_code=201)
    r.add_api_route("/staff/{staff_id}", get_staff_by_id, methods=["GET"])
    r.add_api_route("/staff/{staff_id}", update_staff, methods=["PUT"])
    r.add_api_route("/staff/{staff_id}", delete_staff, methods=["DELETE"], status_code=204)


router = APIRouter(prefix="/api", tags=["users"])
root_router = APIRouter(tags=["users_root"])
_register_routes(router)
_register_routes(root_router)
