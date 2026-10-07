import json
from pathlib import Path
import sqlite3
import sys
from fastapi import FastAPI
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from school_auth import _db, get_current_user, require_admin
from school_notifications import router, root_router


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
        CREATE TABLE notifications (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            title TEXT,
            message TEXT,
            type TEXT,
            target_audience TEXT,
            target_class TEXT,
            target_student_id TEXT,
            priority TEXT,
            created_by TEXT,
            creator_id TEXT,
            created_at TEXT,
            expires_at TEXT,
            deleted_at TEXT
        );
        CREATE TABLE notification_reads (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            notification_id TEXT,
            user_id TEXT,
            read_at TEXT,
            UNIQUE (notification_id, user_id)
        );
        INSERT INTO tenants VALUES ('school-a', 'School A', 1);
    """)

    app = FastAPI()
    app.include_router(router)
    app.include_router(root_router)
    app.dependency_overrides[_db] = lambda: D1(db)
    app.dependency_overrides[get_current_user] = lambda: {
        "id": "usr-01",
        "email": "admin@school.com",
        "fullName": "Admin User",
        "role": "SCHOOL_ADMIN",
        "tenantId": "school-a",
        "permissions": ["*"],
    }
    app.dependency_overrides[require_admin] = lambda: {
        "id": "usr-01",
        "email": "admin@school.com",
        "fullName": "Admin User",
        "role": "SCHOOL_ADMIN",
        "tenantId": "school-a",
        "permissions": ["*"],
    }
    return TestClient(app)


def test_notifications_crud():
    client = _client()

    # Create notification
    res = client.post(
        "/api/notifications",
        headers={"X-Tenant-ID": "school-a"},
        json={
            "title": "Annual Sports Day",
            "message": "Annual Sports meet scheduled for Saturday.",
            "type": "EVENT",
            "priority": "HIGH",
        },
    )
    assert res.status_code == 201
    notif = res.json()
    assert notif["title"] == "Annual Sports Day"
    assert notif["read"] is False

    # List notifications
    list_res = client.get("/api/notifications", headers={"X-Tenant-ID": "school-a"})
    assert list_res.status_code == 200
    assert len(list_res.json()) == 1

    # Mark as read
    read_res = client.put(f"/api/notifications/{notif['id']}/read", headers={"X-Tenant-ID": "school-a"})
    assert read_res.status_code == 200
    assert read_res.json()["read"] is True

    # Delete
    del_res = client.delete(f"/api/notifications/{notif['id']}", headers={"X-Tenant-ID": "school-a"})
    assert del_res.status_code == 200

    # List again -> 0
    list_res2 = client.get("/api/notifications", headers={"X-Tenant-ID": "school-a"})
    assert len(list_res2.json()) == 0
