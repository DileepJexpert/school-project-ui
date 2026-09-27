# School management: Cloudflare implementation plan

Prepared 26 September 2026; target updated 27 September 2026 to schools.katixo.com. This plan describes the migration; it is not evidence of a working deployment. See CLOUDFLARE_DEPLOYMENT_STATUS.md for verified results.

## Outcome and boundaries

Deploy the existing school application with a Flutter Pages frontend, a separate Python/FastAPI Worker and a separate D1 database, while preserving the existing /api and /platform contracts and school/role isolation. Aim to fit the account's free allowance, but measure real CPU, database and media usage before claiming zero-cost operation. Do not rewrite the frontend or switch backend language as part of this plan.

Do not change existing katixo.com, Milterra Pages/Worker/D1, or other application resources. Do not expose real student data, accept real fee entries, activate paid subscriptions or enable untested features during migration. No new school resources or DNS have been created yet. The current work is a local source checkpoint and handoff; a public cutover must follow completed acceptance.

## Source baseline and preservation

The active source is C:/dileepkm/Learning/School-project; Git origin is DileepJexpert/school-project-ui. The older OneDrive path is not the active checkout used for this audit.

IMPORTANT: the entire FastAPI backend/ directory and several Flutter/test files are currently untracked, while many other source files have uncommitted edits. These are existing work, not disposable files. The narrow Cloudflare checkpoint excludes the backend and unrelated Flutter work. A fresh GitHub clone will NOT contain the complete Python implementation described here. Antigravity must use this local checkout first, inspect changes, and coordinate a reviewed source checkpoint before working elsewhere. Never git clean, reset --hard, overwrite the checkout, or blindly stage all files; backend/data, virtual environments, credentials and generated artifacts must not be published.

Current evidence:

- backend/app/db.py uses synchronous SQLAlchemy sessions and a psycopg PostgreSQL connection.
- backend/app/models.py defines 44 tables. The initial narrow count found 108 @router method decorators; additional named routers exist, so generate the authoritative route inventory from app.routes.
- backend/app/main.py registers /api and /platform workflows and requires an Alembic revision for /health/ready.
- backend/app/auth.py uses opaque random access/refresh tokens stored by hash, scrypt password hashes and legacy BCrypt verification. Do not incorrectly port this as an existing JWT system.
- PostgreSQL row locks appear in dependencies.py and auth, attendance, payments, results and rollover routers.
- Monetary values use Decimal/Numeric; videos use local filesystem bytes; optional AI calls a configured Ollama endpoint.
- Flutter initializes authentication and waits for SchoolData.load before runApp. Public content retains illustrative defaults when the backend is unavailable.
- Flutter JavaScript release build previously passed with API_BASE_URL=https://school-api.katixo.com/api: 69 files, about 42.95 MiB, largest file 6.89 MiB. This was the earlier proposed hostname; rebuild with the final API hostname before deployment. Optional Wasm checks report existing dart:html usage; JavaScript deployment does not require a Wasm migration.

## Proposed resources and routing

| Purpose | Proposed resource | Exposure |
| --- | --- | --- |
| Staging frontend | Separate school-staging Pages project | pages.dev initially; clearly identify staging |
| Staging API | Separate school-api-staging Python Worker | workers.dev initially; no real data |
| Staging database | Separate school-staging D1 | Worker binding only |
| Production frontend | Separate schools Pages project | schools.katixo.com after acceptance |
| Production API | Separate schools-api Worker | schools-api.katixo.com proposed; confirm before DNS |
| Production database | Separate school-production D1 | Separate binding and credentials |
| Video/documents | Separate private school object storage | Authorized downloads; only after storage/billing approval |

Names are proposals: inspect existing Cloudflare resources and DNS before creating anything. Preserve staging/production separation. Never bind school code to the existing katixo_admin or milterra-staging database. Configure exact CORS origins and allow Authorization, Content-Type, X-Tenant-ID and Idempotency-Key where required. Do not enable wildcard authenticated CORS or carry development localhost permissions into production automatically.

Use isolated cloudflare/worker/ source, tests, migrations and config examples. Retain the current backend/ as the reference implementation until parity and rollback gates pass. Keep real bindings in ignored local config and secrets in Cloudflare secret storage; commit placeholders only. Each deployment should identify its Git revision and schema version.

