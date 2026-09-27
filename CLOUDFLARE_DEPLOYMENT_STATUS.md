# School Cloudflare deployment status

Updated 27 September 2026. Confirmed website target: schools.katixo.com. The API hostname schools-api.katixo.com is a proposal, not configured DNS.

## Current deployment and local development status

- School staging resources now exist: D1 `school-staging-d1` (`e27122b3-e2ba-474f-b7b3-dc7cddd39a89`), Worker `school-api-staging` (deployed version `b8c61acb-0579-4ec7-bc80-1226b22f8cd8`), and Pages `school-staging` at `https://school-staging.pages.dev`. Existing Katixo/Milterra resources were not changed. No `schools.katixo.com` DNS record or custom domain has been attached.
- Wrangler is authenticated through OAuth for Pages, Workers, and D1 but lacks zone/Workers Routes scopes. The separate `Workers Scripts` API token has account permissions but lacks `katixo.com` Zone DNS Edit and Workers Routes Edit; adding those permissions is pending explicit action-time approval.
- Both migrations applied to local and remote staging D1 (9 + 115 SQL commands). Live `/health/ready` returned HTTP 200 for the 0002 schema and all 44 school tables. Local auth/schema tests passed 11/11 and local Worker runtime tests passed 10/10. The updated Worker bundled 223 Python modules; live CORS preflight from the staging Pages origin returned HTTP 200, and unauthenticated `/api/auth/me` returned HTTP 401.
- A Flutter web staging preview was built against the staging Worker and deployed to Pages. The preview shows a visible demo-content notice and sends `X-Robots-Tag: noindex, nofollow`. It is not a functional school deployment: the Worker still returns HTTP 404 for Flutter's `/api/site-content`, and most of the 170 FastAPI route methods are not ported.
- Positive authentication, tenant A/B isolation, refresh/logout, inactive account/school behavior, and private bootstrap now pass local unit tests; no real staging account or end-to-end browser sign-in has been verified. `build_vendor.py` rebuilt 222 Python modules from the lockfile in an isolated temp directory. Password-hashing CPU and legacy BCrypt on the Worker runtime remain unverified. The Worker is **not production ready**.
- The proposed public credential-seeding test endpoint was rejected by automatic approval review and was not added. No test or real accounts were created through this work.

## Verified Architecture & Baseline Findings

- Active checkout: `C:\dileepkm\Learning\School-project`, remote `DileepJexpert/school-project-ui`.
- The FastAPI backend and route contract matrix were checkpointed in local commit `818d9c4`; other tracked and untracked changes were preserved. No git resets or cleans were executed.
- Cloudflare dashboard confirms `katixo.com` is Active on the Free plan. Existing Katixo and Milterra resources remain untouched; the school staging resources above are separate, and no DNS cutover has been made.
- The existing school backend is FastAPI with SQLAlchemy, psycopg/PostgreSQL, and Alembic (170 endpoint methods across 26 router modules, 44 database tables).
- The Flutter JavaScript release build passed (`build/web` generated) targeting `https://school-api.katixo.com/api` (hostname not yet provisioned in DNS).

---

## Phase 0: Baseline & Source Checkpoint (Complete)

