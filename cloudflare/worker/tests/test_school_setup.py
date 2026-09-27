"""First-run setup and fee editor contract on D1-shaped SQLite."""

from __future__ import annotations

from pathlib import Path
import sqlite3
import sys

from fastapi import FastAPI
from starlette.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from school_auth import _db, get_current_user, require_admin  # noqa: E402
from school_setup import router as setup_router  # noqa: E402
from school_fee_structures import router as fees_router  # noqa: E402


class Statement:
    def __init__(self, db, sql, values=()):
        self.db, self.sql, self.values = db, sql, values

    def bind(self, *values):
        return Statement(self.db, self.sql, values)

    async def first(self):
        row = self.db.execute(self.sql, self.values).fetchone()
        return dict(row) if row else None

    async def all(self):
        return [dict(row) for row in self.db.execute(self.sql, self.values).fetchall()]

    async def run(self):
        with self.db:
            self.db.execute(self.sql, self.values)


class D1:
    def __init__(self, db):
        self.db = db

    def prepare(self, sql):
        return Statement(self.db, sql)

    async def batch(self, statements):
        with self.db:
            for statement in statements:
                self.db.execute(statement.sql, statement.values)


USER = {"tenantId": "school-a", "role": "SCHOOL_ADMIN",
        "permissions": ["fees:read", "fees:write"]}


def _client():
    db = sqlite3.connect(":memory:", check_same_thread=False)
    db.row_factory = sqlite3.Row
    db.executescript("""
        CREATE TABLE tenants (id TEXT, name TEXT, active INTEGER, city TEXT, board TEXT);
        CREATE TABLE academic_years (tenant_id TEXT, year TEXT, start_date TEXT,
            end_date TEXT, status TEXT, grade_bands TEXT, pass_percentage INTEGER, exam_order TEXT);
        CREATE TABLE school_classes (tenant_id TEXT, class_name TEXT, base_class TEXT,
            section TEXT, sort_order INTEGER, active INTEGER);
        CREATE TABLE school_subjects (tenant_id TEXT, name TEXT, sort_order INTEGER, active INTEGER);
        CREATE TABLE fee_structures (id TEXT PRIMARY KEY, tenant_id TEXT,
            class_name TEXT, academic_year TEXT);
        CREATE TABLE fee_components (id TEXT, structure_id TEXT, position INTEGER,
            name TEXT, amount INTEGER, frequency TEXT, description TEXT);
        CREATE TABLE fee_profiles (id TEXT, tenant_id TEXT, fee_structure_id TEXT);
        CREATE TABLE class_subjects (tenant_id TEXT, academic_year TEXT, class_name TEXT);
        INSERT INTO tenants VALUES ('school-a', 'Rising Star', 1, 'Gonda', 'CBSE');
        INSERT INTO academic_years VALUES ('school-a', '2026-2027', '2026-04-01',
            '2027-03-31', 'ACTIVE', NULL, NULL, NULL);
        INSERT INTO school_classes VALUES ('school-a', 'Class 1 - A', 'Class 1', 'A', 1, 1);
    """)
    app = FastAPI()
    app.include_router(setup_router)
    app.include_router(fees_router)
    app.dependency_overrides[_db] = lambda: D1(db)
    app.dependency_overrides[get_current_user] = lambda: USER
    app.dependency_overrides[require_admin] = lambda: USER
    return TestClient(app), db


def test_school_setup_and_fee_structure_round_trip():
    client, db = _client()
    headers = {"X-Tenant-ID": "school-a"}
    profile = client.get("/api/school/profile", headers=headers)
    assert profile.status_code == 200
    assert profile.json()["name"] == "Rising Star"
    assert client.put("/api/school/profile", json={"name": "Rising Star Public School"}, headers=headers).json()["name"] == "Rising Star Public School"
    catalogue = client.get("/api/master-data", params={"academicYear": "2026-2027"}, headers=headers).json()
    assert catalogue["missingFeeClasses"] == ["Class 1 - A"]
    assert client.get("/api/feestructures", params={"year": "2026-2027"}, headers=headers).json() == []
    payload = [{"className": "Class 1 - A", "academicYear": "2026-2027",
                "feeComponents": [{"feeName": "Tuition", "amount": 150.50, "frequency": "MONTHLY"}]}]
    saved = client.post("/api/feestructures", json=payload, headers=headers)
    assert saved.status_code == 200, saved.text
    assert saved.json()[0]["feeComponents"][0]["amount"] == 150.5
    structure_id = saved.json()[0]["id"]
    assert db.execute("SELECT amount FROM fee_components").fetchone()[0] == 15050
    assert client.get("/api/master-data", params={"academicYear": "2026-2027"}, headers=headers).json()["configuredFeeClasses"] == ["Class 1 - A"]
    db.execute("INSERT INTO fee_profiles VALUES ('fp', 'school-a', ?)", (structure_id,))
    db.commit()
    assert client.delete(f"/api/feestructures/{structure_id}", headers=headers).status_code == 409


def test_fee_write_requires_permission_and_rejects_fractional_minor_units():
    client, _ = _client()
    headers = {"X-Tenant-ID": "school-a"}
    payload = [{"className": "Class 1 - A", "academicYear": "2026-2027",
                "feeComponents": [{"feeName": "Tuition", "amount": 0.001}]}]
    assert client.post("/api/feestructures", json=payload, headers=headers).status_code == 422
    client.app.dependency_overrides[get_current_user] = lambda: {**USER, "permissions": ["fees:read"]}
    assert client.post("/api/feestructures", json=payload, headers=headers).status_code == 403
