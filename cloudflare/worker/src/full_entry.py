import os
import sys
from pathlib import Path

# Add vendored dependencies to Python path
vendor_path = Path(__file__).resolve().parent / "vendor"
if vendor_path.is_dir() and str(vendor_path) not in sys.path:
    sys.path.insert(0, str(vendor_path))

os.environ["PYDANTIC_PURE_PYTHON"] = "1"

import asyncio
import base64
from datetime import datetime, timezone
import hashlib
import hmac
import json
import secrets
import time

from fastapi import FastAPI, Request, HTTPException, Depends, Header, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from workers import WorkerEntrypoint, Response, fetch, asgi

EXPECTED_SCHEMA_VERSION = "0002_school_schema"
REQUIRED_TABLES = {
    "schema_versions", "tenants", "academic_years", "class_subjects",
    "contact_enquiries", "exam_configs", "expenses", "fee_structures",
    "rollover_runs", "school_classes", "school_site_content",
    "school_subjects", "staff", "students", "timetable_days",
    "transport_routes", "users", "ai_configs", "auth_sessions", "buses",
    "certificate_records", "chat_rooms", "class_year_closures",
    "enrollments", "fee_components", "homework", "incidents",
    "leave_requests", "notifications", "salary_records",
    "staff_attendance", "timetable_periods", "tutorial_videos",
    "ai_conversations", "attendance", "chat_messages",
    "coscholastic_assessments", "fee_profiles", "notification_reads",
    "result_records", "transport_assignments", "ai_usage",
    "fee_installments", "payments", "payment_allocations",
}

app = FastAPI(
    title="School Cloudflare Worker API",
    version="0.1.0",
    openapi_url=None,
    docs_url=None,
    redoc_url=None,
)

_routers_loaded = False



_loaded_routers = set()


