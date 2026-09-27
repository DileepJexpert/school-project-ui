"""Student list/search/detail contract and tenant isolation on D1-shaped SQLite."""

from __future__ import annotations

from pathlib import Path
import sqlite3
import sys

from fastapi import FastAPI
from starlette.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from school_auth import _db, get_current_user  # noqa: E402
from school_students import router  # noqa: E402


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


class D1:
    def __init__(self, db):
        self.db = db

    def prepare(self, sql):
        return Statement(self.db, sql)


def client_for(user):
    db = sqlite3.connect(":memory:", check_same_thread=False)
    db.row_factory = sqlite3.Row
    db.executescript("""
        CREATE TABLE tenants (id TEXT, active INTEGER);
        CREATE TABLE students (id TEXT, tenant_id TEXT, full_name TEXT,
            date_of_birth TEXT, gender TEXT, blood_group TEXT, nationality TEXT,
            religion TEXT, mother_tongue TEXT, aadhar_number TEXT, class_name TEXT,
            academic_year TEXT, date_of_admission TEXT, admission_number TEXT,
            roll_number TEXT, status TEXT, parent_details TEXT, contact_details TEXT,
            previous_school_details TEXT);
        INSERT INTO tenants VALUES ('school-a', 1), ('school-b', 1);
        INSERT INTO students VALUES
            ('a1', 'school-a', 'Asha', '2015-01-01', 'FEMALE', 'O+', '', '', '', '', 'Class 1', '2026-2027', '2026-04-01', 'A-1', '1', 'ACTIVE', '{}', '{}', '{}'),
            ('a2', 'school-a', 'Bela', '2014-01-01', 'FEMALE', 'A+', '', '', '', '', 'Class 2', '2026-2027', '2026-04-01', 'A-2', NULL, 'INACTIVE', '{}', '{}', '{}'),
            ('b1', 'school-b', 'Zoya', '2013-01-01', 'FEMALE', 'B+', '', '', '', '', 'Class 3', '2026-2027', '2026-04-01', 'B-1', '1', 'ACTIVE', '{}', '{}', '{}');
    """)
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[_db] = lambda: D1(db)
    if user is not None:
        app.dependency_overrides[get_current_user] = lambda: user
    return TestClient(app)


ADMIN = {"tenantId": "school-a", "role": "SCHOOL_ADMIN", "permissions": ["students:read"]}


def test_students_list_and_search_match_flutter_contract():
    client = client_for(ADMIN)
    response = client.get("/api/students", headers={"X-Tenant-ID": "school-a"})
    assert response.status_code == 200
    assert [item["id"] for item in response.json()] == ["a1", "a2"]
    assert response.json()[0]["dateOfBirth"] == "2015-01-01"
    assert response.json()[0]["parentDetails"] == {}
    assert [s["id"] for s in client.get("/api/students/search", params={"name": "ash"},
                                     headers={"X-Tenant-ID": "school-a"}).json()] == ["a1"]
    assert client.get("/api/students/a1", headers={"X-Tenant-ID": "school-a"}).json()["fullName"] == "Asha"


def test_students_are_tenant_scoped_and_read_requires_auth_permission():
    client = client_for(ADMIN)
    assert client.get("/api/students/b1", headers={"X-Tenant-ID": "school-a"}).status_code == 404
    assert client_for({**ADMIN, "permissions": []}).get("/api/students").status_code == 403
    assert client_for(None).get("/api/students").status_code == 401
