import os

os.environ["DATABASE_URL"] = "sqlite+pysqlite://"
os.environ["SCHOOL_YEAR_START_MONTH"] = "4"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base, get_session
from app.main import app
from app.auth import password_hash
from app.models import Tenant, User
from datetime import datetime, timezone


@pytest.fixture
def client():
    engine = create_engine(
        "sqlite+pysqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    sessions = sessionmaker(bind=engine, expire_on_commit=False)
    with sessions.begin() as session:
        session.add_all([
            Tenant(id="school-a", name="School A"),
            Tenant(id="school-b", name="School B"),
            User(
                scope="school-a", tenant_id="school-a", email="admin@school.test",
                password_hash=password_hash("test-password-123"), full_name="Test Admin",
                phone="", role="SCHOOL_ADMIN", extra_permissions=[], active=True,
                created_at=datetime.now(timezone.utc),
            ),
        ])

    def override_session():
        with sessions() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    with TestClient(app) as test_client:
        login = test_client.post(
            "/api/auth/login",
            json={"email": "admin@school.test", "password": "test-password-123"},
            headers={"X-Tenant-ID": "school-a"},
        )
        assert login.status_code == 200, login.text
        test_client.headers.update({"Authorization": f"Bearer {login.json()['token']}"})
        yield test_client
    app.dependency_overrides.clear()
    Base.metadata.drop_all(engine)
    engine.dispose()
