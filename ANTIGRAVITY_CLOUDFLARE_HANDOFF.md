# School Cloudflare migration handoff

The active checkout is `C:\dileepkm\Learning\School-project`. The confirmed website hostname is `schools.katixo.com`. `schools-api.katixo.com` is only a proposed API hostname. No school Pages project, Worker, D1 database, DNS record, or public deployment exists yet. Do not change the existing Katixo or Milterra resources.

## Source and current evidence

- Read `CLOUDFLARE_IMPLEMENTATION_PLAN.md`, `CLOUDFLARE_DEPLOYMENT_STATUS.md`, and `ROUTE_CONTRACT_MATRIX.md`. Inspect `git status` before any Git operation. The repository is behind `origin/main` and contains substantial pre-existing tracked and untracked Flutter/backend work. Preserve it; do not use `git add -A`, `git clean`, or `git reset --hard`.
- The new local Worker is in `cloudflare/worker/`. `0001_initial.sql` is the runtime probe baseline; `0002_school_schema.sql` creates the 44 school model tables. `generate_school_schema.py` derives the schema from `backend/app/models.py`. Money columns with two decimal places are stored as scaled integers; application reads and writes must consistently convert them.
- Both migrations applied to an isolated local D1. The Worker dry-run bundled 215 modules. Thirteen local schema/Worker tests passed. `/health/ready` requires the 0002 migration and all 44 school tables; default probe access is disabled. These are local checks, not remote acceptance.
- The Worker has school-code validation and login, refresh, and logout routes in `src/school_auth.py`. Only missing/invalid-context route behavior and a password-hash roundtrip have been tested. The other FastAPI routes remain on the PostgreSQL backend and have not been ported to D1.
- Wrangler is OAuth-authenticated for Pages, Workers, and D1. The present token lacks zone/Worker-route scopes, which may need a permission refresh for hostname setup. No school Cloudflare resources were created.

## Next work in order

1. Make a reviewed source checkpoint for the pre-existing untracked `backend/` and supporting files. The narrow Cloudflare commit does not contain the whole application, so use this checkout before relying on a fresh clone. Exclude credentials, local data, virtual environments, generated builds, and unrelated Flutter edits. Keep Flutter source unchanged during the backend migration.
2. Make the Worker dependency build reproducible from `pyproject.toml` and `uv.lock` rather than relying on the current local `src/vendor/` directory. Verify a clean-checkout bundle and all tests.
3. Complete Phase 2 privately: bootstrap a school and initial administrator without a public credential-seeding endpoint; test successful login/refresh/logout, disabled accounts/schools, tenant A/B isolation, concurrent session rotation, role enforcement, and legacy password compatibility. Measure actual staging Worker CPU for secure password verification.
4. Port the remaining API contracts to D1 in vertical slices, using `ROUTE_CONTRACT_MATRIX.md` and Flutter call sites. Preserve tenant ownership, academic-year context, integer money conversions, atomic fee/payment invariants, and April–March billing with old-year dues retained. Add contract and cross-tenant tests for each slice. A 44-table schema alone does not make the 170 routes functional.
5. Create isolated school staging D1/Worker/Pages resources. Apply both migrations, verify readiness and browser flows, measure CPU/usage, and test backup/restore. Do not reuse the existing Katixo/Milterra resources. Decide the API hostname before rebuilding Flutter with its final `API_BASE_URL`.
6. After full role/workflow acceptance, connect the school Pages project to `schools.katixo.com` and configure the API hostname/routing. Verify DNS, HTTPS, CORS, authentication, media, and all critical workflows on the deployed system before calling it production ready.

Update `CLOUDFLARE_DEPLOYMENT_STATUS.md` with exact commands, results, remaining failures, and deployed resource IDs as work advances. No Cloudflare cutover is authorized or implied by this local checkpoint.
