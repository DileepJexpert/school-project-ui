"""Run acceptance checks only inside an empty dedicated PostgreSQL *_test database.

Set POSTGRES_TEST_URL and run ``python -m scripts.postgres_acceptance``.
The database and generated records are left in place for inspection.
"""

import os
import secrets
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

from sqlalchemy import create_engine, inspect
from sqlalchemy.engine import make_url


def main() -> int:
    url = os.environ.get("POSTGRES_TEST_URL", "")
    if not url:
        raise SystemExit("Set POSTGRES_TEST_URL to an empty PostgreSQL database ending in _test")
    parsed = make_url(url)
    if not parsed.drivername.startswith("postgresql+") or not (parsed.database or "").endswith("_test"):
        raise SystemExit("POSTGRES_TEST_URL must use PostgreSQL and a database name ending in _test")
    probe = create_engine(url, pool_pre_ping=True)
    try:
        with probe.connect() as connection:
            if inspect(connection).get_table_names():
                raise SystemExit("Test database is not empty; refusing to modify it")
    finally:
        probe.dispose()

    env = dict(os.environ, DATABASE_URL=url)
    subprocess.run([sys.executable, "-m", "alembic", "upgrade", "head"], env=env, check=True)
    os.environ["DATABASE_URL"] = url

    from fastapi.testclient import TestClient
    from app.db import SessionLocal
    from app.main import app
    from app.reconcile import audit_session
    from app.schemas import FeeStructureInput
    from app.seed import bootstrap_school

    password = secrets.token_urlsafe(24)
    structure = FeeStructureInput.model_validate({
        "className": "Class 5 - A", "academicYear": "2026-2027",
        "feeComponents": [{"feeName": "Tuition", "amount": 100, "frequency": "MONTHLY"}],
    })
    with SessionLocal.begin() as session:
        bootstrap_school(
            session, "school-pg-test", "PostgreSQL Acceptance School", "2026-2027",
            admin_email="smoke@school.test", admin_password=password,
            fee_structures=[structure],
        )
    with TestClient(app) as client:
        assert client.get("/health/ready").status_code == 200
        login = client.post(
            "/api/auth/login", json={"email": "smoke@school.test", "password": password},
            headers={"X-Tenant-ID": "school-pg-test"},
        )
        assert login.status_code == 200, login.text
        headers = {
            "X-Tenant-ID": "school-pg-test",
            "Authorization": f"Bearer {login.json()['token']}",
        }
        admission = client.post("/api/students/add", json={
            "fullName": "Test Student", "dateOfBirth": "2015-04-10", "gender": "Female",
            "classForAdmission": "Class 5 - A", "academicYear": "2026-2027",
            "dateOfAdmission": "2026-04-01", "parentDetails": {},
            "contactDetails": {}, "previousSchoolDetails": {},
        }, headers=headers)
        assert admission.status_code == 201, admission.text
        student_id = admission.json()["id"]

        barrier = Barrier(2)

        def collect(reference: str):
            with TestClient(app) as worker:
                barrier.wait(timeout=15)
                response = worker.post("/api/fees/collect", json={
                    "studentId": student_id, "academicYear": "2026-2027",
                    "amount": 100, "discount": 0,
                    "installmentNames": ["Tuition - Apr 2026"],
                    "paymentMode": "DIGITAL_PAYMENT", "transactionId": reference,
                }, headers=headers)
                return response.status_code, response.json()

        with ThreadPoolExecutor(max_workers=2) as workers:
            first, second = list(workers.map(collect, ("pg-acceptance-1", "pg-acceptance-2")))
        assert sorted((first[0], second[0])) == [201, 409], (first, second)
        payment = first[1] if first[0] == 201 else second[1]
        profile_url = f"/api/student-fee-profiles/{student_id}"
        assert client.get(profile_url, headers=headers).json()["dueFees"] == 1100
        voided = client.post(
            f"/api/fees/payments/{payment['id']}/void",
            json={"reason": "PostgreSQL acceptance correction"}, headers=headers,
        )
        assert voided.status_code == 200, voided.text
        assert client.get(profile_url, headers=headers).json()["dueFees"] == 1200
        assert client.get("/api/fees/payments?status=VOIDED", headers=headers).json()["totalElements"] == 1
    with SessionLocal() as session:
        issues = audit_session(session, "school-pg-test")
    assert not issues, issues
    print("PostgreSQL migrations, readiness, concurrent fee collection, reversal and reconciliation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