- **Source Preservation:** All tracked and untracked changes (`backend/`, `test/`, and modified working tree files) were preserved intact.
- **Flutter Test Baseline:** `flutter test` passed (3/3 tests passed in `test/academic_year_promotion_test.dart`).
- **Flutter Web Build:** `flutter build web --release --dart-define=API_BASE_URL=https://school-api.katixo.com/api` succeeded.
- **Backend Test Baseline:** `python -m pytest -q` passed (47/47 tests passed in 43.30s).
- **Route Audit:** `python -m scripts.audit_flutter_routes` verified 135 Flutter Dio client calls against FastAPI routes with 0 missing.
- **Authoritative Contract Matrix:**
  - Upgraded `backend/scripts/generate_contract_matrix.py` with genuine Python AST analysis (`ast.parse`) and deep OpenAPI schema resolution.
  - Traced helper and dependency exceptions:
    - `/api/auth/login` and `/platform/auth/login`: cataloged HTTP `401` (invalid credentials) and `403` (inactive school/account) raised inside `app.auth.authenticate`, along with required `X-Tenant-ID` (`400`) and request body validation (`422`).
    - Gated endpoints: cataloged `401` (unauthenticated) and `403` (forbidden) from `require_admin`, `get_current_active_user`, and role permission checks.
  - Deep Request & Response Schemas:
    - Resolved exact Pydantic model names, property fields, formats, and required constraints from OpenAPI `components.schemas`.
    - Documented **60 routes** with fully resolved Pydantic response models.
    - Explicitly cataloged **110 routes** returning untyped Python dictionaries under a dedicated `Unresolved Payload Contracts Inventory` in `ROUTE_CONTRACT_MATRIX.md` to guide typing in Phase 2/4.

---

## Phase 1: Python Worker & D1 Runtime Proof (Complete)

- **Supported Cloudflare ASGI Adapter:**
  - Integrated Cloudflare's supported `workers-runtime-sdk` (`workers.asgi.entrypoint(app)`) in `cloudflare/worker/src/entry.py`.
  - Removed handwritten ASGI bridge, eliminating migration and protocol divergence risk.

- **Reproducible Dependency Management & Lockfile:**
  - Aligned `cloudflare/worker/pyproject.toml` to declare exact pinned runtime dependencies:
    - `pydantic>=1.10.18,<2.0.0` (pure Python, eliminating Rust/C wheel incompatibility in Pyodide).
    - `workers-runtime-sdk>=1.9.0` (official Cloudflare ASGI adapter).
    - `fastapi>=0.115.0`, `starlette>=0.38.0`, `python-multipart>=0.0.9`, `anyio>=4.0.0`, `typing-extensions>=4.12.0`.
  - Generated `cloudflare/worker/uv.lock` via `uv lock`; verify its Git checkpoint status before relying on a fresh clone.
  - Verified clean dry-run bundle via `npx wrangler deploy --dry-run`: successfully packaged all 214 modules (2512.76 KiB) without manually patched global tooling.

- **Fail-Closed Probe Protection:**
  - Implemented `verify_probe_access` dependency reading request-scoped bindings (`request.scope["env"]`).
  - **Disabled by Default:** Rejects requests with HTTP 403 unless `ENABLE_TEST_PROBES == "true"` is explicitly bound.
  - **Production Guard:** Explicitly forbids execution with HTTP 403 when `ENVIRONMENT == "production"`, even if valid keys or enablement flags are passed.
  - **Secret Enforcement:** Requires configured `PROBE_SECRET` matching header `X-Probe-Key` via constant-time comparison (`hmac.compare_digest`).
  - Automated tests verified rejection across: production environment, disabled probes, missing secret, empty scope, and invalid probe keys.

- **Negative Schema Testing Against Actual `/health/ready`:**
  - Tested the real `/health/ready` endpoint against disposable D1 state modifications:
    - Table rename (`ALTER TABLE test_ledger RENAME TO temp_broken_ledger`) -> `/health/ready` returned `HTTP 503` with detail `Required application tables missing in D1: ['test_ledger']`.
    - Table restore -> `/health/ready` recovered to `HTTP 200` (`status: ready`).
    - Version corruption (`UPDATE schema_versions SET version = 'corrupted_0000'`) -> `/health/ready` returned `HTTP 503` with detail `Required schema version '0001_initial' not found in D1`.
    - Version restore -> `/health/ready` recovered to `HTTP 200` (`status: ready`).