def load_router_for_path(path: str):
    clean = path.lower().split("?", 1)[0]

    def _load_auth():
        if "auth" not in _loaded_routers:
            from school_auth import router as r
            app.include_router(r)
            _loaded_routers.add("auth")

    def _load_overview():
        if "overview" not in _loaded_routers:
            from school_overview import router as r, root_router as rr
            app.include_router(r)
            app.include_router(rr)
            _loaded_routers.add("overview")

    def _load_students():
        if "students" not in _loaded_routers:
            from school_students import router as r, root_router as rr
            app.include_router(r)
            app.include_router(rr)
            _loaded_routers.add("students")

    def _load_setup():
        if "setup" not in _loaded_routers:
            from school_setup import router as r
            app.include_router(r)
            _loaded_routers.add("setup")

    def _load_fee_structures():
        if "fee_structures" not in _loaded_routers:
            from school_fee_structures import router as r, root_router as rr
            app.include_router(r)
            app.include_router(rr)
            _loaded_routers.add("fee_structures")

    def _load_admissions():
        if "admissions" not in _loaded_routers:
            from school_admissions import router as r
            app.include_router(r)
            _loaded_routers.add("admissions")

    def _load_fees():
        if "fees" not in _loaded_routers:
            from school_fees import router as r
            app.include_router(r)
            _loaded_routers.add("fees")

    def _load_homework():
        if "homework" not in _loaded_routers:
            from school_homework import router as r
            app.include_router(r)
            _loaded_routers.add("homework")

    def _load_videos():
        if "videos" not in _loaded_routers:
            from school_videos import router as r
            app.include_router(r)
            _loaded_routers.add("videos")

    def _load_expenses():
        if "expenses" not in _loaded_routers:
            from school_expenses import router as r
            app.include_router(r)
            _loaded_routers.add("expenses")

    def _load_attendance():
        if "attendance" not in _loaded_routers:
            from school_attendance import router as r
            app.include_router(r)
            _loaded_routers.add("attendance")

    def _load_transport():
        if "transport" not in _loaded_routers:
            from school_transport import router as r, root_router as rr
            app.include_router(r)
            app.include_router(rr)
            _loaded_routers.add("transport")


    def _load_users():
        if "users" not in _loaded_routers:
            from school_users import router as r, root_router as rr
            app.include_router(r)
            app.include_router(rr)
            _loaded_routers.add("users")

    def _load_hr():
        if "hr" not in _loaded_routers:
            from school_hr import router as r, root_router as rr
            app.include_router(r)
            app.include_router(rr)
            _loaded_routers.add("hr")

    def _load_certificates():
        if "certificates" not in _loaded_routers:
            from school_certificates import router as r, root_router as rr
            app.include_router(r)
            app.include_router(rr)
            _loaded_routers.add("certificates")

    def _load_discipline():
        if "discipline" not in _loaded_routers:
            from school_discipline import router as r, root_router as rr
            app.include_router(r)
            app.include_router(rr)
            _loaded_routers.add("discipline")

    def _load_notifications():
        if "notifications" not in _loaded_routers:
            from school_notifications import router as r, root_router as rr
            app.include_router(r)
            app.include_router(rr)
            _loaded_routers.add("notifications")

    def _load_timetable():
        if "timetable" not in _loaded_routers:
            from school_timetable import router as r, root_router as rr
            app.include_router(r)
            app.include_router(rr)
            _loaded_routers.add("timetable")

    def _load_results():
        if "results" not in _loaded_routers:
            from school_results import router as r, root_router as rr
            app.include_router(r)
            app.include_router(rr)
            _loaded_routers.add("results")

    def _load_chat():
        if "chat" not in _loaded_routers:
            from school_chat import router as r, root_router as rr
            app.include_router(r)
            app.include_router(rr)
            _loaded_routers.add("chat")

    def _load_ai():
        if "ai" not in _loaded_routers:
            from school_ai import (
                config_router as cr,
                config_root_router as crr,
                chat_router as chr,
                chat_root_router as chrr,
            )
            app.include_router(cr)
            app.include_router(crr)
            app.include_router(chr)
            app.include_router(chrr)
            _loaded_routers.add("ai")

    def _load_whatsapp():
        if "whatsapp" not in _loaded_routers:
            from school_whatsapp import router as r, root_router as rr
            app.include_router(r)
            app.include_router(rr)
            _loaded_routers.add("whatsapp")

    def _load_portals():
        if "portals" not in _loaded_routers:
            from school_portals import (
                parent_router as pr,
                parent_root_router as prr,
                student_router as sr,
                student_root_router as srr,
            )
            app.include_router(pr)
            app.include_router(prr)
            app.include_router(sr)
            app.include_router(srr)
            _loaded_routers.add("portals")

    if "/auth" in clean:
        _load_auth()
    elif "/site-content" in clean or "/master-data" in clean or "/profile" in clean or "/overview" in clean:
        _load_overview()
    elif "/student-portal" in clean or "/parent" in clean:
        _load_portals()
    elif "/students" in clean:
        _load_students()
    elif "/staff" in clean or "/users" in clean:
        _load_users()
        _load_hr()
        _load_overview()
    elif "/salary" in clean or "/leave" in clean or "/staff-attendance" in clean or "/hr" in clean:
        _load_hr()
    elif "/certificates" in clean:
        _load_certificates()
    elif "/discipline" in clean:
        _load_discipline()
    elif "/notifications" in clean:
        _load_notifications()
    elif "/timetable" in clean:
        _load_timetable()
    elif "/results" in clean:
        _load_results()
    elif "/chat" in clean:
        _load_chat()
    elif "/ai" in clean or "/ai-config" in clean:
        _load_ai()
    elif "/whatsapp" in clean or "/whatsapp-config" in clean:
        _load_whatsapp()
    elif "/fee-structures" in clean or "/feestructures" in clean:
        _load_fee_structures()
    elif "/fees" in clean or "/student-fee-profiles" in clean:
        _load_fees()
    elif "/reports" in clean:
        _load_overview()
        _load_fees()
    elif "/admissions" in clean:
        _load_admissions()
    elif "/homework" in clean:
        _load_homework()
    elif "/videos" in clean:
        _load_videos()
    elif "/expenses" in clean:
        _load_expenses()
    elif "/attendance" in clean:
        _load_attendance()
    elif "/transport" in clean:
        _load_transport()
    elif "/setup" in clean:
        _load_setup()
    else:
        _load_auth()
        _load_overview()



