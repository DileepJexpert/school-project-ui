from pathlib import Path
import sqlite3
import sys
from fastapi import FastAPI
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from school_auth import _db, get_current_user, require_admin
from school_timetable import router, root_router


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
        CREATE TABLE timetable_days (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            class_name TEXT,
            academic_year TEXT,
            day_of_week TEXT
        );
        CREATE TABLE timetable_periods (
            id TEXT PRIMARY KEY,
            day_id TEXT,
            period_number INTEGER,
            subject TEXT,
            teacher_name TEXT,
            start_time TEXT,
            end_time TEXT
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


def test_timetable_flow():
    client = _client()

    # Save timetable day
    save_res = client.post(
        "/api/timetable",
        headers={"X-Tenant-ID": "school-a"},
        json={
            "className": "Class 10-A",
            "academicYear": "2026-2027",
            "dayOfWeek": "Monday",
            "periods": [
                {
                    "periodNumber": 1,
                    "subject": "Mathematics",
                    "teacherName": "Anita Sharma",
                    "startTime": "08:30",
                    "endTime": "09:15",
                },
                {
                    "periodNumber": 2,
                    "subject": "Physics",
                    "teacherName": "Ramesh Verma",
                    "startTime": "09:15",
                    "endTime": "10:00",
                },
            ],
        },
    )
    assert save_res.status_code == 200
    data = save_res.json()
    assert data["dayOfWeek"] == "Monday"
    assert len(data["periods"]) == 2

    # Get class timetable
    get_res = client.get("/api/timetable/Class%2010-A?academicYear=2026-2027", headers={"X-Tenant-ID": "school-a"})
    assert get_res.status_code == 200
    tt = get_res.json()
    assert len(tt) == 1
    assert tt[0]["periods"][0]["subject"] == "Mathematics"
