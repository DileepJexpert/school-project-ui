import json
from pathlib import Path
import sqlite3
import sys
from fastapi import FastAPI
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from school_auth import _db, get_current_user, require_admin
from school_certificates import router, root_router


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
        CREATE TABLE students (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            full_name TEXT,
            date_of_birth TEXT,
            gender TEXT,
            blood_group TEXT,
            nationality TEXT,
            religion TEXT,
            mother_tongue TEXT,
            aadhar_number TEXT,
            class_name TEXT,
            academic_year TEXT,
            date_of_admission TEXT,
            admission_number TEXT,
            roll_number TEXT,
            status TEXT,
            parent_details TEXT,
            contact_details TEXT,
            previous_school_details TEXT
        );
        CREATE TABLE certificate_records (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            student_id TEXT,
            student_name TEXT,
            class_name TEXT,
            academic_year TEXT,
            certificate_type TEXT,
            serial_number TEXT,
            reason TEXT,
            additional_fields TEXT,
            generated_by TEXT,
            generated_at TEXT
        );
        INSERT INTO tenants VALUES ('school-a', 'School A', 1);
        INSERT INTO students (id, tenant_id, full_name, class_name, academic_year, admission_number, parent_details)
        VALUES ('stu-001', 'school-a', 'Rohan Sharma', 'Class 10-A', '2025-2026', 'ADM-1001', '{"fatherName": "Rajesh Sharma"}');
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


def test_list_certificates_empty_initially():
    client = _client()
    res = client.get("/api/certificates", headers={"X-Tenant-ID": "school-a"})
    assert res.status_code == 200
    assert res.json() == []


def test_generate_certificate_and_list():
    client = _client()
    gen_res = client.post(
        "/api/certificates/generate",
        headers={"X-Tenant-ID": "school-a"},
        json={
            "studentId": "stu-001",
            "certificateType": "TRANSFER",
            "reason": "Family relocation to another city",
        },
    )
    assert gen_res.status_code == 200
    cert = gen_res.json()
    assert cert["studentName"] == "Rohan Sharma"
    assert cert["className"] == "Class 10-A"
    assert cert["academicYear"] == "2025-2026"
    assert cert["certificateType"] == "TRANSFER"
    assert cert["serialNumber"].startswith("TC-")
    assert cert["fatherName"] == "Rajesh Sharma"
    assert cert["admissionNumber"] == "ADM-1001"
    assert cert["reason"] == "Family relocation to another city"

    # List all
    list_res = client.get("/api/certificates", headers={"X-Tenant-ID": "school-a"})
    assert list_res.status_code == 200
    all_certs = list_res.json()
    assert len(all_certs) == 1
    assert all_certs[0]["id"] == cert["id"]

    # Filter by type
    type_res = client.get("/api/certificates/type/TRANSFER", headers={"X-Tenant-ID": "school-a"})
    assert type_res.status_code == 200
    assert len(type_res.json()) == 1

    other_type_res = client.get("/api/certificates/type/BONAFIDE", headers={"X-Tenant-ID": "school-a"})
    assert other_type_res.status_code == 200
    assert len(other_type_res.json()) == 0


def test_generate_by_admission_number():
    client = _client()
    gen_res = client.post(
        "/certificates/generate",
        headers={"X-Tenant-ID": "school-a"},
        json={
            "studentId": "ADM-1001",
            "certificateType": "BONAFIDE",
            "reason": "Passport application",
        },
    )
    assert gen_res.status_code == 200
    cert = gen_res.json()
    assert cert["studentName"] == "Rohan Sharma"
    assert cert["certificateType"] == "BONAFIDE"
    assert cert["serialNumber"].startswith("BON-")


def test_generate_non_existent_student_throws_404():
    client = _client()
    res = client.post(
        "/api/certificates/generate",
        headers={"X-Tenant-ID": "school-a"},
        json={
            "studentId": "unknown-student",
            "certificateType": "STUDY",
        },
    )
    assert res.status_code == 404
