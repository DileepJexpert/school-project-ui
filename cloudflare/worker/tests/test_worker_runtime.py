"""Automated tests against the local Cloudflare Python Worker and D1 database."""

import json
import os
import urllib.error
import urllib.request
import uuid
import pytest

BASE_URL = os.getenv("WORKER_TEST_BASE_URL", "http://127.0.0.1:8787")
PROBE_SECRET = "local-dev-probe-key"


def request_json(path: str, method: str = "GET", headers: dict | None = None, data: bytes | None = None):
    req_headers = headers.copy() if headers else {}
    req = urllib.request.Request(f"{BASE_URL}{path}", headers=req_headers, method=method, data=data)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode()
            return resp.status, json.loads(body) if body else {}
    except urllib.error.HTTPError as ex:
        err_body = ex.read().decode()
        try:
            parsed = json.loads(err_body)
        except Exception:
            parsed = {"raw": err_body}
        return ex.code, parsed


def post_multipart(path: str, fields: dict, files: dict, headers: dict | None = None):
    boundary = f"----Boundary{uuid.uuid4().hex}"
    body = bytearray()
    for name, value in fields.items():
        body.extend(f"--{boundary}\r\n".encode())
        body.extend(f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode())
        body.extend(f"{value}\r\n".encode())
    for name, (filename, file_bytes, content_type) in files.items():
        body.extend(f"--{boundary}\r\n".encode())
        body.extend(f'Content-Disposition: form-data; name="{name}"; filename="{filename}"\r\n'.encode())
        body.extend(f"Content-Type: {content_type}\r\n\r\n".encode())
        body.extend(file_bytes)
        body.extend(b"\r\n")
    body.extend(f"--{boundary}--\r\n".encode())

    req_headers = {"Content-Type": f"multipart/form-data; boundary={boundary}"}
    if headers:
        req_headers.update(headers)
    return request_json(path, method="POST", headers=req_headers, data=bytes(body))


def test_health_live():
    """Verify live probe endpoint returns 200 OK."""
    status, data = request_json("/health/live")
    assert status == 200
    assert data["status"] == "ok"


def test_health_ready_d1_schema():
    """Verify ready probe confirms D1 schema version and application tables existence."""
    status, data = request_json("/health/ready")
    assert status == 200
    assert data["status"] == "ready"
    assert data["version"] == "0002_school_schema"
    tables = set(data.get("tables_verified", []))
    required = {"schema_versions", "tenants", "users", "auth_sessions", "students", "payments", "school_site_content"}
    assert required.issubset(tables)
    assert len(tables) == 45


def test_probe_security_guard_fails_closed():
    """Verify probe endpoints fail closed: rejected without key or with invalid key."""
    # 1. Missing header -> 403 Forbidden
    status_no_key, data_no_key = request_json("/api/test/auth-crypto", method="POST")
    assert status_no_key == 403
    assert "detail" in data_no_key

    # 2. Invalid key -> 403 Forbidden
    status_bad_key, data_bad_key = request_json(
        "/api/test/auth-crypto", method="POST", headers={"X-Probe-Key": "invalid-probe-key"}
    )
    assert status_bad_key == 403
    assert "detail" in data_bad_key


def test_auth_contract_rejects_missing_or_invalid_context():
    status, school = request_json("/platform/schools/unknown-school/validate")
    assert status == 200 and school == {"valid": False}

    login_body = json.dumps({"email": "nobody@example.test", "password": "wrong"}).encode()
    headers = {"Content-Type": "application/json"}
    status, _ = request_json("/api/auth/login", "POST", headers, login_body)
    assert status == 400
    status, _ = request_json(
        "/api/auth/login", "POST", {**headers, "X-Tenant-ID": "unknown-school"}, login_body
    )
    assert status == 403

    status, _ = request_json(
        "/api/auth/refresh", "POST", headers,
        json.dumps({"refreshToken": "unknown-refresh-token"}).encode(),
    )
    assert status == 401
    status, _ = request_json(
        "/api/auth/logout", "POST", {"Authorization": "Bearer unknown-access-token"}
    )
    assert status == 401


def test_probe_guard_production_and_missing_config_rejection():
    """Verify verify_probe_access fails closed across production, disabled, and misconfigured states."""
    headers = {"X-Probe-Key": PROBE_SECRET}
    status, data = request_json("/api/test/probe-guard-simulation", method="POST", headers=headers)
    assert status == 200
    assert data["prod_rejected"] is True
    assert data["disabled_by_default_rejected"] is True
    assert data["no_secret_rejected"] is True
    assert data["empty_env_rejected"] is True
    assert data["all_passed"] is True



