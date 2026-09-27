from sqlalchemy import create_engine, text
from sqlalchemy.pool import StaticPool

from app import main as main_module


def test_readiness_requires_current_database_migration(client, monkeypatch):
    database = create_engine(
        "sqlite+pysqlite://", poolclass=StaticPool,
        connect_args={"check_same_thread": False},
    )
    monkeypatch.setattr(main_module, "engine", database)
    try:
        assert client.get("/health/live").status_code == 200
        assert client.get("/health/ready").status_code == 503
        with database.begin() as connection:
            connection.execute(text("CREATE TABLE alembic_version (version_num VARCHAR(32) NOT NULL)"))
            connection.execute(text("INSERT INTO alembic_version VALUES ('outdated')"))
        assert client.get("/health/ready").status_code == 503
        with database.begin() as connection:
            connection.execute(text("UPDATE alembic_version SET version_num = '20260924_23'"))
        assert client.get("/health/ready").json() == {"status": "ready"}
    finally:
        database.dispose()