def _load_routers():
    global _routers_loaded
    if _routers_loaded:
        return
    for route in [
        "/auth", "/overview", "/students", "/setup", "/fee-structures",
        "/admissions", "/fees", "/homework", "/videos", "/expenses",
        "/attendance", "/transport", "/users", "/staff", "/certificates",
        "/discipline", "/notifications", "/timetable", "/results",
        "/chat", "/ai", "/whatsapp", "/parent",
    ]:
        load_router_for_path(route)
    _routers_loaded = True


def to_py(val):
    if val is None:
        return None
    if hasattr(val, "to_py"):
        try:
            return val.to_py()
        except Exception:
            pass
    if isinstance(val, (int, float, str, bool, bytes)):
        return val
    try:
        return {k: to_py(val[k]) for k in val}
    except Exception:
        pass
    try:
        return [to_py(item) for item in val]
    except Exception:
        pass
    try:
        attrs = {}
        for attr in dir(val):
            if not attr.startswith("_"):
                v = getattr(val, attr)
                if not callable(v):
                    attrs[attr] = to_py(v)
        if attrs:
            return attrs
    except Exception:
        pass
    return str(val)


def get_binding(request: Request, key: str) -> str | None:
    """Retrieve environment binding from request scope env object, env dict, or os.environ."""
    env = request.scope.get("env")
    if env is not None:
        if hasattr(env, key):
            val = getattr(env, key)
            if val is not None:
                return str(val)
        elif isinstance(env, dict) and key in env:
            val = env[key]
            if val is not None:
                return str(val)
    return os.environ.get(key)


async def get_db(request: Request):
    env = request.scope.get("env")
    if env and hasattr(env, "DB"):
        return env.DB
    if env and isinstance(env, dict) and "DB" in env:
        return env["DB"]
    raise HTTPException(status_code=500, detail="D1 database binding 'DB' not accessible in request scope")


@app.get("/api/site-content")
async def get_site_content(
    x_tenant_id: str | None = Header(default=None, alias="X-Tenant-ID"),
    db=Depends(get_db),
):
    """Public school website content, scoped to an active tenant."""
    tenant_id = (x_tenant_id or "").strip().lower()
    if not tenant_id:
        raise HTTPException(status_code=400, detail="School code required")
    school = to_py(await db.prepare(
        "SELECT name, active FROM tenants WHERE id = ?"
    ).bind(tenant_id).first())
    if not isinstance(school, dict) or not school.get("active"):
        raise HTTPException(status_code=404, detail="School not found")
    row = to_py(await db.prepare(
        "SELECT content FROM school_site_content WHERE tenant_id = ?"
    ).bind(tenant_id).first())
    content = json.loads(row["content"]) if isinstance(row, dict) else {}
    if not isinstance(content, dict):
        content = {}
    return {"schoolName": school["name"], **content}


async def verify_probe_access(
    request: Request,
    x_probe_key: str | None = Header(default=None, alias="X-Probe-Key"),
):
    """
    Fail-closed probe access guard.
    - Disabled by default.
    - Explicitly forbidden when ENVIRONMENT is 'production'.
    - Requires ENABLE_TEST_PROBES == 'true' in Worker bindings.
    - Requires configured PROBE_SECRET matching X-Probe-Key.
    """
    env_name = (get_binding(request, "ENVIRONMENT") or "production").lower()
    if env_name == "production":
        raise HTTPException(
            status_code=403,
            detail="Test probe endpoints are disabled in production environment",
        )

    enable_probes = (get_binding(request, "ENABLE_TEST_PROBES") or "false").lower()
    if enable_probes != "true":
        raise HTTPException(
            status_code=403,
            detail="Test probe endpoints are disabled by default. Configure ENABLE_TEST_PROBES=true to enable.",
        )

    expected_secret = get_binding(request, "PROBE_SECRET")
    if not expected_secret:
        raise HTTPException(
            status_code=403,
            detail="Test probe secret is not configured in environment bindings",
        )

    if not x_probe_key or not hmac.compare_digest(x_probe_key, expected_secret):
        raise HTTPException(
            status_code=403,
            detail="Valid X-Probe-Key required for test endpoints",
        )


