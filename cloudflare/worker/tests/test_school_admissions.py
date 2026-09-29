"""First enquiry/admission workflow, fee installments, and tenant boundary."""

from __future__ import annotations

from pathlib import Path
import sqlite3
import sys

from fastapi import FastAPI
from starlette.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from school_auth import _db, get_current_user  # noqa: E402
from school_students import router as read_router  # noqa: E402
from school_admissions import router as write_router  # noqa: E402


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
        "permissions": ["students:read", "students:write"]}


def _client():
    db = sqlite3.connect(":memory:", check_same_thread=False)
    db.row_factory = sqlite3.Row
    db.executescript("""
        CREATE TABLE tenants (id TEXT, active INTEGER);
        CREATE TABLE school_classes (id TEXT, tenant_id TEXT, class_name TEXT, base_class TEXT, active INTEGER);
        CREATE TABLE class_year_closures (id TEXT, tenant_id TEXT, class_name TEXT, academic_year TEXT);
        CREATE TABLE students (id TEXT, tenant_id TEXT, full_name TEXT, date_of_birth TEXT,
            gender TEXT, blood_group TEXT, nationality TEXT, religion TEXT,
            mother_tongue TEXT, aadhar_number TEXT, class_name TEXT, academic_year TEXT,
            date_of_admission TEXT, admission_number TEXT, roll_number TEXT, status TEXT,
            parent_details TEXT, contact_details TEXT, previous_school_details TEXT);
        CREATE TABLE fee_structures (id TEXT, tenant_id TEXT, class_name TEXT, academic_year TEXT);
        CREATE TABLE fee_components (structure_id TEXT, position INTEGER, name TEXT,
            amount INTEGER, frequency TEXT);
        CREATE TABLE enrollments (id TEXT, tenant_id TEXT, student_id TEXT,
            academic_year TEXT, class_name TEXT, roll_number TEXT, date_of_admission TEXT,
            status TEXT);
        CREATE TABLE fee_profiles (id TEXT, tenant_id TEXT, enrollment_id TEXT,
            fee_structure_id TEXT);
        CREATE TABLE fee_installments (id TEXT, profile_id TEXT, position INTEGER,
            name TEXT, amount_due INTEGER, paid_amount INTEGER, discount_amount INTEGER,
            status TEXT);
        INSERT INTO tenants VALUES ('school-a', 1), ('school-b', 1);
        INSERT INTO school_classes VALUES ('c-a', 'school-a', 'Class 1 - A', 'Class 1', 1);
    """)
    app = FastAPI()
    app.include_router(read_router)
    app.include_router(write_router)
    app.dependency_overrides[_db] = lambda: D1(db)
    app.dependency_overrides[get_current_user] = lambda: USER
    return TestClient(app), db


PAYLOAD = {
    "fullName": "Asha", "dateOfBirth": "2015-06-10", "gender": "Female",
    "classForAdmission": "Class 1 - A", "academicYear": "2026-2027",
    "dateOfAdmission": "2026-09-27", "status": "ACTIVE",
    "parentDetails": {"fatherName": "Raj"},
    "contactDetails": {"primaryContactNumber": "1234567890"},
}


def test_enquiry_to_admission_requires_fees_and_creates_april_march_installments():
    client, db = _client()
    headers = {"X-Tenant-ID": "school-a"}
    response = client.post("/api/students/enquiry", json=PAYLOAD, headers=headers)
    assert response.status_code == 201, response.text
    enquiry = response.json()
    assert enquiry["status"] == "ENQUIRY"
    assert enquiry["admissionNumber"].startswith("ENQ-")
    assert enquiry["parentDetails"]["fatherName"] == "Raj"
    assert client.put(f"/api/students/{enquiry['id']}", json=PAYLOAD, headers=headers).status_code == 409
    db.executescript("""
        INSERT INTO fee_structures VALUES ('fs1', 'school-a', 'Class 1 - A', '2026-2027');
        INSERT INTO fee_components VALUES ('fs1', 0, 'Tuition', 15050, 'MONTHLY');
    """)
    admitted = client.put(f"/api/students/{enquiry['id']}", json=PAYLOAD, headers=headers)
    assert admitted.status_code == 200, admitted.text
    assert admitted.json()["status"] == "ACTIVE"
    assert admitted.json()["admissionNumber"].startswith("ADM-")
    names = [r[0] for r in db.execute("SELECT name FROM fee_installments ORDER BY position")]
    assert len(names) == 12
    assert names[0] == "Tuition - Apr 2026"
    assert names[-1] == "Tuition - Mar 2027"
    assert client.delete(f"/api/students/{enquiry['id']}", headers=headers).status_code == 409
    assert client.get(f"/api/students/{enquiry['id']}", headers=headers).json()["fullName"] == "Asha"


def test_direct_admission_and_enquiry_delete_are_school_scoped():
    client, db = _client()
    headers = {"X-Tenant-ID": "school-a"}
    db.executescript("""
        INSERT INTO fee_structures VALUES ('fs1', 'school-a', 'Class 1 - A', '2026-2027');
        INSERT INTO fee_components VALUES ('fs1', 0, 'Annual', 100000, 'YEARLY');
    """)
    admitted = client.post("/api/students/add", json=PAYLOAD, headers=headers)
    assert admitted.status_code == 201, admitted.text
    assert db.execute("SELECT COUNT(*) FROM fee_installments").fetchone()[0] == 1
    inquiry = client.post("/api/students/enquiry", json=PAYLOAD, headers=headers).json()
    assert client.delete(f"/api/students/{inquiry['id']}", headers=headers).status_code == 204
    assert client.get(f"/api/students/{inquiry['id']}", headers=headers).status_code == 404
    assert client.post("/api/students/enquiry", json=PAYLOAD,
                       headers={"X-Tenant-ID": "school-b"}).status_code == 403


def test_enquiry_accepts_base_class_but_admission_requires_section():
    client, db = _client()
    headers = {"X-Tenant-ID": "school-a"}
    interested = {**PAYLOAD, "classForAdmission": "Class 1", "status": "ENQUIRY"}

    created = client.post("/api/students/enquiry", json=interested, headers=headers)
    assert created.status_code == 201, created.text
    student_id = created.json()["id"]
    assert created.json()["classForAdmission"] == "Class 1"
    assert client.put(f"/api/students/{student_id}", json=interested, headers=headers).status_code == 200
    assert client.post("/api/students/add", json=interested, headers=headers).status_code == 409

    db.executescript("""
        INSERT INTO fee_structures VALUES ('fs1', 'school-a', 'Class 1 - A', '2026-2027');
        INSERT INTO fee_components VALUES ('fs1', 0, 'Annual', 100000, 'YEARLY');
    """)
    admitted = client.put(f"/api/students/{student_id}",
                          json={**PAYLOAD, "status": "ACTIVE"}, headers=headers)
    assert admitted.status_code == 200, admitted.text
    assert admitted.json()["classForAdmission"] == "Class 1 - A"
    assert db.execute("SELECT COUNT(*) FROM enrollments WHERE student_id = ?", (student_id,)).fetchone()[0] == 1