- **PostgreSQL Row Locks Replacement with D1 Invariants:**
  1. *Overlapping Concurrent Withdrawals (`asyncio.gather`):*
     - Fired two competing 600-cent withdrawals simultaneously against an account with 1,000 cents using conditional update:
       `UPDATE test_accounts SET balance_cents = balance_cents - ?, version = version + 1 WHERE id = ? AND balance_cents >= ?`.
     - Exactly 1 task succeeded (`changes == 1`), exactly 1 was blocked (`changes == 0`), and balance was strictly maintained at 400 cents without double-spending.
  2. *Unique Constraint & Batch Rollback:*
     - Duplicate payment key threw `SQLITE_CONSTRAINT_UNIQUE`; D1 atomically rolled back the preceding balance deduction in the multi-statement batch (`balance_unaltered: true`).
  3. *Complete Refresh Token Rotation:*
     - **Atomic Rotation & Successor Issuance:** In a single D1 batch, revoked predecessor token `R1` (`WHERE refresh_hash = ? AND revoked_at IS NULL`) and inserted successor session `R2`. Both verified in D1.
     - **Successor Failure Rollback:** Attempted rotation `R2 -> R3` with a failing successor insert; D1 rolled back the predecessor revocation, leaving `R2` active and uncorrupted.
     - **Competing Overlapping Rotations:** Fired two concurrent rotation requests for `R2` via `asyncio.gather()`; exactly 1 succeeded in issuing a successor, and the competing request was blocked from creating a duplicate successor.

- **Multipart Form Parsing & Outbound HTTP:**
  - Verified binary file upload parsing (`UploadFile` + `Form`) inside the Worker via pure-Python multipart.
  - Verified outbound HTTP connectivity using Cloudflare's native `from workers import fetch`, avoiding sandbox socket timeouts.

- **Cryptographic Profiling & Hosting Status:**
  - Measured local wall-clock timing in Miniflare via `time.perf_counter()`:
    - Scrypt (n=16384, r=8, p=1): hash = ~200–240 ms wall-clock; verify = ~160–205 ms wall-clock.
    - Opaque token generation + SHA-256 hash: ~1.5–2.0 ms wall-clock.
  - **Hosting Tier Status:** Secure-auth CPU consumption and legacy BCrypt compatibility remain explicitly **pending** until profiled on an isolated staging Worker using isolate CPU telemetry (`isolate.cpu_time()`). No paid plan has been purchased, and no production cutover has been scheduled.

- **Automated Worker Test Suite:**
  - `cloudflare/worker/tests/test_worker_runtime.py` executed via pytest: **9/9 tests passed in 3.23s**.

---

## Progress tracker

| Phase | Status | Verified Evidence & Next Steps |
| --- | --- | --- |
| Source/domain audit and frontend build | Complete | 69 files, 42.95 MiB total, largest 6.89 MiB; Katixo/Milterra untouched |
| Plan and Antigravity handoff | Complete | Implementation plan and handoff docs established in repo |
| Baseline/source checkpoint (Phase 0) | Complete | Untracked backend preserved; 170-route contract matrix generated via AST (60 resolved, 110 unresolved contracts cataloged); tests: 3/3 Flutter, 47/47 pytest passed, 135 Dio routes audited |
| Python Worker/D1 runtime proof (Phase 1) | Complete | Official `workers.asgi.entrypoint` adapter; locked `uv.lock` & clean dry-run bundle; fail-closed probe guards; negative `/health/ready` testing (503/200); overlapping concurrency (`asyncio.gather`) & complete refresh rotation rollback; 9/9 worker tests passed |
| Schema/auth and tenant isolation (Phase 2) | In progress | 44-table D1 schema applied locally and remotely; 11 local auth/schema tests and 10 local Worker tests pass. Live account/bootstrap, browser sign-in, legacy BCrypt runtime, and CPU telemetry remain |
| Public content and staging frontend (Phase 3) | In progress | Separate staging Pages preview deployed with demo notice and no-index; CORS works, but `/api/site-content` is HTTP 404 and public content is not ported |
| School workflow parity (Phase 4) | Pending | Fees, attendance, results, rollover and remaining modules |
| Private media and jobs (Phase 5) | Pending | Storage approval and acceptance |
| Production cutover (Phase 6) | Pending | Full acceptance, backup/restore, cost measurements |