@app.post("/api/test/probe-guard-simulation", dependencies=[Depends(verify_probe_access)])
async def test_probe_guard_simulation():
    """Verify that verify_probe_access fails closed across production and misconfigured scopes."""
    results = {}

    def make_req(env_bindings: dict):
        scope = {
            "type": "http",
            "method": "POST",
            "path": "/api/test/probe-guard-simulation",
            "headers": [],
            "env": env_bindings,
        }
        return Request(scope)

    # 1. Production environment MUST reject even with correct key and ENABLE_TEST_PROBES=true
    req_prod = make_req({"ENVIRONMENT": "production", "ENABLE_TEST_PROBES": "true", "PROBE_SECRET": "secret123"})
    try:
        await verify_probe_access(req_prod, x_probe_key="secret123")
        results["prod_rejected"] = False
    except HTTPException as e:
        results["prod_rejected"] = (e.status_code == 403 and "production" in e.detail.lower())

    # 2. Probes disabled by default (ENABLE_TEST_PROBES absent or false)
    req_disabled = make_req({"ENVIRONMENT": "development", "PROBE_SECRET": "secret123"})
    try:
        await verify_probe_access(req_disabled, x_probe_key="secret123")
        results["disabled_by_default_rejected"] = False
    except HTTPException as e:
        results["disabled_by_default_rejected"] = (e.status_code == 403 and "disabled by default" in e.detail.lower())

    # 3. Missing probe secret in bindings
    req_no_secret = make_req({"ENVIRONMENT": "development", "ENABLE_TEST_PROBES": "true"})
    try:
        await verify_probe_access(req_no_secret, x_probe_key="secret123")
        results["no_secret_rejected"] = False
    except HTTPException as e:
        results["no_secret_rejected"] = (e.status_code == 403 and "secret is not configured" in e.detail.lower())

    # 4. Completely empty or absent env
    req_empty = make_req({})
    try:
        await verify_probe_access(req_empty, x_probe_key="secret123")
        results["empty_env_rejected"] = False
    except HTTPException as e:
        results["empty_env_rejected"] = (e.status_code == 403)

    results["all_passed"] = all(results.values())
    return results


# --- Production-shaped Health Endpoints ---

@app.get("/health/live")
async def health_live():
    return {"status": "ok"}


@app.get("/health/ready")
async def health_ready(request: Request, db=Depends(get_db)):
    try:
        # 1. Verify schema version
        stmt = db.prepare("SELECT version FROM schema_versions WHERE version = ?").bind(EXPECTED_SCHEMA_VERSION)
        version_val = await stmt.first("version")
        if not version_val:
            res = await stmt.first()
            res_py = to_py(res)
            version_val = res_py.get("version") if isinstance(res_py, dict) else str(res_py)

        if not version_val or version_val != EXPECTED_SCHEMA_VERSION:
            raise HTTPException(
                status_code=503,
                detail=f"Required schema version '{EXPECTED_SCHEMA_VERSION}' not found in D1",
            )

        # 2. Verify all required application tables exist
        table_stmt = db.prepare("SELECT name FROM sqlite_master WHERE type='table'")
        table_rows = await table_stmt.all()
        table_data = to_py(table_rows)
        results = table_data.get("results", []) if isinstance(table_data, dict) else table_data
        existing_tables = {r.get("name") for r in results if isinstance(r, dict)}

        missing_tables = REQUIRED_TABLES - existing_tables
        if missing_tables:
            raise HTTPException(
                status_code=503,
                detail=f"Required application tables missing in D1: {sorted(list(missing_tables))}",
            )

        return {"status": "ready", "version": version_val, "tables_verified": sorted(list(REQUIRED_TABLES))}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Database or schema unavailable: {str(e)}")


