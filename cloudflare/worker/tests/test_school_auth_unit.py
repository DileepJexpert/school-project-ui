"""Unit and isolation tests for D1 school authentication, bootstrap, and tenant isolation."""

from __future__ import annotations

import base64
from datetime import datetime, timezone
import hashlib
from pathlib import Path
import sqlite3
import sys

import bcrypt
import pytest
from starlette.testclient import TestClient
from fastapi import FastAPI

WORKER = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(WORKER))
sys.path.insert(0, str(WORKER / "src"))

from bootstrap_school import generate_bootstrap_sql  # noqa: E402
from school_auth import router, _db, password_hash, _wire, ROLE_PERMISSIONS, require_admin  # noqa: E402


class SQLiteD1Statement:
    def __init__(self, db: sqlite3.Connection, sql: str, bindings: tuple = ()):
        self.db = db
        self.sql = sql
        self.bindings = bindings

    def bind(self, *args) -> SQLiteD1Statement:
        return SQLiteD1Statement(self.db, self.sql, args)

    async def first(self) -> dict | None:
        cur = self.db.cursor()
        cur.execute(self.sql, self.bindings)
        row = cur.fetchone()
        if not row:
            return None
        cols = [c[0] for c in cur.description]
        return dict(zip(cols, row))

    async def all(self) -> list[dict]:
        cur = self.db.cursor()
        cur.execute(self.sql, self.bindings)
        rows = cur.fetchall()
        cols = [c[0] for c in cur.description]
        return [dict(zip(cols, r)) for r in rows]

    async def run(self) -> dict:
        cur = self.db.cursor()
        cur.execute(self.sql, self.bindings)
        self.db.commit()
        return {"meta": {"changes": cur.rowcount}}


class SQLiteD1:
    def __init__(self, db: sqlite3.Connection):
        self.db = db

    def prepare(self, sql: str) -> SQLiteD1Statement:
        return SQLiteD1Statement(self.db, sql)

    async def batch(self, stmts: list[SQLiteD1Statement]) -> list[dict]:
        results = []
        cur = self.db.cursor()
        try:
            self.db.execute("BEGIN")
            for s in stmts:
                cur.execute(s.sql, s.bindings)
                results.append({"meta": {"changes": cur.rowcount}})
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise
        return results


def migration_text(name: str) -> str:
    return (WORKER / "migrations" / name).read_text(encoding="utf-8")


@pytest.fixture
def test_db():
    conn = sqlite3.connect(":memory:", check_same_thread=False)
    conn.execute("PRAGMA foreign_keys = ON")
    conn.executescript(migration_text("0001_initial.sql"))
    conn.executescript(migration_text("0002_school_schema.sql"))
    return conn


@pytest.fixture
def client(test_db):
    app = FastAPI()
    app.include_router(router)
    d1 = SQLiteD1(test_db)
    app.dependency_overrides[_db] = lambda: d1
    return TestClient(app)


def seed_test_ecosystem(test_db: sqlite3.Connection):
    """Seed Tenant A, Tenant B, an inactive school, and users without exposing public endpoints."""
    # 1. Tenant A (Alpha Academy)
    sql_a = generate_bootstrap_sql(
        school_id="school-a",
        school_name="Alpha Academy",
        admin_email="admin@alpha.edu",
        admin_password="Password123!",
        admin_name="Alpha Admin",
        active=True,
    )
    test_db.executescript(sql_a)

    # 2. Tenant B (Beta High)
    sql_b = generate_bootstrap_sql(
        school_id="school-b",
        school_name="Beta High School",
        admin_email="admin@beta.edu",
        admin_password="Password123!",
        admin_name="Beta Admin",
        active=True,
    )
    test_db.executescript(sql_b)

    # 3. Inactive Tenant
    sql_inact = generate_bootstrap_sql(
        school_id="school-inactive",
        school_name="Inactive School",
        admin_email="admin@inactive.edu",
        admin_password="Password123!",
        active=False,
    )
    test_db.executescript(sql_inact)

    # 4. Disabled User in Tenant A
    disabled_hash = password_hash("Password123!")
    now_iso = datetime.now(timezone.utc).isoformat()
    test_db.execute(
        "INSERT INTO users (id, tenant_id, email, password_hash, full_name, phone, role, scope, extra_permissions, active, created_at) "
        "VALUES ('usr-disabled-a', 'school-a', 'disabled@alpha.edu', ?, 'Disabled Staff', '+919999999999', "
        "'TEACHER', 'school-a', '[]', 0, ?)",
        (disabled_hash, now_iso),
    )

    # 5. Platform Super Admin (scope = 'platform', tenant_id = NULL)
    super_hash = password_hash("SuperAdmin123!")
    test_db.execute(
        "INSERT INTO users (id, tenant_id, email, password_hash, full_name, phone, role, scope, extra_permissions, active, created_at) "
        "VALUES ('usr-platform-super', NULL, 'super@platform.local', ?, 'Super Administrator', '+910000000000', "
        "'SUPER_ADMIN', 'platform', '[]', 1, ?)",
        (super_hash, now_iso),
    )
    test_db.commit()


