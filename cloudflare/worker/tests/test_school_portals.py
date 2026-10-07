import json
from pathlib import Path
import sqlite3
import sys
from fastapi import FastAPI
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from school_auth import _db, get_current_user
from school_portals import (
    parent_router, parent_root_router,
    student_router, student_root_router
)


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
        CREATE TABLE users (id TEXT PRIMARY KEY, tenant_id TEXT, username TEXT, full_name TEXT, role TEXT, phone TEXT);
        CREATE TABLE students (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            full_name TEXT,
            class_name TEXT,
            academic_year TEXT,
            roll_number TEXT,
            aadhar_number TEXT,
            parent_details TEXT,
            contact_details TEXT,
            status TEXT
        );
        CREATE TABLE attendance (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            student_id TEXT,
            date TEXT,
            status TEXT,
            remarks TEXT
        );
        CREATE TABLE fee_installments (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            student_id TEXT,
            amount REAL,
            due_date TEXT,
            status TEXT
        );
        CREATE TABLE payments (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            student_id TEXT,
            amount REAL,
            payment_date TEXT
        );
        CREATE TABLE homework (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            class_name TEXT,
            due_date TEXT
        );
        CREATE TABLE timetable_days (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            class_name TEXT,
            academic_year TEXT,
            day_of_week TEXT
        );
        CREATE TABLE timetable_periods (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            timetable_day_id TEXT,
            period_number INTEGER,
            subject TEXT,
            teacher_name TEXT,
            start_time TEXT,
            end_time TEXT
        );
        CREATE TABLE enrollments (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            student_id TEXT,
            academic_year TEXT,
            class_name TEXT,
            roll_number TEXT,
            status TEXT
        );
        CREATE TABLE result_records (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            enrollment_id TEXT,
            exam_type TEXT,
            subject TEXT,
            marks_obtained INTEGER,
            max_marks INTEGER,
            teacher_remarks TEXT,
            voided_at TEXT
        );
        CREATE TABLE coscholastic_assessments (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            enrollment_id TEXT,
            term TEXT,
            areas TEXT
        );

        INSERT INTO tenants VALUES ('risingstar', 'Rising Star School', 1);
        INSERT INTO students VALUES (
            'stu-1', 'risingstar', 'Aashvi Sharma', 'Class 10', '2026-2027', '1', '123456789012',
            '{"fatherPhone": "9876543210"}', '{"phone": "9876543210"}', 'ACTIVE'
        );
        INSERT INTO users VALUES ('user-p1', 'risingstar', 'parent1', 'Parent Sharma', 'PARENT', '9876543210');
        INSERT INTO users VALUES ('user-s1', 'risingstar', 'student1', 'Aashvi Sharma', 'STUDENT', '9876543210');
        INSERT INTO attendance VALUES ('att-1', 'risingstar', 'stu-1', '2026-10-01', 'PRESENT', 'On time');
    """)

    app = FastAPI()
    app.include_router(parent_router)
    app.include_router(parent_root_router)
    app.include_router(student_router)
    app.include_router(student_root_router)
    app.dependency_overrides[_db] = lambda: D1(db)
    app.dependency_overrides[get_current_user] = lambda: {
        "id": "user-p1",
        "username": "parent1",
        "name": "Parent Sharma",
        "role": "PARENT",
        "phone": "9876543210",
    }
    return TestClient(app)


def test_parent_and_student_portal():
    client = _client()

    # Parent dashboard
    res_dash = client.get("/api/parent/dashboard", headers={"X-Tenant-ID": "risingstar"})
    assert res_dash.status_code == 200
    dash = res_dash.json()
    assert len(dash["children"]) >= 1
    assert dash["children"][0]["fullName"] == "Aashvi Sharma"

    # Child attendance summary
    res_att = client.get("/api/parent/child/stu-1/attendance/summary", headers={"X-Tenant-ID": "risingstar"})
    assert res_att.status_code == 200
    assert "presentDays" in res_att.json()

    # Student portal dashboard
    res_s_dash = client.get("/api/student-portal/dashboard", headers={"X-Tenant-ID": "risingstar"})
    assert res_s_dash.status_code == 200
    assert res_s_dash.json()["student"]["fullName"] == "Aashvi Sharma"
