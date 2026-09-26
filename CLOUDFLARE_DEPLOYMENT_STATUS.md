# School Cloudflare deployment status

Checked 26 September 2026. Target: school.katixo.com.

## Verified

- Active checkout: C:/dileepkm/Learning/School-project, remote DileepJexpert/school-project-ui.
- Existing tracked and untracked changes were preserved; no source changes were made during this audit.
- Cloudflare dashboard confirms katixo.com is Active on the Free plan.
- The current school backend is FastAPI with SQLAlchemy, psycopg/PostgreSQL and Alembic. It has 108 router endpoint decorators and 44 model tables.
- No school Worker entrypoint, Wrangler configuration or D1 migration was found.
- The Flutter JavaScript release build passed with API_BASE_URL=https://school-api.katixo.com/api for build verification. That API hostname has NOT been provisioned. Flutter reported optional Wasm incompatibilities in the existing dart:html video/CSV code; the JavaScript release build succeeded.
- Nothing has been published and no school DNS records have been created.

## Compatibility work before a working management deployment

1. Adapt the PostgreSQL/SQLAlchemy data access to the selected Cloudflare runtime and storage. Preserve tenant ownership and role checks throughout.
2. Replace PostgreSQL row locks and multi-statement transactions with proven atomic D1 operations, especially fee allocation/reversal, refresh-token rotation, attendance, results publication and academic-year rollover. Do not silently drop locking.
3. Preserve exact monetary amounts: current models use Numeric/Decimal. Define and test the D1 money representation before copying fee/payroll workflows.
4. Prove password hashing and verification in the runtime and within its CPU limits. The current implementation uses scrypt and accepts legacy BCrypt. Do not weaken hashing to fit the free tier.
5. Replace filesystem video uploads/streaming with private object storage and authorized retrieval. R2 activation or any paid service needs separate approval.
6. Treat optional Ollama AI as a separate reachable service; it cannot be assumed to run inside the Worker. Keep it disabled unless configured and tested.
7. Create separate school Pages/Worker/D1 resources and secrets. Do not reuse Milterra/Katixo application data or modify their existing deployments.
8. Configure the real school tenant and public content, bootstrap an admin privately, and run tenant-isolation, authentication, fees, attendance, results, migration/restore and browser acceptance before allowing real student records.

## Implementation handoff

The user requested a pushed implementation plan for Antigravity. See CLOUDFLARE_IMPLEMENTATION_PLAN.md and ANTIGRAVITY_CLOUDFLARE_HANDOFF.md. Start with baseline preservation and runtime compatibility proof; no migration code or public deployment is included in this documentation handoff. The earlier frontend-preview versus full-backend publishing choice remains unanswered. A frontend upload alone is not a working school management deployment. The current app requests site content before runApp and retains sample school content on an unavailable API; any preview must identify itself clearly and avoid suggesting management workflows work.


## Progress tracker

| Phase | Status | Next evidence |
| --- | --- | --- |
| Source/domain audit and frontend build | Complete | 69 files, 42.95 MiB total, largest 6.89 MiB; no deployment |
| Plan and Antigravity handoff | Complete | Documentation-only change; implementation remains pending |
| Baseline/source checkpoint | Pending | Preserve untracked backend and current edits; full route matrix |
| Python Worker/D1 runtime proof | Pending | Secure auth CPU, transactions, health/readiness |
| Schema/auth and tenant isolation | Pending | Actual D1 tests |
| Public content and staging frontend | Pending | Browser integration |
| School workflow parity | Pending | Fees, attendance, results, rollover and remaining modules |
| Private media and jobs | Pending | Storage approval and acceptance |
| Production cutover | Pending | Full acceptance, backup/restore, cost measurements |
