import json
from pathlib import Path
import sqlite3
import sys
from fastapi import FastAPI
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from school_auth import _db, get_current_user, require_admin
from school_discipline import router, root_router


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
        CREATE TABLE students (id TEXT PRIMARY KEY, tenant_id TEXT, full_name TEXT, class_name TEXT, academic_year TEXT, admission_number TEXT);
        CREATE TABLE incidents (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            student_id TEXT,
            student_name TEXT,
            class_name TEXT,
            academic_year TEXT,
            severity TEXT,
            category TEXT,
            description TEXT,
            action_taken TEXT,
            reported_by TEXT,
            incident_date TEXT,
            parent_notified INTEGER,
            parent_notified_at TEXT,
            follow_up_notes TEXT,
            resolved INTEGER,
            resolved_at TEXT,
            created_at TEXT
        );
        INSERT INTO tenants VALUES ('school-a', 'School A', 1);
        INSERT INTO students VALUES ('stu-001', 'school-a', 'Rohan', 'Class 10-A', '2026-2027', 'ADM-01');
    """)

    app = FastAPI()
    app.include_router(router)
    app.include_router(root_router)
    app.dependency_overrides[_db] = lambda: D1(db)
    app.dependency_overrides[get_current_user] = lambda: {
        "id": "admin-1",
        "email": "admin@school.com",
        "fullName": "Admin User",
        "role": "SCHOOL_ADMIN",
        "tenantId": "school-a",
        "permissions": ["*"],
    }
    app.dependency_overrides[require_admin] = lambda: {
        "id": "admin-1",
        "email": "admin@school.com",
        "fullName": "Admin User",
        "role": "SCHOOL_ADMIN",
        "tenantId": "school-a",
        "permissions": ["*"],
    }
    return TestClient(app)


def test_discipline_flow():
    client = _client()

    # Empty initially
    res = client.get("/api/discipline", headers={"X-Tenant-ID": "school-a"})
    assert res.status_code == 200
    assert res.json() == []

    # Summary empty
    sum_res = client.get("/api/discipline/summary", headers={"X-Tenant-ID": "school-a"})
    assert sum_res.status_code == 200
    assert sum_res.json()["total"] == 0

    # Create incident
    create_res = client.post(
        "/api/discipline",
        headers={"X-Tenant-ID": "school-a"},
        json={
            "studentId": "stu-001",
            "severity": "MAJOR",
            "category": "BEHAVIORAL",
            "description": "Disrupted classroom lecture",
            "actionTaken": "Verbal reprimand and written notice",
        },
    )
    assert create_res.status_code == 201
    inc = create_res.json()
    assert inc["studentName"] == "Rohan"
    assert inc["severity"] == "MAJOR"
    assert inc["resolved"] is False

    # Summary updated
    sum_res2 = client.get("/api/discipline/summary", headers={"X-Tenant-ID": "school-a"})
    assert sum_res2.json()["total"] == 1
    assert sum_res2.json()["bySeverity"]["MAJOR"] == 1
    assert sum_res2.json()["open"] == 1

    # Resolve incident
    resolve_res = client.put(
        f"/api/discipline/{inc['id']}/resolve",
        headers={"X-Tenant-ID": "school-a"},
        json={"resolution": "Parent counseling completed"},
    )
    assert resolve_res.status_code == 200
    assert resolve_res.json()["resolved"] is True
    assert resolve_res.json()["resolution"] == "Parent counseling completed"
