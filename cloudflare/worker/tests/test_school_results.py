import json
from pathlib import Path
import sqlite3
import sys
from fastapi import FastAPI
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from school_auth import _db, get_current_user
from school_results import router, root_router


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
            class_name TEXT,
            academic_year TEXT,
            roll_number TEXT,
            date_of_admission TEXT,
            status TEXT
        );
        CREATE TABLE enrollments (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            student_id TEXT,
            academic_year TEXT,
            class_name TEXT,
            roll_number TEXT,
            date_of_admission TEXT,
            status TEXT,
            UNIQUE (tenant_id, student_id, academic_year)
        );
        CREATE TABLE exam_configs (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            academic_year TEXT,
            exam_type TEXT,
            display_name TEXT,
            weightage_percent INTEGER,
            max_marks_default INTEGER,
            is_active INTEGER,
            UNIQUE (tenant_id, academic_year, exam_type)
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
            entered_by TEXT,
            is_published INTEGER,
            updated_at TEXT,
            voided_at TEXT,
            UNIQUE (tenant_id, enrollment_id, exam_type, subject)
        );
        CREATE TABLE coscholastic_assessments (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            enrollment_id TEXT,
            term TEXT,
            areas TEXT,
            updated_at TEXT,
            UNIQUE (tenant_id, enrollment_id, term)
        );

        INSERT INTO tenants VALUES ('risingstar', 'Rising Star School', 1);
        INSERT INTO students VALUES ('stu-1', 'risingstar', 'Aashvi Sharma', 'Class 10', '2026-2027', '1', '2026-04-01', 'ACTIVE');
    """)

    app = FastAPI()
    app.include_router(router)
    app.include_router(root_router)
    app.dependency_overrides[_db] = lambda: D1(db)
    app.dependency_overrides[get_current_user] = lambda: {
        "id": "admin-1",
        "username": "admin",
        "name": "Admin",
        "role": "SUPER_ADMIN",
        "permissions": ["*"],
    }
    return TestClient(app)


def test_bulk_submit_and_query_results():
    client = _client()
    payload = {
        "className": "Class 10",
        "examType": "MID_TERM",
        "academicYear": "2026-2027",
        "subject": "Mathematics",
        "maxMarks": 100.0,
        "enteredBy": "Admin",
        "entries": [
            {
                "studentId": "stu-1",
                "studentName": "Aashvi Sharma",
                "marksObtained": 95.0,
                "teacherRemarks": "Outstanding performace"
            }
        ]
    }
    # Test POST /api/results/bulk
    res = client.post("/api/results/bulk", json=payload, headers={"X-Tenant-ID": "risingstar"})
    assert res.status_code == 200
    data = res.json()
    assert len(data) == 1
    assert data[0]["marksObtained"] == 95.0
    assert data[0]["grade"] == "A+"
    assert data[0]["isPassed"] is True

    # Test GET /api/results/class/Class 10/exam/MID_TERM
    res_sheet = client.get("/api/results/class/Class 10/exam/MID_TERM?year=2026-2027", headers={"X-Tenant-ID": "risingstar"})
    assert res_sheet.status_code == 200
    sheet = res_sheet.json()
    assert len(sheet) == 1
    assert sheet[0]["studentName"] == "Aashvi Sharma"

    # Test GET /api/results/student/stu-1/report
    res_rc = client.get("/api/results/student/stu-1/report?year=2026-2027", headers={"X-Tenant-ID": "risingstar"})
    assert res_rc.status_code == 200
    rc = res_rc.json()
    assert rc["studentName"] == "Aashvi Sharma"
    assert len(rc["subjects"]) == 1
    assert rc["cumulativePercentage"] == 95.0

    # Test GET /api/results/class/Class 10/analytics
    res_an = client.get("/api/results/class/Class 10/analytics?year=2026-2027", headers={"X-Tenant-ID": "risingstar"})
    assert res_an.status_code == 200
    an = res_an.json()
    assert an["totalStudents"] == 1
    assert an["classAverage"] == 95.0
    assert an["passPercentage"] == 100.0


def test_exam_config_and_coscholastic():
    client = _client()
    cfg_payload = {
        "academicYear": "2026-2027",
        "examType": "MID_TERM",
        "displayName": "Mid-Term Examination",
        "weightagePercent": 25,
        "maxMarksDefault": 100.0,
        "isActive": True,
    }
    res = client.post("/api/results/exam-config", json=cfg_payload, headers={"X-Tenant-ID": "risingstar"})
    assert res.status_code == 200
    assert res.json()["displayName"] == "Mid-Term Examination"

    res_list = client.get("/api/results/exam-config?year=2026-2027", headers={"X-Tenant-ID": "risingstar"})
    assert res_list.status_code == 200
    assert len(res_list.json()) == 1

    # Test coscholastic
    coscho_payload = {
        "studentId": "stu-1",
        "studentName": "Aashvi Sharma",
        "className": "Class 10",
        "academicYear": "2026-2027",
        "term": "Term 1",
        "areas": [
            {"name": "Work Education", "grade": "A", "remarks": "Very creative"}
        ]
    }
    res_co = client.post("/api/results/coscholastic", json=coscho_payload, headers={"X-Tenant-ID": "risingstar"})
    assert res_co.status_code == 200

    res_get_co = client.get("/api/results/coscholastic/student/stu-1?year=2026-2027", headers={"X-Tenant-ID": "risingstar"})
    assert res_get_co.status_code == 200
    assert len(res_get_co.json()) == 1