def test_private_bootstrap_utility(test_db):
    seed_test_ecosystem(test_db)
    schools = {row[0] for row in test_db.execute("SELECT id FROM tenants").fetchall()}
    assert {"school-a", "school-b", "school-inactive"}.issubset(schools)
    users = {row[0] for row in test_db.execute("SELECT email FROM users").fetchall()}
    assert "admin@alpha.edu" in users
    assert "admin@beta.edu" in users
    assert "super@platform.local" in users


def test_positive_school_login_and_me_profile(test_db, client):
    seed_test_ecosystem(test_db)

    # 1. Login to School A
    resp = client.post(
        "/api/auth/login",
        headers={"X-Tenant-ID": "school-a"},
        json={"email": "admin@alpha.edu", "password": "Password123!"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "token" in data and len(data["token"]) >= 32
    assert "refreshToken" in data and len(data["refreshToken"]) >= 32
    assert data["role"] == "SCHOOL_ADMIN"
    assert data["tenantId"] == "school-a"
    assert "students:read" in data["permissions"]
    assert "fees:write" in data["permissions"]
    assert data["expiresIn"] == 3600

    token = data["token"]

    # 2. Access /api/auth/me with Bearer token and X-Tenant-ID
    me_resp = client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {token}", "X-Tenant-ID": "school-a"},
    )
    assert me_resp.status_code == 200
    me_data = me_resp.json()
    assert me_data["email"] == "admin@alpha.edu"
    assert me_data["tenantId"] == "school-a"
    assert me_data["role"] == "SCHOOL_ADMIN"


def test_negative_authentication_and_inactive_school(test_db, client):
    seed_test_ecosystem(test_db)

    # Missing X-Tenant-ID
    r_no_tenant = client.post(
        "/api/auth/login",
        json={"email": "admin@alpha.edu", "password": "Password123!"},
    )
    assert r_no_tenant.status_code == 400
    assert "X-Tenant-ID is required" in r_no_tenant.json()["detail"]

    # Wrong password
    r_bad_pw = client.post(
        "/api/auth/login",
        headers={"X-Tenant-ID": "school-a"},
        json={"email": "admin@alpha.edu", "password": "WrongPassword!"},
    )
    assert r_bad_pw.status_code == 401
    assert "Invalid credentials" in r_bad_pw.json()["detail"]

    # Unknown user
    r_unknown = client.post(
        "/api/auth/login",
        headers={"X-Tenant-ID": "school-a"},
        json={"email": "nobody@alpha.edu", "password": "Password123!"},
    )
    assert r_unknown.status_code == 401

    # Inactive school
    r_inactive_school = client.post(
        "/api/auth/login",
        headers={"X-Tenant-ID": "school-inactive"},
        json={"email": "admin@inactive.edu", "password": "Password123!"},
    )
    assert r_inactive_school.status_code == 403
    assert "School is inactive" in r_inactive_school.json()["detail"]

    # Disabled user
    r_disabled_user = client.post(
        "/api/auth/login",
        headers={"X-Tenant-ID": "school-a"},
        json={"email": "disabled@alpha.edu", "password": "Password123!"},
    )
    assert r_disabled_user.status_code == 401
    assert "Invalid credentials" in r_disabled_user.json()["detail"]


def test_tenant_ab_strict_isolation(test_db, client):
    seed_test_ecosystem(test_db)

    # 1. Admin A cannot log into School B with their credentials
    r_cross_login = client.post(
        "/api/auth/login",
        headers={"X-Tenant-ID": "school-b"},
        json={"email": "admin@alpha.edu", "password": "Password123!"},
    )
    assert r_cross_login.status_code == 401
    assert "Invalid credentials" in r_cross_login.json()["detail"]

    # 2. Admin A logs into School A legitimately
    r_legit = client.post(
        "/api/auth/login",
        headers={"X-Tenant-ID": "school-a"},
        json={"email": "admin@alpha.edu", "password": "Password123!"},
    )
    assert r_legit.status_code == 200
    token_a = r_legit.json()["token"]

    # 3. Admin A attempts to use Token A against School B
    r_cross_access = client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {token_a}", "X-Tenant-ID": "school-b"},
    )
    assert r_cross_access.status_code == 403
    assert "Tenant does not match token" in r_cross_access.json()["detail"]


