# School FastAPI backend

This is the separate FastAPI/PostgreSQL backend for the school application. It
is still in **testing**. Flutter now targets these FastAPI routes; the Java
backend remains unchanged. The
school has no existing production data to import, so first-run setup starts
with an empty ledger.

## Implemented workflows

- School and platform login, refresh/logout, role and tenant-bound API access,
  school onboarding and user management. Password verification also accepts
  legacy BCrypt hashes, although no legacy data needs importing now.
- Admissions and enquiries; April–March fee structures, yearly fee profiles,
  exact payment allocation and receipts, audited payment reversals; expenses
  and fee/school reports.
- Idempotent class/year rollover, old-year dues retained in their original
  year, class/year closure, dated attendance, results, exam configuration,
  report cards and timetables. Publishing results requires a school-specific
  grading policy with grade bands, pass mark and exam order for that year,
  plus the class's complete subject roster.
- Student and parent portal reads; staff, leave, payroll, staff attendance;
  buses, routes and student assignments; homework, discipline, certificates,
  targeted notifications and private chat.
- Video upload/stream using a persistent volume, and optional Ollama AI
  homework chat with school settings and student usage limits. AI is disabled
  until a school admin enables it and supplies a reachable Ollama server.

The existing `/api` and `/platform` paths and camel-case JSON shapes are used.
The Flutter app defaults to `http://localhost:8000/api`; its Settings API URL
control can switch servers at runtime. Set `CORS_ORIGINS` to the Flutter web
origin in production (for example `https://school.example.com`). Localhost
browser origins are allowed for development.
For a public site serving one school, build Flutter with
`--dart-define=API_BASE_URL=https://api.example.com/api` and
`--dart-define=PUBLIC_TENANT_ID=school-a`; login can still choose a tenant.
`GET /api/master-data` reports the configured years, classes, subjects and
which classes still need fee structures and subject assignments for a selected
academic year. It also shows whether grading policy and exam weights are
complete. The
unused online payment-gateway service was removed from Flutter; in-person fee
collection is implemented. The public results page requires school staff sign-in
and returns only published marks. Students and parents view their own results
through their portal routes.

## First run

From `backend/`, install and start a local PostgreSQL database:

```powershell
py -3.13 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -e '.[test]'
docker compose up -d --build
```

Docker Compose's password is for local testing only. Its one-shot `migrate`
service upgrades PostgreSQL before starting the API. `/health/ready` returns
503 until the database is at the required migration revision.

The local Compose project is named `school-project-local`. It binds FastAPI to
`http://127.0.0.1:8000` and PostgreSQL to `127.0.0.1:5433`, avoiding other
projects that use host port 5432. From the repository root, run Flutter web with:

```powershell
flutter run -d chrome --web-port 8081 --dart-define=API_BASE_URL=http://localhost:8000/api --dart-define=PUBLIC_TENANT_ID=local-school
```

Stop only this project's backend with `docker compose down` from `backend/`.
The named PostgreSQL and video volumes remain for the next start.

When running the API outside Compose, set `DATABASE_URL`, run
`python -m alembic upgrade head`, then:

```powershell
python -m uvicorn app.main:app --reload --port 8000
```

For deployment, `compose.prod.yaml` requires externally supplied PostgreSQL
`DATABASE_URL` and `CORS_ORIGINS`, runs migrations before the API, and stores video bytes in a
persistent volume. Set the real connection URL in the host environment and
run `docker compose -f compose.prod.yaml up -d --build`. Do not deploy the
local `compose.yaml` password. Back up PostgreSQL and the video volume
together, and complete a restore drill before accepting real records.
The Flutter Settings screen no longer offers a misleading ZIP download;
database and video backups are an operator procedure.

Bootstrap a school and its first admin account:

```powershell
python -m app.seed school-a 'Example School' --city 'Delhi' --board 'CBSE' --year 2026-2027 --admin-email admin@example.test
```

The command prompts for the initial password; it does not store a default
password in the repository. It is safe to rerun: the existing admin password,
student records and payments are preserved. The seed creates the April–March
academic year, the Flutter client's 27 class/section labels (Nursery, LKG,
UKG, then Class 1–12 A/B), and 13 common subjects. It creates no students,
staff, payments or fake fee amounts.

Before admitting students, add the real fee rates for each class in the year.
Before publishing results, configure the school's actual subjects per class,
pass mark, grade bands and exam order. Copy `master_data.example.json`, fill
its `feeStructures` and `classSubjects` arrays and `gradingPolicy` object,
and list any subjects absent from the initial catalogue in `additionalSubjects`,
then replace the empty `siteContent` fields with real school text and lists,
then run:

```powershell
python -m app.seed school-a 'Example School' --year 2026-2027 --fees-file .\fees.school.json
```

Each item has the same shape as `POST /api/feestructures`:

```json
{
  "className": "Class 5 - A",
  "academicYear": "2026-2027",
  "feeComponents": [
    {"feeName": "Tuition", "amount": 100.00, "frequency": "MONTHLY"}
  ]
}
```

The amount above is illustrative; replace it with the school's actual rate.
Each `classSubjects` entry lists the subjects that every enrolled student
must have marks for before that class and exam can be published:

