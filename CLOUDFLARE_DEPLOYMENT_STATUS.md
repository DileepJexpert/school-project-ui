# School Cloudflare deployment status

Updated 27 September 2026. Confirmed website target: schools.katixo.com. The API hostname schools-api.katixo.com is a proposal, not configured DNS.

## Current deployment and local development status

- No school Pages project, Worker, D1 database, custom hostname, or DNS cutover has been deployed. The only remote D1 databases listed were `katixo_admin` and `milterra-staging`; the only Pages projects listed were `katixo` and `milterra-staging`. Those resources were not changed.
- Wrangler is already authenticated through OAuth with Pages, Workers, and D1 write scopes. Cloudflare account credentials are **not** currently the blocking item. The existing OAuth token lacks zone/Worker-route scopes, so custom hostname setup may still require a permission refresh or dashboard action later.
- Phase 2 schema work began locally. `0002_school_schema.sql` now creates all 44 school model tables, indexes, foreign keys, and integer-scaled decimal columns. It refuses to replace nonempty 0001 probe identity tables. Both migrations applied to an isolated local D1 database through Wrangler (9 + 115 SQL commands).
- `/health/ready` now requires the 0002 version and all 44 school tables. The Worker bundles in a dry run (215 modules), and the local schema/Worker suites passed 13 tests. With default Wrangler settings, readiness returned HTTP 200 and test probes returned HTTP 403.
- School-code validation and school/platform login, refresh, and logout routes were added to the Worker. Only their missing/invalid-context behavior has been exercised; successful authentication, tenant A/B isolation, active-school rejection, CPU cost, and a private bootstrap process remain unverified. The Worker is therefore **not ready for a school deployment**.
- The proposed public credential-seeding test endpoint was rejected by automatic approval review and was not added. No test or real accounts were created through this work.

## Verified Architecture & Baseline Findings

- Active checkout: `C:\dileepkm\Learning\School-project`, remote `DileepJexpert/school-project-ui`.
- Existing tracked and untracked changes (`backend/`, `test/`, and working tree files) were strictly preserved; no git resets or cleans were executed.
- Cloudflare dashboard confirms `katixo.com` is Active on the Free plan. Production and staging environments for Katixo and Milterra remain completely untouched; no DNS records or cutovers have been created.
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
| Schema/auth and tenant isolation (Phase 2) | In progress locally | 44-table D1 schema applied and checked locally; auth routes added but positive login/refresh, private bootstrap, staging CPU telemetry, and A/B isolation remain |
| Public content and staging frontend (Phase 3) | Pending | Browser integration on separate staging resources |
| School workflow parity (Phase 4) | Pending | Fees, attendance, results, rollover and remaining modules |
| Private media and jobs (Phase 5) | Pending | Storage approval and acceptance |
| Production cutover (Phase 6) | Pending | Full acceptance, backup/restore, cost measurements |
