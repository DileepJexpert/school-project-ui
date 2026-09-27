"""Tenant-bound opaque sessions and legacy BCrypt-aware password verification."""

import base64
import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

import bcrypt
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import AuthSession, Tenant, User

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


def password_hash(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(password.encode(), salt=salt, n=2**14, r=8, p=1)
    return "$scrypt$16384$8$1$" + base64.urlsafe_b64encode(salt).decode() + "$" + base64.urlsafe_b64encode(digest).decode()


def verify_password(password: str, stored: str) -> bool:
    try:
        if stored.startswith(("$2a$", "$2b$", "$2y$")):
            return bcrypt.checkpw(password.encode(), stored.encode())
        _, algorithm, n, r, p, salt, expected = stored.split("$")
        if algorithm != "scrypt":
            return False
        actual = hashlib.scrypt(password.encode(), salt=base64.urlsafe_b64decode(salt), n=int(n), r=int(r), p=int(p))
        return hmac.compare_digest(actual, base64.urlsafe_b64decode(expected))
    except (ValueError, TypeError, OverflowError):
        return False


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def permissions(user: User) -> list[str]:
    return sorted(set(ROLE_PERMISSIONS.get(user.role, []) + (user.extra_permissions or [])))


def user_wire(user: User) -> dict:
    return {
        "userId": user.id,
        "id": user.id,
        "email": user.email,
        "fullName": user.full_name,
        "phone": user.phone,
        "role": user.role,
        "tenantId": user.tenant_id,
        "linkedEntityId": user.linked_entity_id,
        "permissions": permissions(user),
        "extraPermissions": user.extra_permissions or [],
        "active": user.active,
        "createdAt": aware(user.created_at).isoformat(),
        "lastLoginAt": aware(user.last_login_at).isoformat() if user.last_login_at else None,
    }


def issue_tokens(session: Session, user: User) -> dict:
    now = datetime.now(timezone.utc)
    access = secrets.token_urlsafe(48)
    refresh = secrets.token_urlsafe(48)
    session.add(AuthSession(
        user_id=user.id,
        access_hash=token_hash(access),
        refresh_hash=token_hash(refresh),
        access_expires_at=now + timedelta(seconds=ACCESS_SECONDS),
        refresh_expires_at=now + timedelta(days=REFRESH_DAYS),
    ))
    return {"token": access, "refreshToken": refresh, **user_wire(user), "expiresIn": ACCESS_SECONDS}


def aware(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def active_session(session: Session, token: str, *, refresh: bool = False) -> AuthSession | None:
    column = AuthSession.refresh_hash if refresh else AuthSession.access_hash
    record = session.scalar(select(AuthSession).where(column == token_hash(token)))
    if record is None or record.revoked_at is not None:
        return None
    expiry = record.refresh_expires_at if refresh else record.access_expires_at
    if aware(expiry) <= datetime.now(timezone.utc) or not record.user.active:
        return None
    if record.user.tenant_id:
        tenant = session.get(Tenant, record.user.tenant_id)
        if tenant is None or not tenant.active:
            return None
    return record


def authenticate(session: Session, email: str, password: str, scope: str) -> dict:
    user = session.scalar(select(User).where(User.scope == scope, User.email == email.strip().lower()))
    if user is None or not user.active or not verify_password(password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if scope != "platform":
        tenant = session.get(Tenant, scope)
        if tenant is None or not tenant.active:
            raise HTTPException(status_code=403, detail="School is inactive")
    user.last_login_at = datetime.now(timezone.utc)
    if user.password_hash.startswith(("$2a$", "$2b$", "$2y$")):
        user.password_hash = password_hash(password)
    return issue_tokens(session, user)
