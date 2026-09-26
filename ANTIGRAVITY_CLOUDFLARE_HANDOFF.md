# Antigravity handoff: school Cloudflare migration

Work in C:/dileepkm/Learning/School-project. Read CLOUDFLARE_IMPLEMENTATION_PLAN.md and CLOUDFLARE_DEPLOYMENT_STATUS.md before editing. Target school.katixo.com; keep Python/FastAPI and Flutter. The immediate task is Phase 0 and Phase 1, not public cutover.

## First work package

1. Inspect Git status and local instructions. Preserve all current changes. The FastAPI backend/ and some Flutter/tests are untracked and are NOT included in the documentation-only GitHub push. Use this checkout; do not assume a fresh clone has the backend. Prepare a reviewed source checkpoint without credentials, personal records, backend/data, virtual environments or generated build files. Do not automatically commit unrelated work.
2. Run and record the existing backend/Flutter baseline and route audit. Generate a complete app.routes-to-Flutter contract matrix, including named routers, permissions and tenant ownership. Record baseline failures separately from new regressions.
3. Scaffold isolated cloudflare/worker/ tooling, a minimal reviewed D1 migration and contract-compatible health/readiness endpoints. Keep the existing PostgreSQL backend operational as the reference.
4. Prove the runtime dependencies and secure password verification in the actual Python Worker runtime. Current auth uses scrypt/legacy BCrypt and opaque tokens, not JWT. Measure CPU before assuming the free plan can handle login. Never weaken hashing.
5. Prove D1 bound read/write, atomic rollback on failure, serialization and schema readiness. Document the async repository approach and how PostgreSQL locks/transactions will be replaced. Do not use a synchronous ORM adapter without runtime and transaction evidence.
6. Add meaningful tests and update the status/matrix with exact commands, results, limits and the next slice. Stop at any incompatible dependency or cost decision and present measured evidence. Do not describe local proof as a fully deployed school system.

Suggested baseline commands (inspect environments first):

```powershell
# From repository root
flutter test
flutter build web --release --dart-define=API_BASE_URL=https://school-api.katixo.com/api
# Build verification only: that API hostname is not provisioned.

# From backend/ with its Python environment active
python -m pytest -q
python -m scripts.audit_flutter_routes
```

Review scripts/postgres_acceptance.py before running it; it requires a disposable database. Native SQLite tests do not prove remote D1 concurrency. Discover/pin pywrangler dependencies inside the new Worker directory instead of depending on Milterra's environment.

## Following work packages

After Phase 1 passes, implement Phase 2: schema, school bootstrap, authentication/session rotation, roles and tenant isolation. Then integrate public content in a separate staging Pages project and proceed through the plan's core workflows, media and full acceptance gates.

## Boundaries

- No changes to existing Katixo or Milterra resources, DNS, databases or deployed assets.
- No new paid subscriptions, broadened security-sensitive access or real data imports without required approval.
- No public school.katixo.com cutover yet; the frontend-only preview choice has not been answered.
- No placeholder successful responses, default production passwords, fake fee data or public student media.
- Keep compatibility and workload/cost uncertainty visible. Do not claim all modules work from a homepage or /health result.

## Report back

List changed files, preserved existing work, baseline/new test results, actual Worker/D1 runtime results, CPU/hash measurements, remaining blockers and the next concrete phase. Update the tracker after each completed slice. Only mark a phase complete with its stated exit evidence.
