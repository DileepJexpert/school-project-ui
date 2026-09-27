from decimal import Decimal

from sqlalchemy import select

from app.db import get_session
from app.main import app
from app.models import FeeInstallment
from app.reconcile import audit_session
from test_admission_flow import HEADERS, student_payload, structure


def test_reconciliation_detects_cached_fee_balance_drift(client):
    assert client.post(
        "/api/feestructures", json=[structure("Class 5 - A", "2026-2027")], headers=HEADERS
    ).status_code == 200
    assert client.post("/api/students/add", json=student_payload(), headers=HEADERS).status_code == 201
    session_source = app.dependency_overrides[get_session]()
    session = next(session_source)
    try:
        assert audit_session(session, "school-a") == []
        installment = session.scalar(select(FeeInstallment).order_by(FeeInstallment.position).limit(1))
        installment.paid_amount = Decimal("1.00")
        session.flush()
        issues = audit_session(session, "school-a")
        assert any("cached balance differs from allocations" in issue for issue in issues)
    finally:
        session.rollback()
        session_source.close()
