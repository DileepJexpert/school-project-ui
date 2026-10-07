import json
import sqlite3
from datetime import datetime, timezone
from fastapi import FastAPI
from fastapi.testclient import TestClient

from school_auth import _db, get_current_user, require_admin
from school_users import router, root_router


class Statement:
    def __init__(self, db: sqlite3.Connection, sql: str, bindings=None):
        self.db = db
        self.sql = sql
        self.bindings = bindings or []

    def bind(self, *bindings):
        return Statement(self.db, self.sql, list(bindings))

    async def first(self):
        cur = self.db.execute(self.sql, self.bindings)
        row = cur.fetchone()
        return dict(row) if row else None

    async def all(self):
        cur = self.db.execute(self.sql, self.bindings)
        rows = cur.fetchall()
        return [dict(r) for r in rows]

    async def run(self):
        cur = self.db.execute(self.sql, self.bindings)
        self.db.commit()
        return {"meta": {"changes": cur.rowcount}}


class D1:
    def __init__(self, db: sqlite3.Connection):
        self.db = db

    def prepare(self, sql: str):
        return Statement(self.db, sql)


def _client():
    db = sqlite3.connect(":memory:", check_same_thread=False)
    db.row_factory = sqlite3.Row
    db.executescript("""
        CREATE TABLE tenants (id TEXT PRIMARY KEY, name TEXT, active INTEGER);
        CREATE TABLE users (
            id TEXT PRIMARY KEY,
            scope TEXT,
            tenant_id TEXT,
            email TEXT,
            password_hash TEXT,
            full_name TEXT,
            phone TEXT,
            role TEXT,
            linked_entity_id TEXT,
            extra_permissions TEXT,
            active INTEGER,
            created_at TEXT,
            last_login_at TEXT
        );
        CREATE TABLE auth_sessions (
            id TEXT PRIMARY KEY,
            user_id TEXT,
            access_hash TEXT,
            refresh_hash TEXT,
            access_expires_at TEXT,
            refresh_expires_at TEXT,
            revoked_at TEXT
        );
        CREATE TABLE staff (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            employee_id TEXT,
            full_name TEXT,
            email TEXT,
            phone TEXT,
            department TEXT,
            designation TEXT,
            date_of_joining TEXT,
            date_of_leaving TEXT,
            basic_salary INTEGER,
            status TEXT,
            details TEXT,
            created_at TEXT,
            updated_at TEXT,
            deleted_at TEXT
        );
        INSERT INTO tenants VALUES ('school-a', 'School A', 1);
        INSERT INTO users VALUES (
            'usr-admin-1', 'school-a', 'school-a', 'admin@school.a',
            '$scrypt$16384$8$1$dummy$hash', 'Admin A', '1234567890',
            'SCHOOL_ADMIN', NULL, '[]', 1, '2026-10-01T00:00:00Z', NULL
        );
    """)

    admin_ctx = {
        "id": "usr-admin-1",
        "userId": "usr-admin-1",
        "email": "admin@school.a",
        "role": "SCHOOL_ADMIN",
        "tenantId": "school-a",
        "active": True,
    }

    app = FastAPI()
    app.include_router(router)
    app.include_router(root_router)
    app.dependency_overrides[_db] = lambda: D1(db)
    app.dependency_overrides[get_current_user] = lambda: admin_ctx
    app.dependency_overrides[require_admin] = lambda: admin_ctx
    return TestClient(app)


def test_list_users():
    client = _client()
    res = client.get("/api/users", headers={"X-Tenant-ID": "school-a"})
    assert res.status_code == 200
    data = res.json()
    assert len(data) == 1
    assert data[0]["fullName"] == "Admin A"
    assert data[0]["role"] == "SCHOOL_ADMIN"

    # Also test /users root path
    res_root = client.get("/users", headers={"X-Tenant-ID": "school-a"})
    assert res_root.status_code == 200
    assert len(res_root.json()) == 1


def test_create_user_and_update():
    client = _client()
    payload = {
        "fullName": "Pooja Sharma",
        "email": "pooja.teacher@school.a",
        "phone": "9876543210",
        "role": "TEACHER",
        "password": "Password123",
        "extraPermissions": []
    }
    res = client.post("/api/users", json=payload, headers={"X-Tenant-ID": "school-a"})
    assert res.status_code == 201, res.text
    created = res.json()
    assert created["fullName"] == "Pooja Sharma"
    assert created["role"] == "TEACHER"
    user_id = created["id"]

    # Update user
    update_payload = {
        "fullName": "Pooja Sharma Updated",
        "email": "pooja.teacher@school.a",
        "phone": "9876543211",
        "role": "TEACHER",
        "extraPermissions": []
    }
    res_update = client.put(f"/api/users/{user_id}", json=update_payload, headers={"X-Tenant-ID": "school-a"})
    assert res_update.status_code == 200
    assert res_update.json()["fullName"] == "Pooja Sharma Updated"

    # Delete (deactivate) user
    res_del = client.delete(f"/api/users/{user_id}", headers={"X-Tenant-ID": "school-a"})
    assert res_del.status_code == 200