# --- Disposable Schema State Alteration (Protected by verify_probe_access) ---

@app.post("/api/test/schema-state/break-table", dependencies=[Depends(verify_probe_access)])
async def break_schema_table(db=Depends(get_db)):
    """Temporarily rename a required table to test readiness failure."""
    await db.prepare("ALTER TABLE school_site_content RENAME TO temp_broken_site_content").run()
    return {"broken": True, "table": "school_site_content"}


@app.post("/api/test/schema-state/restore-table", dependencies=[Depends(verify_probe_access)])
async def restore_schema_table(db=Depends(get_db)):
    """Restore the renamed table to test readiness recovery."""
    await db.prepare("ALTER TABLE temp_broken_site_content RENAME TO school_site_content").run()
    return {"restored": True, "table": "school_site_content"}


@app.post("/api/test/schema-state/break-version", dependencies=[Depends(verify_probe_access)])
async def break_schema_version(db=Depends(get_db)):
    """Temporarily corrupt schema version to test readiness failure."""
    await db.prepare("UPDATE schema_versions SET version = 'corrupted_0000' WHERE version = ?").bind(EXPECTED_SCHEMA_VERSION).run()
    return {"broken": True, "version": "corrupted_0000"}


@app.post("/api/test/schema-state/restore-version", dependencies=[Depends(verify_probe_access)])
async def restore_schema_version(db=Depends(get_db)):
    """Restore schema version to test readiness recovery."""
    await db.prepare("UPDATE schema_versions SET version = ? WHERE version = 'corrupted_0000'").bind(EXPECTED_SCHEMA_VERSION).run()
    return {"restored": True, "version": EXPECTED_SCHEMA_VERSION}


# --- Protected Verification Probes ---

@app.post("/api/test/auth-crypto", dependencies=[Depends(verify_probe_access)])
async def test_auth_crypto():
    """Profile CPU execution time and wall-clock duration for scrypt, bcrypt, and token hashing."""
    results = {
        "python_version": sys.version,
        "has_hashlib_scrypt": hasattr(hashlib, "scrypt"),
    }

    # 1. Scrypt benchmarking (CPU time vs Wall-clock time)
    if hasattr(hashlib, "scrypt"):
        password = "SecurePassword123!"
        salt = secrets.token_bytes(16)

        c_cpu_start = time.process_time()
        c_wall_start = time.perf_counter()
        digest = hashlib.scrypt(password.encode(), salt=salt, n=16384, r=8, p=1)
        c_cpu_ms = (time.process_time() - c_cpu_start) * 1000
        c_wall_ms = (time.perf_counter() - c_wall_start) * 1000

        warm_cpu_times = []
        warm_wall_times = []
        for _ in range(5):
            t0_cpu = time.process_time()
            t0_wall = time.perf_counter()
            hashlib.scrypt(password.encode(), salt=salt, n=16384, r=8, p=1)
            warm_cpu_times.append((time.process_time() - t0_cpu) * 1000)
            warm_wall_times.append((time.perf_counter() - t0_wall) * 1000)

        formatted = "$scrypt$16384$8$1$" + base64.urlsafe_b64encode(salt).decode() + "$" + base64.urlsafe_b64encode(digest).decode()
        _, alg, n, r, p, s, exp = formatted.split("$")
        v_cpu_start = time.process_time()
        v_wall_start = time.perf_counter()
        actual = hashlib.scrypt(password.encode(), salt=base64.urlsafe_b64decode(s), n=int(n), r=int(r), p=int(p))
        verified = hmac.compare_digest(actual, base64.urlsafe_b64decode(exp))
        v_cpu_ms = (time.process_time() - v_cpu_start) * 1000
        v_wall_ms = (time.perf_counter() - v_wall_start) * 1000

        results["scrypt"] = {
            "supported": True,
            "cold_hash_cpu_ms": round(c_cpu_ms, 2),
            "cold_hash_wall_ms": round(c_wall_ms, 2),
            "warm_avg_cpu_ms": round(sum(warm_cpu_times) / len(warm_cpu_times), 2),
            "warm_avg_wall_ms": round(sum(warm_wall_times) / len(warm_wall_times), 2),
            "verify_cpu_ms": round(v_cpu_ms, 2),
            "verify_wall_ms": round(v_wall_ms, 2),
            "verification_passed": verified,
        }
    else:
        results["scrypt"] = {"supported": False, "error": "hashlib.scrypt unavailable"}

    # 2. Bcrypt packaging check
    try:
        import bcrypt
        b_cpu_start = time.process_time()
        b_wall_start = time.perf_counter()
        b_hash = bcrypt.hashpw(b"SecurePassword123!", bcrypt.gensalt(rounds=12))
        b_verified = bcrypt.checkpw(b"SecurePassword123!", b_hash)
        results["bcrypt"] = {
            "supported": True,
            "hash_cpu_ms": round((time.process_time() - b_cpu_start) * 1000, 2),
            "hash_wall_ms": round((time.perf_counter() - b_wall_start) * 1000, 2),
            "verification_passed": b_verified,
        }
    except Exception as ex:
        results["bcrypt"] = {"supported": False, "error": f"{type(ex).__name__}: {str(ex)}"}

    # 3. Opaque Tokens
    t_start = time.process_time()
    access_token = secrets.token_urlsafe(48)
    refresh_token = secrets.token_urlsafe(48)
    access_hash = hashlib.sha256(access_token.encode()).hexdigest()
    t_cpu_ms = (time.process_time() - t_start) * 1000

    results["opaque_tokens"] = {
        "supported": True,
        "token_cpu_ms": round(t_cpu_ms, 4),
        "access_token_len": len(access_token),
        "access_hash_len": len(access_hash),
    }

    return results


