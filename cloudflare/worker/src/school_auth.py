"""D1-backed school authentication using the existing Flutter wire contract."""

from __future__ import annotations

import base64
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import json
import secrets

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field


ACCESS_SECONDS = 3600
REFRESH_DAYS = 30
ROLE_PERMISSIONS = {
    "SUPER_ADMIN": ["*"],
    "SCHOOL_ADMIN": [
        "students:read", "students:write", "attendance:read", "attendance:write",
        "fees:read", "fees:write", "results:read", "results:write",
        "transport:read", "transport:write", "expenses:read", "expenses:write",
        "notifications:read", "notifications:write", "timetable:read", "timetable:write",
        "reports:read", "users:read", "users:write", "staff:read", "staff:write",
        "payroll:read", "payroll:write", "homework:read", "homework:write",
        "discipline:read", "discipline:write", "certificates:read", "certificates:write",
        "videos:read", "videos:write",
    ],
    "TEACHER": ["students:read", "attendance:read", "attendance:write", "results:read", "results:write", "timetable:read", "timetable:write", "notifications:read", "notifications:write", "homework:read", "homework:write", "discipline:read", "discipline:write", "videos:read", "videos:write"],
    "ACCOUNTANT": ["students:read", "fees:read", "fees:write", "expenses:read", "expenses:write", "reports:read", "payroll:read", "payroll:write"],
    "TRANSPORT_MANAGER": ["students:read", "transport:read", "transport:write"],
    "STUDENT": ["attendance:read:own", "fees:read:own", "results:read:own", "timetable:read"],
    "PARENT": ["attendance:read:child", "fees:read:child", "results:read:child", "timetable:read"],
}

router = APIRouter(tags=["auth"])


class LoginInput(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=1)


class RefreshInput(BaseModel):
    refresh_token: str = Field(alias="refreshToken", min_length=1)


def _py(value):
    if value is None:
        return None
    if hasattr(value, "to_py"):
        value = value.to_py()
    return dict(value) if not isinstance(value, dict) else value


async def _db(request: Request):
    env = request.scope.get("env")
    if isinstance(env, dict) and "DB" in env:
        return env["DB"]
    if env is not None and hasattr(env, "DB"):
        return env.DB
    raise HTTPException(status_code=500, detail="D1 database binding unavailable")


