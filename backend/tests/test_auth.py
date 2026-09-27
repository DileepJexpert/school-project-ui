from datetime import datetime, timezone

import bcrypt

from app.auth import password_hash, verify_password
from app.db import get_session
from app.main import app
from app.models import User

TENANT = {"X-Tenant-ID": "school-a"}


def test_school_login_refresh_logout_and_tenant_binding(client):
    assert client.post(
        "/api/auth/login", json={"email": "admin@school.test", "password": "bad"}, headers=TENANT
    ).status_code == 401
    login = client.post(
        "/api/auth/login", json={"email": "ADMIN@SCHOOL.TEST", "password": "test-password-123"}, headers=TENANT
    )
    assert login.status_code == 200, login.text
    first = login.json()
    assert first["userId"] and first["tenantId"] == "school-a"
    assert first["role"] == "SCHOOL_ADMIN"
    assert "fees:write" in first["permissions"]
    refreshed = client.post("/api/auth/refresh", json={"refreshToken": first["refreshToken"]})
    assert refreshed.status_code == 200, refreshed.text
    assert refreshed.json()["token"] != first["token"]
    assert client.post("/api/auth/refresh", json={"refreshToken": first["refreshToken"]}).status_code == 401
    assert client.get("/api/students", headers={**TENANT, "Authorization": f"Bearer {first['token']}"}).status_code == 401
    new_token = refreshed.json()["token"]
    assert client.get("/api/students", headers={**TENANT, "Authorization": f"Bearer {new_token}"}).status_code == 200
    assert client.get(
        "/api/students", headers={"X-Tenant-ID": "school-b", "Authorization": f"Bearer {new_token}"}
    ).status_code == 403
    assert client.post(
        "/api/auth/logout", headers={**TENANT, "Authorization": f"Bearer {new_token}"}
    ).status_code == 200
    assert client.get("/api/students", headers={**TENANT, "Authorization": f"Bearer {new_token}"}).status_code == 401


def test_school_user_roles_and_password_change(client):
    created = client.post(
        "/api/users",
        json={
            "email": "teacher@school.test", "password": "teacher-pass-123",
            "fullName": "Teacher One", "role": "TEACHER",
        },
        headers=TENANT,
    )
    assert created.status_code == 201, created.text
    assert "password" not in created.json()
    assert len(client.get("/api/users", headers=TENANT).json()) == 2
    teacher = client.post(
        "/api/auth/login", json={"email": "teacher@school.test", "password": "teacher-pass-123"}, headers=TENANT
    ).json()
    teacher_headers = {**TENANT, "Authorization": f"Bearer {teacher['token']}"}
    assert client.get("/api/students", headers=teacher_headers).status_code == 200
    assert client.get("/api/fees/dues", headers=teacher_headers).status_code == 403
    contacts = client.get("/api/users", headers=teacher_headers)
    assert contacts.status_code == 200
    assert all(set(item) == {"id", "fullName", "role"} for item in contacts.json())
    assert client.post(
        "/api/users/change-password",
        json={"currentPassword": "teacher-pass-123", "newPassword": "new-teacher-pass-123"},
        headers=teacher_headers,
    ).status_code == 200
    assert client.post(
        "/api/auth/login", json={"email": "teacher@school.test", "password": "teacher-pass-123"}, headers=TENANT
    ).status_code == 401
    assert client.post(
        "/api/auth/login", json={"email": "teacher@school.test", "password": "new-teacher-pass-123"}, headers=TENANT
    ).status_code == 200
    assert client.delete(f"/api/users/{created.json()['id']}", headers=TENANT).status_code == 204
    assert client.post(
        "/api/auth/login", json={"email": "teacher@school.test", "password": "new-teacher-pass-123"}, headers=TENANT
    ).status_code == 401


def test_legacy_bcrypt_password_verifies_for_import():
    legacy = bcrypt.hashpw(b"legacy-password", bcrypt.gensalt()).decode()
    assert verify_password("legacy-password", legacy)
    assert not verify_password("wrong", legacy)
    assert verify_password("fresh-password", password_hash("fresh-password"))


def test_platform_login_and_school_validation(client):
    generator = app.dependency_overrides[get_session]()
    session = next(generator)
    try:
        with session.begin():
            session.add(User(
                scope="platform", tenant_id=None, email="root@platform.test",
                password_hash=password_hash("platform-pass-123"), full_name="Root",
                phone="", role="SUPER_ADMIN", linked_entity_id=None,
                extra_permissions=[], active=True, created_at=datetime.now(timezone.utc),
            ))
    finally:
        generator.close()
    login = client.post(
        "/platform/auth/login", json={"email": "root@platform.test", "password": "platform-pass-123"}
    )
    assert login.status_code == 200, login.text
    headers = {"Authorization": f"Bearer {login.json()['token']}"}
    assert client.get("/platform/schools", headers=TENANT).status_code == 403
    created = client.post(
        "/platform/schools",
        json={"tenantId": "school-c", "name": "School C", "city": "Delhi", "board": "CBSE"},
        headers=headers,
    )
    assert created.status_code == 201, created.text
    assert client.get("/platform/schools/school-c/validate").json() == {
        "valid": True, "name": "School C", "city": "Delhi", "board": "CBSE"
    }
    assert client.put("/platform/schools/school-c/status", json={"active": False}, headers=headers).status_code == 200
    assert client.get("/platform/schools/school-c/validate").json() == {"valid": False}