def test_actual_health_ready_failure_and_recovery():
    """Test actual /health/ready endpoint returning 503 on real schema/table corruption, then recovering to 200."""
    headers = {"X-Probe-Key": PROBE_SECRET}

    # 1. Break a real application table, then restore it.
    status, _ = request_json("/api/test/schema-state/break-table", method="POST", headers=headers)
    assert status == 200

    # Test the real /health/ready endpoint
    status_503_table, data_503_table = request_json("/health/ready")
    assert status_503_table == 503
    assert "Required application tables missing in D1" in data_503_table.get("detail", "")
    assert "school_site_content" in data_503_table.get("detail", "")

    # Restore table
    status, _ = request_json("/api/test/schema-state/restore-table", method="POST", headers=headers)
    assert status == 200

    # Verify recovery
    status_200_table, data_200_table = request_json("/health/ready")
    assert status_200_table == 200
    assert data_200_table.get("status") == "ready"

    # 2. Break version: corrupt schema_versions record
    status, _ = request_json("/api/test/schema-state/break-version", method="POST", headers=headers)
    assert status == 200

    # Test the real /health/ready endpoint
    status_503_ver, data_503_ver = request_json("/health/ready")
    assert status_503_ver == 503
    assert "Required schema version '0002_school_schema' not found in D1" in data_503_ver.get("detail", "")

    # Restore version
    status, _ = request_json("/api/test/schema-state/restore-version", method="POST", headers=headers)
    assert status == 200

    # Verify recovery
    status_200_ver, data_200_ver = request_json("/health/ready")
    assert status_200_ver == 200
    assert data_200_ver.get("status") == "ready"


def test_d1_concurrency_overlapping_and_complete_rotation():
    """Prove PostgreSQL row locks replacement with true overlapping concurrent requests and complete refresh rotation."""
    headers = {"X-Probe-Key": PROBE_SECRET}
    status, data = request_json("/api/test/d1-concurrency-locks", method="POST", headers=headers)
    assert status == 200

    # 1. Overlapping Concurrent Withdrawals (asyncio.gather)
    withdrawal = data["overlapping_withdrawals"]
    assert withdrawal["first_succeeded"] is True
    assert withdrawal["second_blocked"] is True
    assert withdrawal["balance_consistent_at_400"] is True

    # 2. Unique Constraint Rollback
    payment = data["unique_constraint_rollback"]
    assert payment["duplicate_error_caught"] is True
    assert "UNIQUE" in payment["error_detail"].upper()
    assert payment["balance_unaltered"] is True

    # 3. Complete Refresh Token Rotation (atomic rotation, successor failure rollback, competing rotation blocking)
    rotation = data["complete_refresh_rotation"]
    assert rotation["atomic_rotation_and_successor_created"] is True
    assert rotation["successor_insert_failure_rolled_back_revocation"] is True
    assert rotation["competing_rotations_prevented"] is True


def test_auth_crypto_measurements():
    """Profile CPU execution time and wall-clock duration objectively without hardcoded hosting assertions."""
    headers = {"X-Probe-Key": PROBE_SECRET}
    status, data = request_json("/api/test/auth-crypto", method="POST", headers=headers)
    assert status == 200
    assert data["has_hashlib_scrypt"] is True

    scrypt_info = data["scrypt"]
    assert scrypt_info["supported"] is True
    assert scrypt_info["verification_passed"] is True

    # Check timing metrics are present and non-negative
    assert "cold_hash_cpu_ms" in scrypt_info
    assert "cold_hash_wall_ms" in scrypt_info
    assert "warm_avg_cpu_ms" in scrypt_info
    assert "warm_avg_wall_ms" in scrypt_info
    assert "verify_cpu_ms" in scrypt_info
    assert "verify_wall_ms" in scrypt_info
    assert scrypt_info["cold_hash_wall_ms"] > 0
    assert scrypt_info["verify_wall_ms"] > 0

    # Opaque tokens
    assert data["opaque_tokens"]["supported"] is True
    assert data["opaque_tokens"]["access_token_len"] == 64
    assert data["opaque_tokens"]["access_hash_len"] == 64


def test_multipart_upload_parsing():
    """Verify multipart/form-data upload parsing in the Python Worker."""
    headers = {"X-Probe-Key": PROBE_SECRET}
    test_content = b"School student admission records mock binary content"
    status, data = post_multipart(
        "/api/test/multipart",
        fields={"title": "Admission Form"},
        files={"file": ("admission.pdf", test_content, "application/pdf")},
        headers=headers,
    )
    assert status == 200
    assert data["filename"] == "admission.pdf"
    assert data["content_type"] == "application/pdf"
    assert data["size_bytes"] == len(test_content)
    assert data["title"] == "Admission Form"


def test_outbound_http_fetch():
    """Verify outbound HTTP connectivity using native Cloudflare Worker fetch."""
    headers = {"X-Probe-Key": PROBE_SECRET}
    status, data = request_json("/api/test/outbound-http", method="POST", headers=headers)
    assert status == 200
    assert data["status_code"] == 200
    assert data["outbound_success"] is True
    assert data["duration_ms"] > 0