```json
{
  "className": "Class 5 - A",
  "academicYear": "2026-2027",
  "subjects": ["English", "Mathematics", "Science"]
}
```

The subject names must exist in the school's subject catalogue. For example,
set `"additionalSubjects": ["Economics", "Physics"]` before assigning either
subject to a class. An admin can add a subject with `PUT /api/master-data/subjects`
(`{"name":"Economics"}`), inspect the catalogue with `GET /api/master-data/subjects`,
set class assignments with `PUT /api/master-data/class-subjects`, and read them with
`GET /api/master-data/class-subjects?className=Class%205%20-%20A&academicYear=2026-2027`.
Published marks lock the class subject roster.

The optional `gradingPolicy` object has this shape; its values below are also
illustrative and must be approved by the school:

```json
{
  "academicYear": "2026-2027",
  "passPercentage": 40,
  "examOrder": ["TERM1", "TERM2"],
  "bands": [
    {"minPercentage": 40, "grade": "P", "gradePoint": 4},
    {"minPercentage": 0, "grade": "F", "gradePoint": 0}
  ]
}
```

An admin can also set the policy with `PUT /api/results/grading-policy` and
read it with `GET /api/results/grading-policy?year=2026-2027`. Published
results lock that year's policy and exam configuration. Before publication,
create active exam configurations for every `examOrder` entry with weightages
that total 100%. Draft marks return an empty grade until a policy is configured.

The seed rejects a changed existing structure rather than silently changing
historical obligations, and rejects a changed seeded grading policy. The fee
setup API can also create or edit structures
before they are used by an admission. A missing class/year structure blocks
admission for that class until it is configured. Creating the first fee
structure for a later academic year also registers that April–March year in
the master-data catalogue.

The public Home, About, Academics, Admissions, Events, Gallery and Transport
pages load `siteContent` through `GET /api/site-content` at app startup. A
school admin may replace it with `PUT /api/site-content` using
`{"content": { ... }}`. `PUT /api/school/profile` changes the school name in
the admin Settings page. The seed never invents a school history, contact
details, fee table or testimonials. If content has not been configured, those
sections are empty. The contact form posts to `POST /api/contact/enquiry` and
admins can review submissions at `GET /api/contact/enquiries`.

The API requires `X-Tenant-ID: school-a` and `Authorization: Bearer <token>`
on school routes. Login is `POST /api/auth/login` with email and password.
Platform login is separate at `POST /platform/auth/login`; create an initial
platform administrator only if needed with `python -m app.seed_platform`.

To correct an erroneous payment, post a specific reason to
`POST /api/fees/payments/{id}/void`. The original receipt remains readable,
and `GET /api/fees/payments?status=VOIDED` lists reversals. The student's fee
balance is restored. Fee and school summaries show currently posted receipts;
the ledger endpoint retains both posted and voided receipts for audit. Each
receipt preserves the student name and collector identity from collection time.

## Tests and reconciliation

```powershell
python -m pytest tests -q -p no:cacheprovider
python -m scripts.audit_flutter_routes
python -m app.reconcile school-a
```

For PostgreSQL acceptance, create a separate empty database and run the
operator check. It refuses non-PostgreSQL URLs, database names without the
`_test` suffix, and databases that already contain tables:

```powershell
docker compose exec db createdb -U school school_test
$env:POSTGRES_TEST_URL='postgresql+psycopg://school:local-only@localhost:5433/school_test'
python -m scripts.postgres_acceptance
```

That check applies every migration and exercises login, admission, concurrent
collection of the same installment, reversal, readiness and reconciliation.
It leaves the test database intact for inspection.

The route audit checks Flutter Dio method/path existence; it does not prove
request/response shape or live browser behavior. The AI settings form now offers
only the implemented Ollama provider; staff account management uses `/api/users`.
The public pages read `siteContent` and display only configured school claims.
Image fields in `siteContent` accept a full HTTP(S) URL or a bundled Flutter
asset path; the backend does not host public website photos.
The standard Flutter web build and focused academic-year tests pass. WebAssembly
builds are not supported by the HTML file picker and CSV export code.
The routine backend tests use SQLite for HTTP and transaction checks (47 passed).
All 23 migrations, readiness, concurrent collection of one installment,
reversal, reconciliation, and `alembic check` also passed against an isolated
PostgreSQL 17 database. Live browser acceptance of each school role and a
backup/restore drill remain before use with real school records.
`app.reconcile` is read-only and checks fee allocations, enrollments, payroll,
transport capacity, communication links, AI usage and video files.

Actual fee rates and grading policy are school inputs, never generated by the
seed. Online payments and cloud AI providers
are not implemented because the client does not currently use checkout and no
provider configuration or credentials have been supplied. Video files live in
`VIDEO_STORAGE_DIR` (`school_video` in Compose); back up that volume together
with PostgreSQL. The Flutter web video screen selects MP4/WebM files and uploads
them to the tested `/api/videos` route. The student player fetches the protected
stream with the signed-in API client and plays it from a browser object URL.
A live browser upload and playback check is still required.
