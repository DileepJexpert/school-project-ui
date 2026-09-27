# FastAPI + PostgreSQL migration plan

## Goal and current evidence

Replace the Spring Boot API without changing the Flutter user journeys or losing
school records. Keep the existing `/api` and `/platform` routes and JSON shapes
until each workflow has passed contract and live acceptance tests. The new
backend should also resolve the fee-year and rollover gaps documented in
[SESSION_ROLLOVER_READINESS.md](SESSION_ROLLOVER_READINESS.md).

This checkout contains only the Flutter client. It does not contain the Java
backend, its database schema, migrations, API specification, data, or a live
test environment. Endpoint names below are **client-observed contracts**, not
proof of how the existing server behaves. Data-migration mapping, estimates,
and a cutover date require the backend source and a database inventory.

## Target architecture

- One modular FastAPI application, with routers for platform, auth, students,
  admissions, fees, attendance, results, portals, HR, transport, communication,
  media, and AI. Preserve `/api/...` plus `/platform/...` routing. Keep DTOs
  distinct from database models so API compatibility can be tested.
- PostgreSQL as the source of truth; SQLAlchemy 2 for persistence, Alembic for
  reviewed schema migrations, and Pydantic for request/response validation.
  Start with request-scoped synchronous database sessions and short explicit
  transactions. Use async only where it has a measured benefit, such as
  external AI or real-time I/O. [FastAPI application structure](https://fastapi.tiangolo.com/tutorial/bigger-applications/),
  [FastAPI sync/async guidance](https://fastapi.tiangolo.com/async/),
  [SQLAlchemy transaction scope](https://docs.sqlalchemy.org/en/20/orm/session_basics.html),
  [Alembic migration review](https://alembic.sqlalchemy.org/en/latest/autogenerate.html).
- One tenant model selected from the authenticated school context. Preserve
  the client's `X-Tenant-ID`, token, role, permission, and `linkedEntityId`
  expectations initially, but verify the header against the token on the
  server. Platform administration remains separate from school-scoped data.
- Store money as PostgreSQL `numeric`, dates as dates, and timestamps with a
  documented timezone policy. Add foreign keys, unique constraints, and
  idempotency keys around admissions, installments, receipts, and rollover.
  Store uploaded videos/documents in durable object storage, with metadata in
  PostgreSQL; do not rely on a web container's local disk.
- Development: Docker Compose for API + PostgreSQL and a disposable test DB.
  Production: a small always-on VPS or equivalent, TLS/reverse proxy, health
  checks, off-site backups, and a tested restore path. Choose exact hosting
  after measuring memory, upload volume, traffic, and backup needs.

## Contract inventory and migration order

| Wave | Client-observed areas | Acceptance focus |
| --- | --- | --- |
| 0 | `/platform/auth/login`, `/api/auth/login`, refresh/logout, tenant discovery, users | Existing login response shape, role strings, tenant identity, parent/student links, and one-refresh behavior. |
| 1 | `/api/students`, `/students/add`, `/students/enquiry`, search, update; `/feestructures` | New admission and enquiry conversion; stable IDs; matching year/class fee structure; old records still readable. |
| 2 | `/student-fee-profiles`, `/fees/collect`, dues/search, expenses, fee reports, receipts | Exact decimal totals, discounts, duplicate-submit protection, year-specific balances, and report reconciliation. |
| 3 | Academic-year rollover endpoint; attendance, results, publication, timetable | Atomic/idempotent rollover; old-year history; correct active rosters, marks, and class/date/year filters. |
| 4 | Student/parent portals, staff/leave/salary, transport, certificates, discipline, homework, notifications | Role-scoped reads and writes, linked student/child views, payroll and transport consistency. |
| 5 | Chat, video upload/stream, AI/config/usage, payment-gateway endpoints if online checkout is actually adopted | Message delivery, durable media, streaming authorization, usage accounting, provider callbacks. |

The full route ledger must be generated from **both** the Java controllers and
the Flutter `lib/services/` calls. Capture method, path, query/body, response,
status codes, auth role, tenant behavior, side effects, and empty/error cases.
Do not treat an unused client service as a delivered feature. The existing
Flutter review identifies a duplicated `/api` prefix in results publishing;
fix that client URI while preserving the intended server route.

## Database rules to establish before implementation

1. Model `academic_year` as a canonical entity, with one wire-format policy.
   The Flutter client currently uses both `YYYY-YYYY` and `YYYY-YY`; accept
   legacy forms only at the boundary and normalize internally.
2. Keep student identity separate from year-specific enrollment. Enrollment
   records hold class, section, roll number, status, and academic year, so
   promotion does not overwrite prior-year history.
3. Version fee structures by tenant, class, and academic year. Link each
   student fee profile and installment to an enrollment/year. Payments and
   receipts reference exact installments and a tenant, remain auditable, and
   cannot be counted twice. Decide and document how arrears carry forward.
4. Use database uniqueness and transaction boundaries for admission numbers,
   one enrollment per student/year, fee-profile creation, payment references,
   and rollover jobs. A rollover request must be safe to repeat and must
   report what it changed. [PostgreSQL constraints](https://www.postgresql.org/docs/18/ddl-constraints.html),
   [SQLAlchemy transactions](https://docs.sqlalchemy.org/en/20/orm/session_transaction.html).
5. Define tenant isolation and role permissions in server code and test them
   on every school-scoped route. Do not assume the Flutter menu guard enforces
   authorization.

## Data migration and cutover

1. Inventory the source database engine/version, tables, row counts, keys,
   constraints, stored files, existing password hashes, tenant layout, and
   current backup/restore process. Obtain a sanitized copy for repeatable
   rehearsal. Preserve original IDs wherever possible.
2. Create versioned Alembic schema migrations and repeatable, read-only-source
   import scripts. Map legacy fields explicitly; record rejected rows instead
   of silently defaulting fee amounts, years, or student status.
3. Rehearse the import into a fresh PostgreSQL database. Reconcile counts by
   tenant and table, admission IDs, active enrollments, fee structures,
   installment dues, paid totals, discounts, receipts, attendance, and marks.
   Test a restore from backup before any production switch.
4. Run the new API against the imported staging data. Compare representative
   old/new JSON responses and exercise the Flutter screens for every wave.
5. For final cutover, announce a short write-free maintenance window, take a
   source snapshot, rerun the import, reconcile, and switch the frontend API
   URL/reverse proxy. Keep the old API and database read-only afterward. Do
   not promise a simple rollback after the new API accepts writes; that needs
   a tested reverse-data plan or a restore to a known point.

PostgreSQL documents several backup methods; select the recovery point and
restore time the school needs, automate off-site backups accordingly, and
verify restores regularly. [PostgreSQL backup and restore](https://www.postgresql.org/docs/18/backup.html).

## Verification and release gates

- Contract tests for every client-used route, including query strings,
  response field names, status codes, empty arrays, and error bodies.
- PostgreSQL integration tests for admission + fee-profile creation, fee
  collection with retries, concurrent duplicate payments, discounts,
  graduation, and interrupted/repeated rollover. Inject failures mid-operation
  and confirm rollback or resumable state. Use a real PostgreSQL test database,
  not SQLite, for transaction behavior.
- Tenant/role matrix tests for admin, teacher, accountant, transport manager,
  student, parent, and platform admin. Test direct API calls as well as menus.
- Flutter smoke tests with staging API for each role and the year transition;
  compare old and new reports/totals before cutover.
- Deployment gate: migrations applied cleanly, backup restore proven, health
  checks and error logs visible, and a written rollback boundary.

## First implementation slice

After the Java backend and database snapshot are available, start with a
separate `backend/` FastAPI skeleton, PostgreSQL/Alembic setup, a route ledger,
and contract fixtures. Then implement tenant/auth and **one vertical
admission-to-fee-profile flow** in staging: create enquiry, convert/admit,
create year-specific fee profile, and read it back through the unchanged
Flutter API. Do not route production users to the new backend until that flow
and its data import reconcile.

## Inputs needed before estimates or a production switch

- Java backend repository, schema/migrations, and current database engine.
- Sanitized database snapshot or sample dataset and information about stored
  files/videos; never place real student/fee data in this Git repository.
- Which workflows are actually used today, especially online payments, chat,
  AI, and video; target number of schools/users and expected upload volume.
- School policy for outstanding fees across years, rollover timing, desired
  downtime, and acceptable backup recovery point/restore time.