@app.post("/api/test/d1-concurrency-locks", dependencies=[Depends(verify_probe_access)])
async def test_d1_concurrency_locks(db=Depends(get_db)):
    """Prove PostgreSQL row locks replacement with true overlapping concurrent requests and complete refresh rotation."""
    test_id = f"acc-{int(time.time() * 1000)}"

    # 1. Setup account with 1000 cents ($10.00)
    await db.prepare(
        "INSERT INTO test_accounts (id, balance_cents, version) VALUES (?, ?, ?)"
    ).bind(test_id, 1000, 1).run()

    # 2. True Overlapping Concurrent Withdrawals (asyncio.gather)
    # Launch two competing withdrawal tasks of 600 cents simultaneously against the same account record
    async def try_withdraw(amount: int):
        res = await db.prepare(
            "UPDATE test_accounts SET balance_cents = balance_cents - ?, version = version + 1 WHERE id = ? AND balance_cents >= ?"
        ).bind(amount, test_id, amount).run()
        meta = to_py(res).get("meta", {})
        return meta.get("changes", 0) == 1

    withdrawal_results = await asyncio.gather(try_withdraw(600), try_withdraw(600))
    succeeded_withdrawals = withdrawal_results.count(True)
    blocked_withdrawals = withdrawal_results.count(False)

    acc_row = to_py(await db.prepare("SELECT balance_cents, version FROM test_accounts WHERE id = ?").bind(test_id).first())
    final_balance = acc_row.get("balance_cents")

    # 3. Unique Constraint Rollback (duplicate payment idempotency)
    idemp_key = f"pay-{test_id}"
    await db.prepare(
        "INSERT INTO test_ledger (account_name, amount_cents, note) VALUES (?, ?, ?)"
    ).bind("Tuition", 100, idemp_key).run()

    duplicate_caught = False
    duplicate_error = ""
    try:
        await db.batch([
            db.prepare("UPDATE test_accounts SET balance_cents = balance_cents - 100 WHERE id = ?").bind(test_id),
            db.prepare("INSERT INTO test_ledger (account_name, amount_cents, note) VALUES (?, ?, ?)").bind("Tuition", 100, idemp_key),
        ])
    except Exception as ex:
        duplicate_caught = True
        duplicate_error = str(ex)

    acc_after = to_py(await db.prepare("SELECT balance_cents FROM test_accounts WHERE id = ?").bind(test_id).first())
    balance_unaltered = (acc_after.get("balance_cents") == 400)

    # 4. Complete Refresh Token Rotation
    user_id = f"usr-{test_id}"
    ref_1 = hashlib.sha256(f"ref-1-{test_id}".encode()).hexdigest()
    acc_1 = hashlib.sha256(f"acc-1-{test_id}".encode()).hexdigest()
    now_iso = datetime.now(timezone.utc).isoformat()

    await db.prepare(
        "INSERT INTO users (id, scope, email, password_hash, full_name, phone, role, "
        "extra_permissions, active, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    ).bind(user_id, "platform", f"{user_id}@test.com", "dummy_hash", "Test User", "", "STAFF", "[]", 1, now_iso).run()

    await db.prepare(
        "INSERT INTO auth_sessions (id, user_id, access_hash, refresh_hash, access_expires_at, "
        "refresh_expires_at) VALUES (?, ?, ?, ?, ?, ?)"
    ).bind(secrets.token_hex(16), user_id, acc_1, ref_1, now_iso, now_iso).run()

    # Step 4A: Atomic rotation + successor creation in single D1 batch
    ref_2 = hashlib.sha256(f"ref-2-{test_id}".encode()).hexdigest()
    acc_2 = hashlib.sha256(f"acc-2-{test_id}".encode()).hexdigest()
    rot_batch = await db.batch([
        db.prepare("UPDATE auth_sessions SET revoked_at = ? WHERE refresh_hash = ? AND revoked_at IS NULL").bind(now_iso, ref_1),
        db.prepare("INSERT INTO auth_sessions (id, user_id, access_hash, refresh_hash, access_expires_at, refresh_expires_at) VALUES (?, ?, ?, ?, ?, ?)").bind(secrets.token_hex(16), user_id, acc_2, ref_2, now_iso, now_iso),
    ])
    rot_batch_py = to_py(rot_batch)
    s1_revoked_meta = rot_batch_py[0].get("meta", {}) if len(rot_batch_py) > 0 else {}
    s1_revoked_ok = s1_revoked_meta.get("changes", 0) == 1

    s2_row = to_py(await db.prepare("SELECT id, revoked_at FROM auth_sessions WHERE refresh_hash = ?").bind(ref_2).first())
    s2_created = (s2_row is not None and s2_row.get("revoked_at") is None)

    # Step 4B: Successor insert failure atomically rolls back predecessor revocation
    ref_failed = hashlib.sha256(f"ref-fail-{test_id}".encode()).hexdigest()
    successor_fail_caught = False
    try:
        await db.batch([
            db.prepare("UPDATE auth_sessions SET revoked_at = ? WHERE refresh_hash = ? AND revoked_at IS NULL").bind(now_iso, ref_2),
            db.prepare("INSERT INTO non_existent_session_table (bad_col) VALUES (?)").bind("bad_val"),
        ])
    except Exception:
        successor_fail_caught = True

    # S2 must remain UNREVOKED because the batch rolled back
    s2_after_fail = to_py(await db.prepare("SELECT revoked_at FROM auth_sessions WHERE refresh_hash = ?").bind(ref_2).first())
    s2_preserved_active = (s2_after_fail is not None and s2_after_fail.get("revoked_at") is None)

    # Step 4C: Overlapping competing rotation requests (asyncio.gather).
    # The conditional INSERT prevents a loser from minting a usable successor.
    # Two competing clients present ref_2 simultaneously
    async def rotate_s2(token_name: str):
        new_ref = hashlib.sha256(f"{token_name}-{test_id}".encode()).hexdigest()
        new_acc = hashlib.sha256(f"{token_name}-acc-{test_id}".encode()).hexdigest()
        try:
            res = await db.batch([
                db.prepare(
                    "INSERT INTO auth_sessions (id, user_id, access_hash, refresh_hash, access_expires_at, refresh_expires_at) "
                    "SELECT ?, user_id, ?, ?, ?, ? FROM auth_sessions "
                    "WHERE refresh_hash = ? AND revoked_at IS NULL"
                ).bind(secrets.token_hex(16), new_acc, new_ref, now_iso, now_iso, ref_2),
                db.prepare("UPDATE auth_sessions SET revoked_at = ? WHERE refresh_hash = ? AND revoked_at IS NULL").bind(now_iso, ref_2),
            ])
            res_py = to_py(res)
            # Check whether a successor was actually issued.
            return res_py[0].get("meta", {}).get("changes", 0) == 1
        except Exception:
            return False

    competing_rot_results = await asyncio.gather(rotate_s2("clientA"), rotate_s2("clientB"))
    rot_succeeded_count = competing_rot_results.count(True)
    successors = to_py(await db.prepare(
        "SELECT COUNT(*) AS count FROM auth_sessions WHERE user_id = ? AND "
        "refresh_hash NOT IN (?, ?) AND revoked_at IS NULL"
    ).bind(user_id, ref_1, ref_2).first())
    usable_successor_count = successors.get("count", 0)

    return {
        "overlapping_withdrawals": {
            "first_succeeded": succeeded_withdrawals == 1,
            "second_blocked": blocked_withdrawals == 1,
            "balance_consistent_at_400": final_balance == 400,
        },
        "unique_constraint_rollback": {
            "duplicate_error_caught": duplicate_caught,
            "error_detail": duplicate_error,
            "balance_unaltered": balance_unaltered,
        },
        "complete_refresh_rotation": {
            "atomic_rotation_and_successor_created": s1_revoked_ok and s2_created,
            "successor_insert_failure_rolled_back_revocation": successor_fail_caught and s2_preserved_active,
            "competing_rotations_prevented": rot_succeeded_count == 1 and usable_successor_count == 1,
        },
    }


@app.post("/api/test/multipart", dependencies=[Depends(verify_probe_access)])
async def test_multipart(file: UploadFile = File(...), title: str = Form(...)):
    """Verify multipart/form-data upload parsing in the Python Worker."""
    content = await file.read()
    return {
        "filename": file.filename,
        "content_type": file.content_type,
        "size_bytes": len(content),
        "title": title,
    }


@app.post("/api/test/outbound-http", dependencies=[Depends(verify_probe_access)])
async def test_outbound_http():
    """Verify outbound HTTP connectivity using native Cloudflare Worker fetch."""
    t0 = time.perf_counter()
    resp = await fetch("https://cloudflare.com/cdn-cgi/trace")
    body = await resp.text()
    duration_ms = (time.perf_counter() - t0) * 1000

    has_trace = "colo=" in body or "fl=" in body or "ip=" in body
    return {
        "status_code": resp.status,
        "outbound_success": has_trace,
        "duration_ms": round(duration_ms, 2),
    }


# Connect FastAPI via official Cloudflare ASGI adapter
BaseDefault = asgi.entrypoint(app)


class Default(BaseDefault):
    async def on_fetch(self, request):
        if request.method == "OPTIONS":
            return Response(
                status=204,
                headers={
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
                    "Access-Control-Allow-Headers": "*",
                    "Access-Control-Max-Age": "86400",
                },
            )
        _load_routers()
        path = str(request.url).split("?", 1)[0]
        if "/api/expenses" in path:
            finance = getattr(self.env, "FINANCE", None)
            if finance is not None:
                return await finance.fetch(request)
        try:
            return await self.fetch(request)
        except Exception as exc:
            return Response(
                json.dumps({"detail": f"Internal server error: {exc}"}),
                status=500,
                headers={
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "*",
                    "Access-Control-Allow-Headers": "*",
                },
            )