def test_token_refresh_rotation_and_revocation(test_db, client):
    seed_test_ecosystem(test_db)

    # Initial login
    r_login = client.post(
        "/api/auth/login",
        headers={"X-Tenant-ID": "school-a"},
        json={"email": "admin@alpha.edu", "password": "Password123!"},
    )
    assert r_login.status_code == 200
    r1 = r_login.json()["refreshToken"]

    # Successful refresh
    r_refresh = client.post("/api/auth/refresh", json={"refreshToken": r1})
    assert r_refresh.status_code == 200
    r2 = r_refresh.json()["refreshToken"]
    new_token = r_refresh.json()["token"]
    assert r2 != r1

    # Verify predecessor token r1 is now revoked
    r_replay = client.post("/api/auth/refresh", json={"refreshToken": r1})
    assert r_replay.status_code == 401

    # Successor token r2 can access endpoints
    me_resp = client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {new_token}", "X-Tenant-ID": "school-a"},
    )
    assert me_resp.status_code == 200


def test_logout_session_invalidation(test_db, client):
    seed_test_ecosystem(test_db)

    # Login
    r_login = client.post(
        "/api/auth/login",
        headers={"X-Tenant-ID": "school-a"},
        json={"email": "admin@alpha.edu", "password": "Password123!"},
    )
    token = r_login.json()["token"]

    # Logout
    r_logout = client.post(
        "/api/auth/logout",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r_logout.status_code == 200
    assert r_logout.json()["message"] == "Logged out successfully"

    # Subsequent access with same token is rejected
    r_me = client.get(
        "/api/auth/me",
        headers={"Authorization": f"Bearer {token}", "X-Tenant-ID": "school-a"},
    )
    assert r_me.status_code == 401


def test_legacy_bcrypt_compatibility_and_auto_rehash(test_db, client):
    seed_test_ecosystem(test_db)

    # Generate genuine bcrypt hash for legacy user
    legacy_pw = "LegacySecret999!"
    legacy_salt = bcrypt.gensalt(rounds=10)
    legacy_hash = bcrypt.hashpw(legacy_pw.encode(), legacy_salt).decode()
    assert legacy_hash.startswith("$2b$")

    now_iso = datetime.now(timezone.utc).isoformat()
    test_db.execute(
        "INSERT INTO users (id, tenant_id, email, password_hash, full_name, phone, role, scope, extra_permissions, active, created_at) "
        "VALUES ('usr-legacy-a', 'school-a', 'legacy@alpha.edu', ?, 'Legacy Teacher', '+918888888888', "
        "'TEACHER', 'school-a', '[]', 1, ?)",
        (legacy_hash, now_iso),
    )
    test_db.commit()

    # Login with legacy bcrypt password
    r_login = client.post(
        "/api/auth/login",
        headers={"X-Tenant-ID": "school-a"},
        json={"email": "legacy@alpha.edu", "password": legacy_pw},
    )
    assert r_login.status_code == 200
    assert r_login.json()["role"] == "TEACHER"

    # Verify that the password_hash in D1 was automatically updated to modern $scrypt$
    updated_hash = test_db.execute(
        "SELECT password_hash FROM users WHERE id = 'usr-legacy-a'"
    ).fetchone()[0]
    assert updated_hash.startswith("$scrypt$16384$8$1$")

    # Verify that subsequent logins succeed using the newly upgraded scrypt hash
    r_login_again = client.post(
        "/api/auth/login",
        headers={"X-Tenant-ID": "school-a"},
        json={"email": "legacy@alpha.edu", "password": legacy_pw},
    )
    assert r_login_again.status_code == 200


def test_platform_super_admin_login(test_db, client):
    seed_test_ecosystem(test_db)

    # Platform login
    r_plat = client.post(
        "/platform/auth/login",
        json={"email": "super@platform.local", "password": "SuperAdmin123!"},
    )
    assert r_plat.status_code == 200
    data = r_plat.json()
    assert data["role"] == "SUPER_ADMIN"
    assert data["tenantId"] is None
    assert "*" in data["permissions"]

    # Platform login rejects school users
    r_school_user = client.post(
        "/platform/auth/login",
        json={"email": "admin@alpha.edu", "password": "Password123!"},
    )
    assert r_school_user.status_code == 401