def password_hash(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(password.encode(), salt=salt, n=16384, r=8, p=1)
    return "$scrypt$16384$8$1$" + base64.urlsafe_b64encode(salt).decode() + "$" + base64.urlsafe_b64encode(digest).decode()


def _verify_password(password: str, stored: str) -> bool:
    try:
        _, algorithm, n, r, p, salt, expected = stored.split("$")
        if (algorithm, n, r, p) != ("scrypt", "16384", "8", "1"):
            return False
        digest = hashlib.scrypt(
            password.encode(), salt=base64.urlsafe_b64decode(salt), n=16384, r=8, p=1
        )
        return hmac.compare_digest(digest, base64.urlsafe_b64decode(expected))
    except (ValueError, TypeError, OverflowError):
        return False


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _wire(user: dict) -> dict:
    try:
        extra = json.loads(user.get("extra_permissions") or "[]")
    except (TypeError, ValueError):
        extra = []
    if not isinstance(extra, list):
        extra = []
    permissions = sorted(set(ROLE_PERMISSIONS.get(user["role"], []) + extra))
    return {
        "userId": user["id"], "id": user["id"], "email": user["email"],
        "fullName": user["full_name"], "phone": user["phone"],
        "role": user["role"], "tenantId": user["tenant_id"],
        "linkedEntityId": user["linked_entity_id"],
        "permissions": permissions, "extraPermissions": extra,
        "active": bool(user["active"]), "createdAt": user["created_at"],
        "lastLoginAt": user.get("last_login_at"),
    }


def _new_tokens() -> tuple[str, str, str, str]:
    access = secrets.token_urlsafe(48)
    refresh = secrets.token_urlsafe(48)
    return access, refresh, _token_hash(access), _token_hash(refresh)


async def _school(db, school_id: str):
    return _py(await db.prepare(
        "SELECT id, name, city, board, active FROM tenants WHERE id = ?"
    ).bind(school_id).first())


@router.get("/platform/schools/{tenant_id}/validate")
async def validate_school(tenant_id: str, db=Depends(_db)):
    school = await _school(db, tenant_id.strip().lower())
    if not school or not school["active"]:
        return {"valid": False}
    return {"valid": True, "name": school["name"], "city": school["city"], "board": school["board"]}


async def _login(data: LoginInput, scope: str, db):
    if scope != "platform":
        school = await _school(db, scope)
        if not school or not school["active"]:
            raise HTTPException(status_code=403, detail="School is inactive")
    user = _py(await db.prepare(
        "SELECT * FROM users WHERE scope = ? AND email = ?"
    ).bind(scope, data.email.strip().lower()).first())
    if (not user or not user["active"] or
            (scope == "platform" and (user["tenant_id"] is not None or user["role"] != "SUPER_ADMIN")) or
            (scope != "platform" and user["tenant_id"] != scope) or
            not _verify_password(data.password, user["password_hash"])):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    now = _utc_now()
    access, refresh, access_hash, refresh_hash = _new_tokens()
    await db.batch([
        db.prepare("UPDATE users SET last_login_at = ? WHERE id = ? AND active = 1").bind(now.isoformat(), user["id"]),
        db.prepare(
            "INSERT INTO auth_sessions (id, user_id, access_hash, refresh_hash, access_expires_at, refresh_expires_at) "
            "VALUES (?, ?, ?, ?, ?, ?)"
        ).bind(secrets.token_hex(16), user["id"], access_hash, refresh_hash,
               (now + timedelta(seconds=ACCESS_SECONDS)).isoformat(),
               (now + timedelta(days=REFRESH_DAYS)).isoformat()),
    ])
    user["last_login_at"] = now.isoformat()
    return {"token": access, "refreshToken": refresh, **_wire(user), "expiresIn": ACCESS_SECONDS}


@router.post("/api/auth/login")
async def login_school(
    data: LoginInput, db=Depends(_db),
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
):
    if not x_tenant_id or not x_tenant_id.strip():
        raise HTTPException(status_code=400, detail="X-Tenant-ID is required")
    return await _login(data, x_tenant_id.strip().lower(), db)


@router.post("/platform/auth/login")
async def login_platform(data: LoginInput, db=Depends(_db)):
    return await _login(data, "platform", db)


async def _session_user(db, token_hash: str, *, refresh: bool):
    column = "refresh_hash" if refresh else "access_hash"
    return _py(await db.prepare(
        "SELECT u.*, s.revoked_at AS session_revoked_at, s.access_expires_at, "
        "s.refresh_expires_at, t.active AS tenant_active FROM auth_sessions s "
        "JOIN users u ON u.id = s.user_id LEFT JOIN tenants t ON t.id = u.tenant_id "
        f"WHERE s.{column} = ?"
    ).bind(token_hash).first())


def _active(user: dict | None, *, refresh: bool) -> bool:
    if not user or user["session_revoked_at"] is not None or not user["active"]:
        return False
    if user["tenant_id"] is not None and not user["tenant_active"]:
        return False
    expiry = user["refresh_expires_at"] if refresh else user["access_expires_at"]
    return datetime.fromisoformat(expiry) > _utc_now()


@router.post("/api/auth/refresh")
async def refresh(data: RefreshInput, db=Depends(_db)):
    predecessor_hash = _token_hash(data.refresh_token)
    user = await _session_user(db, predecessor_hash, refresh=True)
    if not _active(user, refresh=True):
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")
    now = _utc_now()
    access, successor, access_hash, successor_hash = _new_tokens()
    result = await db.batch([
        db.prepare(
            "INSERT INTO auth_sessions (id, user_id, access_hash, refresh_hash, access_expires_at, refresh_expires_at) "
            "SELECT ?, s.user_id, ?, ?, ?, ? FROM auth_sessions s "
            "JOIN users u ON u.id = s.user_id LEFT JOIN tenants t ON t.id = u.tenant_id "
            "WHERE s.refresh_hash = ? AND s.revoked_at IS NULL AND s.refresh_expires_at > ? "
            "AND u.active = 1 AND (u.tenant_id IS NULL OR t.active = 1)"
        ).bind(secrets.token_hex(16), access_hash, successor_hash,
               (now + timedelta(seconds=ACCESS_SECONDS)).isoformat(),
               (now + timedelta(days=REFRESH_DAYS)).isoformat(), predecessor_hash, now.isoformat()),
        db.prepare(
            "UPDATE auth_sessions SET revoked_at = ? WHERE refresh_hash = ? AND revoked_at IS NULL "
            "AND refresh_expires_at > ?"
        ).bind(now.isoformat(), predecessor_hash, now.isoformat()),
    ])
    results = result.to_py() if hasattr(result, "to_py") else result
    first = _py(results[0]) if results else {}
    meta = _py(first.get("meta")) if first else {}
    if meta.get("changes") != 1:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")
    return {"token": access, "refreshToken": successor, **_wire(user), "expiresIn": ACCESS_SECONDS}


@router.post("/api/auth/logout")
async def logout(
    db=Depends(_db),
    authorization: str | None = Header(default=None, alias="Authorization"),
):
    token = authorization[7:] if authorization and authorization.startswith("Bearer ") else ""
    token_hash = _token_hash(token)
    user = await _session_user(db, token_hash, refresh=False)
    if not _active(user, refresh=False):
        raise HTTPException(status_code=401, detail="Invalid token")
    result = _py(await db.prepare(
        "UPDATE auth_sessions SET revoked_at = ? WHERE access_hash = ? AND revoked_at IS NULL"
    ).bind(_utc_now().isoformat(), token_hash).run())
    meta = _py(result.get("meta")) if result else {}
    if meta.get("changes") != 1:
        raise HTTPException(status_code=401, detail="Invalid token")
    return {"message": "Logged out successfully"}
