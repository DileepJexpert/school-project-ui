"""Schema parity and safety checks for the D1 migration SQL."""

from pathlib import Path
import sqlite3
import sys

import pytest


WORKER = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(WORKER))

from generate_school_schema import MODEL_TABLES, schema_sql  # noqa: E402


def migration_text(name: str) -> str:
    return (WORKER / "migrations" / name).read_text(encoding="utf-8")


def new_probe_db() -> sqlite3.Connection:
    db = sqlite3.connect(":memory:")
    db.execute("PRAGMA foreign_keys = ON")
    db.executescript(migration_text("0001_initial.sql"))
    return db


def test_generated_migration_is_checked_in_and_covers_every_model_table():
    assert schema_sql() == migration_text("0002_school_schema.sql")
    db = new_probe_db()
    db.executescript(migration_text("0002_school_schema.sql"))
    tables = {
        row[0] for row in db.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
        )
    }
    assert MODEL_TABLES.issubset(tables)
    assert len(MODEL_TABLES) == 44
    assert db.execute("PRAGMA foreign_key_check").fetchall() == []
    assert db.execute(
        "SELECT version FROM schema_versions ORDER BY version DESC LIMIT 1"
    ).fetchone() == ("0002_school_schema",)
    assert db.execute("PRAGMA table_info(users)").fetchall()
    assert db.execute("PRAGMA table_info(auth_sessions)").fetchall()


def test_existing_data_blocks_destructive_probe_table_replacement():
    db = new_probe_db()
    db.execute(
        "INSERT INTO tenants (id, name, created_at) VALUES (?, ?, ?)",
        ("do-not-delete", "Existing School", "2026-09-27"),
    )
    with pytest.raises(sqlite3.IntegrityError):
        db.executescript(migration_text("0002_school_schema.sql"))
    assert db.execute("SELECT name FROM tenants WHERE id = 'do-not-delete'").fetchone() == (
        "Existing School",
    )


def test_money_is_integer_minor_units_and_partial_unique_index_is_preserved():
    db = new_probe_db()
    db.executescript(migration_text("0002_school_schema.sql"))
    db.execute("INSERT INTO tenants (id, name, active, city, board) VALUES ('school-a', 'A', 1, '', '')")
    db.execute(
        "INSERT INTO fee_structures (id, tenant_id, class_name, academic_year) "
        "VALUES ('fee-a', 'school-a', 'Class 1 - A', '2026-2027')"
    )
    db.execute(
        "INSERT INTO fee_components (id, structure_id, position, name, amount, frequency, description) "
        "VALUES ('component-a', 'fee-a', 0, 'Tuition', 12500, 'MONTHLY', '')"
    )
    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            "INSERT INTO fee_components (id, structure_id, position, name, amount, frequency, description) "
            "VALUES ('component-b', 'fee-a', 1, 'Transport', 125.50, 'MONTHLY', '')"
        )
    index_sql = db.execute(
        "SELECT sql FROM sqlite_master WHERE type = 'index' AND name = 'uq_transport_active_student'"
    ).fetchone()[0]
    assert "WHERE status = 'ACTIVE'" in index_sql