## Phase 0 - Establish a reproducible baseline

1. Read existing instructions and preserve all tracked/untracked source changes. Review a source checkpoint with the owner; the documentation commit is not that checkpoint.
2. Generate a method/path/role/tenant/request/response/status-code inventory from app.routes, Flutter services and backend tests. Include every named router. Record intentionally disabled modules explicitly.
3. Run the existing backend tests, Flutter tests and route audit, recording exact results and existing failures. backend/tests/conftest.py uses SQLite, so a pass does not establish PostgreSQL or D1 transaction semantics.
4. Review backend/scripts/postgres_acceptance.py before running it against a disposable PostgreSQL database. Do not run mutating acceptance scripts against production or a shared local database.
5. Produce a feature matrix with columns: current source, Cloudflare implementation, contract tests, actual Worker/D1 runtime evidence, browser acceptance, remaining limitations.

Exit: reproducible baseline, complete inventory and preserved source; no remote deployment required.

## Phase 1 - Prove Python/D1 compatibility before porting workflows

1. Scaffold an isolated Python Worker and pin dependencies. Import only compatible code, not the PostgreSQL engine or Uvicorn server.
2. Prove existing-shape /health/live and /health/ready, parameterized D1 read/write and required-schema checks in an actual local Worker runtime.
3. Prove password hashing/verification, opaque session generation, date/time/JSON/decimal serialization, multipart handling and bounded outbound HTTP. Measure CPU and memory, including password checks; native Python tests are insufficient.
4. Do not lower password hashing strength to meet free-plan CPU limits. If secure hashing or required packages cannot fit, document the measured blocker and obtain an architecture/cost decision before substituting an auth service or paid runtime.
5. Decide the D1 data layer explicitly. Do not assume psycopg, a synchronous SQLAlchemy Session, or existing PostgreSQL transaction scopes can be pointed at an asynchronous D1 binding. Prefer explicit async repositories with bound SQL and tested statement batches; any adapter must first prove equivalent behavior.
6. Establish migration version tracking in D1; readiness must fail if required schema/version is absent. Do not report ready merely because SELECT 1 works.

Exit: local bundle plus actual Worker/D1 runtime evidence. Compatibility failures stop dependent migration work; do not deploy a placeholder API as a completed backend.

## Phase 2 - Schema, authentication and school bootstrap

- Design reviewed D1 migrations from all 44 models, preserving uniqueness, foreign keys, indexes, tenant keys and active/disabled state. Use UTC timestamps and consistent date-only representations.
- Store money as integer minor units with explicit Decimal boundary conversion and rounding rules. Keep marks/percentages at their defined precision; do not blindly apply currency scaling to academic values.
- Port school lookup, platform/school login, refresh, logout, authorization, user permissions and active-school checks. Preserve the existing opaque token contract unless a deliberate reviewed change proves Flutter compatibility.
- Make refresh rotation/revocation atomic; parallel refresh requests must not mint multiple usable successor sessions. Add shared rate limiting that cannot be bypassed by moving between Worker instances.
- Every query must enforce tenant scope and ownership server-side. X-Tenant-ID is a selector, not proof of authorization. Verify platform-admin exceptions explicitly.
- Bootstrap an empty school and initial admin through a private operator process. Never ship default credentials or fixture students/payments. Confirm the real school name, tenant ID and content with the owner before publication.

Exit: authenticated school A/B isolation tests, inactive-user/school rejection, login/refresh/logout, roles and private bootstrap verified in actual D1.

## Phase 3 - Public content and first integrated frontend

- Port tenant-scoped school profile/site content and required master data first. Publish only real approved school details; do not promote sample achievements, testimonials, fee rates or contact details as factual content.
- Remove API waits from the initial public shell when practical. A versioned per-school public snapshot can support browsing; private student, fee and report records must never enter it.
- Preserve local session behavior and tenant selection. Show explicit retry/unavailable states; never fabricate successful login or saved records.
- Build a separate staging frontend with its real staging API URL and agreed PUBLIC_TENANT_ID. Check SPA deep links, startup, mobile layout, cache rules and CORS in the browser.

