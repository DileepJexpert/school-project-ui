# School Cloudflare migration handoff

The active checkout is `C:\dileepkm\Learning\School-project`. The confirmed website hostname is `schools.katixo.com`; `schools-api.katixo.com` is only a proposed API hostname. Separate school staging D1, Worker, and Pages resources now exist, but the public hostname is not attached. Do not change the existing Katixo or Milterra resources.

## Source and current evidence

- Read `CLOUDFLARE_IMPLEMENTATION_PLAN.md`, `CLOUDFLARE_DEPLOYMENT_STATUS.md`, and `ROUTE_CONTRACT_MATRIX.md`. Inspect `git status` before any Git operation. The FastAPI backend and route matrix are now in local commit `818d9c4`; the branch remains behind `origin/main` and contains substantial unrelated Flutter edits and uncommitted Worker auth work. Preserve them; do not use `git add -A`, `git clean`, or `git reset --hard`.
- The new local Worker is in `cloudflare/worker/`. `0001_initial.sql` is the runtime probe baseline; `0002_school_schema.sql` creates the 44 school model tables. `generate_school_schema.py` derives the schema from `backend/app/models.py`. Money columns with two decimal places are stored as scaled integers; application reads and writes must consistently convert them.
- Both migrations applied to local and remote staging D1. The staging Worker is live at `https://school-api-staging.todileepmaurya.workers.dev`; live readiness and CORS preflight pass. Local auth/schema tests pass 11/11 and Worker runtime tests pass 10/10. Default probe access remains disabled.
- The staging Flutter preview is live at `https://school-staging.pages.dev` with a demo-content notice and no-index header. It is incomplete: Flutter's `/api/site-content` gets HTTP 404, and most FastAPI routes remain unported. Do not attach `schools.katixo.com` or present this preview as production ready.
- `src/school_auth.py` now has locally tested positive login, refresh/logout, inactive-account, and tenant-isolation behavior, but no live staging account or browser sign-in has been verified. Legacy BCrypt and password-hashing CPU still need proof in the Worker runtime.
- Wrangler OAuth lacks zone/Workers Routes scopes. The `Workers Scripts` token lacks `katixo.com` Zone DNS Edit and Workers Routes Edit; that security-sensitive token change is awaiting action-time approval.

## Next work in order

1. Preserve the committed backend and the unrelated Flutter working tree. Keep Flutter source unchanged during backend migration. Review and checkpoint the current uncommitted Worker auth/bootstrap files before relying on a fresh clone.
2. Finish the reproducible Worker dependency build from `pyproject.toml` and `uv.lock`; `build_vendor.py` is currently uncommitted. Verify a clean-checkout bundle and all tests, including real Worker compatibility for any optional legacy BCrypt support.
3. Complete Phase 2 privately: use a non-public bootstrap process for a school and initial administrator, then test real staging login/refresh/logout, disabled accounts/schools, tenant A/B isolation, concurrent session rotation, and role enforcement. Measure actual Worker CPU for password verification.
4. Port the remaining API contracts to D1 in vertical slices, using `ROUTE_CONTRACT_MATRIX.md` and Flutter call sites. Preserve tenant ownership, academic-year context, integer money conversions, atomic fee/payment invariants, and April–March billing with old-year dues retained. Add contract and cross-tenant tests for each slice. A 44-table schema alone does not make the 170 routes functional.
5. Continue acceptance on the separate school staging D1/Worker/Pages resources. Verify browser workflows, CPU/usage, and backup/restore. Decide the API hostname before rebuilding Flutter with its final `API_BASE_URL`.
6. After full role/workflow acceptance, connect the school Pages project to `schools.katixo.com` and configure the API hostname/routing. Verify DNS, HTTPS, CORS, authentication, media, and all critical workflows on the deployed system before calling it production ready.

Update `CLOUDFLARE_DEPLOYMENT_STATUS.md` with exact commands, results, remaining failures, and deployed resource IDs as work advances. No Cloudflare cutover is authorized or implied by this local checkpoint.
