"""Admin summary contracts against SQLite using the Worker D1 query interface."""

from __future__ import annotations

from datetime import date
from pathlib import Path
import sqlite3
import sys

from fastapi import FastAPI
from starlette.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from school_overview import router, _db, require_admin  # noqa: E402


class Statement:
    def __init__(self, db: sqlite3.Connection, sql: str, values: tuple = ()):
        self.db, self.sql, self.values = db, sql, values

    def bind(self, *values):
        return Statement(self.db, self.sql, values)

    async def first(self):
        row = self.db.execute(self.sql, self.values).fetchone()
        return dict(row) if row else None

    async def all(self):
        return [dict(row) for row in self.db.execute(self.sql, self.values).fetchall()]


class D1:
    def __init__(self, db: sqlite3.Connection):
        self.db = db

    def prepare(self, sql: str):
        return Statement(self.db, sql)


def _client(*, admin: bool = True):
    db = sqlite3.connect(":memory:", check_same_thread=False)
    db.row_factory = sqlite3.Row
    db.executescript("""
        CREATE TABLE tenants (id TEXT, active INTEGER);
        CREATE TABLE students (tenant_id TEXT, status TEXT, class_name TEXT);
        CREATE TABLE enrollments (id TEXT, tenant_id TEXT);
        CREATE TABLE fee_profiles (id TEXT, tenant_id TEXT, enrollment_id TEXT);
        CREATE TABLE payments (tenant_id TEXT, profile_id TEXT, voided_at TEXT,
            amount_paid INTEGER, discount INTEGER, payment_date TEXT, payment_mode TEXT);
        CREATE TABLE fee_installments (profile_id TEXT, amount_due INTEGER,
            paid_amount INTEGER, discount_amount INTEGER);
        CREATE TABLE staff (id TEXT, tenant_id TEXT, full_name TEXT, designation TEXT,
            deleted_at TEXT, status TEXT, basic_salary INTEGER, department TEXT, details TEXT);
        CREATE TABLE leave_requests (tenant_id TEXT, staff_id TEXT, status TEXT,
            from_date TEXT, to_date TEXT);
        INSERT INTO tenants VALUES ('school-a', 1), ('school-b', 1), ('inactive', 0);
        INSERT INTO students VALUES
            ('school-a', 'ACTIVE', 'Class 1'), ('school-a', 'ACTIVE', 'Class 1'),
            ('school-a', 'INACTIVE', 'Class 2'), ('school-b', 'ACTIVE', 'Class 9');
        INSERT INTO enrollments VALUES ('e-a', 'school-a'), ('e-b', 'school-b');
        INSERT INTO fee_profiles VALUES
            ('fp-a', 'school-a', 'e-a'), ('fp-b', 'school-b', 'e-b');
        INSERT INTO payments VALUES
            ('school-a', 'fp-a', NULL, 12345, 500, '2026-09-15', 'CASH'),
            ('school-a', 'fp-a', '2026-09-16', 1000, 0, '2026-09-16', 'CASH'),
            ('school-b', 'fp-b', NULL, 99900, 0, '2026-09-15', 'CASH');
        INSERT INTO fee_installments VALUES
            ('fp-a', 20000, 12345, 500), ('fp-b', 99900, 99900, 0);
        INSERT INTO staff VALUES
            ('s-a', 'school-a', 'Teacher A', 'Math Teacher', NULL, 'ACTIVE', 100000, 'Teaching', NULL),
            ('s-b', 'school-a', 'Clerk B', 'Office Clerk', NULL, 'INACTIVE', 20000, 'Office', NULL),
            ('s-deleted', 'school-a', 'Deleted C', 'Teacher', '2026-09-01', 'ACTIVE', 30000, 'Teaching', NULL),
            ('s-other', 'school-b', 'Other D', 'Teacher', NULL, 'ACTIVE', 250000, 'Teaching', NULL);
    """)
    today = date.today().isoformat()
    db.executemany(
        "INSERT INTO leave_requests VALUES (?, ?, ?, ?, ?)",
        [
            ("school-a", "s-a", "APPROVED", today, today),
            ("school-a", "s-a", "PENDING", today, today),
            ("school-b", "s-other", "PENDING", today, today),
        ],
    )
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[_db] = lambda: D1(db)
    if admin:
        app.dependency_overrides[require_admin] = lambda: {
            "role": "SCHOOL_ADMIN", "tenantId": "school-a"
        }
    return TestClient(app)


def test_summary_uses_real_tenant_data_and_ignores_voided_payments():
    client = _client()
    result = client.get("/api/reports/school-summary", headers={"X-Tenant-ID": "school-a"})
    assert result.status_code == 200
    body = result.json()
    assert body["totalStudents"] == 2
    assert body["enrollmentByClass"] == {"Class 1": 2}
    assert body["totalFeesCollected"] == 123.45
    assert body["totalFeesDue"] == 71.55
    assert body["totalDiscountGiven"] == 5.0
    assert body["totalTransactions"] == 1
    assert body["monthlyCollections"] == [
        {"month": 9, "year": 2026, "label": "2026-09", "amount": 123.45}
    ]
    assert body["paymentModeSummary"] == [{"paymentMode": "CASH", "totalAmount": 123.45}]


def test_staff_summary_excludes_deleted_and_other_school():
    client = _client()
    result = client.get("/api/staff/dashboard", headers={"X-Tenant-ID": "school-a"})
    assert result.status_code == 200
    data = result.json()
    assert data["totalStaff"] == 2
    assert data["activeStaff"] == 1
    assert data["onLeaveToday"] == 1
    assert data["pendingLeaveRequests"] == 1
    assert data["departmentWise"] == {"Teaching": 1, "Office": 1}
    assert data["totalMonthlyPayroll"] == 1000.0
    assert "categoryBreakdown" in data
    teacher_cat = next((c for c in data["categoryBreakdown"] if c["category"] == "TEACHER"), None)
    assert teacher_cat is not None
    assert teacher_cat["count"] == 1


def test_overview_requires_auth_and_rejects_inactive_school():
    assert _client(admin=False).get(
        "/api/reports/school-summary", headers={"X-Tenant-ID": "school-a"}
    ).status_code == 401
    app_client = _client()
    # A platform admin may select a school explicitly.
    app_client.app.dependency_overrides[require_admin] = lambda: {
        "role": "SUPER_ADMIN", "tenantId": None
    }
    assert app_client.get(
        "/api/staff/dashboard", headers={"X-Tenant-ID": "inactive"}
    ).status_code == 404
