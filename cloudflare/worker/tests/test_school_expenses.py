"""Expense ledger round-trip, voiding, and school isolation."""

from __future__ import annotations

from pathlib import Path
import sqlite3
import sys

from fastapi import FastAPI
from starlette.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from school_auth import _db, get_current_user  # noqa: E402
from school_expenses import router  # noqa: E402


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


def test_expense_ledger_is_persisted_filtered_and_voided():
    db = sqlite3.connect(":memory:", check_same_thread=False)
    db.row_factory = sqlite3.Row
    db.executescript("""
        CREATE TABLE tenants (id TEXT, active INTEGER);
        CREATE TABLE expenses (id TEXT, tenant_id TEXT, title TEXT, category TEXT,
            amount INTEGER, date TEXT, paid_to TEXT, remarks TEXT, created_at TEXT,
            voided_at TEXT);
        INSERT INTO tenants VALUES ('school-a', 1), ('school-b', 1);
        INSERT INTO expenses VALUES ('other', 'school-b', 'Hidden', 'Misc', 9900,
            '2026-09-01', 'Other', NULL, '2026-09-01', NULL);
    """)
    user = {"tenantId": "school-a", "role": "SCHOOL_ADMIN",
            "permissions": ["expenses:read", "expenses:write"]}
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[_db] = lambda: D1(db)
    app.dependency_overrides[get_current_user] = lambda: user
    client = TestClient(app)
    headers = {"X-Tenant-ID": "school-a"}
    assert client.get("/api/expenses", headers=headers).json() == []
    created = client.post("/api/expenses", json={"title": "Books", "category": "Supplies",
        "amount": 125.75, "date": "2026-09-27", "paidTo": "Vendor"}, headers=headers)
    assert created.status_code == 201, created.text
    assert created.json()["amount"] == 125.75
    assert [e["title"] for e in client.get("/api/expenses", headers=headers).json()] == ["Books"]
    assert client.get("/api/expenses", params={"from": "2026-10-01"}, headers=headers).json() == []
    assert client.delete(f"/api/expenses/{created.json()['id']}", headers=headers).status_code == 204
    assert client.get("/api/expenses", headers=headers).json() == []
    assert db.execute("SELECT amount FROM expenses WHERE tenant_id = 'school-a'").fetchone()[0] == 12575
    assert client.delete("/api/expenses/other", headers=headers).status_code == 404