Exit: public content and authenticated navigation work end-to-end on separate staging resources.

## Phase 4 - Core school workflows and transaction guarantees

Port vertical slices in this order, updating the matrix after each:

1. Users, admissions/enquiries, student records and parent/student links.
2. Academic years, classes, subjects, fee setup and student fee profiles.
3. Fee collection, allocations, receipts, reversals, expenses and financial reports.
4. Attendance and timetables.
5. Exams, grading policy, marks publication, report cards and own-child/own-student portal reads.
6. Academic-year rollover, old-year dues and class/year closure.

For every former with_for_update or transaction block, write the concurrency invariant and replace it with a tested D1 atomic batch, conditional update, unique constraint or short bounded serialization mechanism. A per-statement success is not proof of atomic workflow success. Do not introduce another Cloudflare service without documenting its role and cost.

Required adversarial cases: duplicate payment/idempotency keys, same key with different payloads, two collectors paying the same due, rollback after a middle-statement failure, repeated reversal, parallel rollover, competing attendance edits, partial results publication, stale role/session and cross-school object IDs. Amounts, receipt numbers and audit history must remain consistent; uncertain writes must be reconciled rather than blindly replayed.

## Phase 5 - Remaining modules, media and jobs

Port staff/leave/payroll, transport, homework, discipline, certificates, notifications and private chat. Match the original authorization and payload contracts; a visible menu is not feature completion.

Move videos to private object storage with tenant/role-checked upload and range-enabled streaming/download, bounded size/type checks, metadata consistency and recoverable deletion. Never make student media buckets public. Obtain approval before activating billing-backed storage. Keep the module explicitly unavailable until accepted rather than storing uploads in Worker ephemeral files.

Keep Ollama AI disabled until an approved, reachable service and budget exist. Cloudflare Python support does not host the current Ollama model automatically. Document any remaining external service dependency.

Replace required persistent background loops with durable scheduled/bounded work, using idempotency, progress checkpoints and retry limits. Do not add scheduled requests solely to keep the Worker warm.

## Phase 6 - Staging and production acceptance

Deploy only school staging resources first, run all migrations, and use synthetic test identities with no real student PII. Verify real D1 contention, schema readiness, exact-origin CORS, unauthorized requests, backups/restores and the full role-based browser journeys. SQLite mocks and a green health endpoint are insufficient.

Measure request CPU (especially authentication/report generation), latency, D1 scanned/written rows, database size, storage transfer and expected traffic. Account allowances are shared with other apps; use current official pricing/limits when estimating costs. Do not promise that every school workload fits free limits just because idle usage is small.

Before production: confirm school identity/content, create separate production bindings/secrets, remove fixture data, verify private storage and log redaction, complete restore testing and record accepted/disabled modules. Only then attach schools.katixo.com and the approved API hostname and build the production frontend. Obtain required new-access or billing approvals at the relevant step.

Rollback must record previous frontend/Worker versions and compatible schema. Back up before schema changes. For existing data, use a reviewed write freeze or change capture and validate imports privately; do not assume the README's earlier 'no production data' statement is still current. Never restore an old fee ledger blindly after newer payments; reconcile the ledger before resuming writes.

## Completion evidence

- Every route in the inventory is implemented and verified or explicitly approved as disabled.
- Live school frontend/API URLs and deployed versions, migration versions and counts recorded.
- Tenant/role/auth, financial invariants and concurrent-write tests pass against actual staging D1.
- Staff, accountant, parent/student and admin browser journeys accepted.
- Private media and any scheduled work verified; external dependencies documented.
- Backup/restore and rollback rehearsed; runtime usage fits the selected approved plan.
- No unrelated application deployment changed and no secrets or personal records committed.

## References

- Cloudflare Python/FastAPI: https://developers.cloudflare.com/workers/languages/python/packages/fastapi/
- D1 bindings and database APIs: https://developers.cloudflare.com/d1/worker-api/
- D1 limits: https://developers.cloudflare.com/d1/platform/limits/
- Workers pricing: https://developers.cloudflare.com/workers/platform/pricing/
- Pages custom domains: https://developers.cloudflare.com/pages/configuration/custom-domains/

Verify current runtime support and limits during implementation; these links are reference material, not proof the current school code already supports the platform.
