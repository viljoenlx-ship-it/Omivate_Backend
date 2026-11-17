# Progress — paused 2026-11-17

Phase 1 is not finished. This note is the resume point. Nothing here is a secret.

## Done

- Branch `dev` (base `main`). Supabase CLI layout: `supabase/config.toml`, `supabase/migrations`.
- Local config: project id `omivate-backend`, email/password, minimum length 8 with mixed case, digit and symbol, TOTP enrol and verify turned on, analytics container off. Site URL `http://127.0.0.1:3000`.
- Migrations apply in order on Postgres 17. Checked by loading them into Postgres 17 with stub `auth.users`, `auth.jwt()`, and the Supabase roles (`anon`, `authenticated`, `service_role`). Not yet checked with `supabase start`.
- Schema in place:
  - Tenants, branding, profile, platform staff (`owner`, `platform_admin`), memberships (`tenant_admin`, `manager`, `operator`, `viewer`), invites (token hash only).
  - Control Centre catalogue: modules M01–M41, per-tenant module rows, feature flags (`camera_scan`, `handheld_scan` forced on, `production`, `timesheets`), production screen columns.
  - Production tables: quarries, materials, machines, operators, polish grades, blocks, cuts, slabs, cut-to-size jobs.
  - Block measures are generated columns: m³ = L×W×H/1e6, tons = m³×3.65, cost = m³×m³ cost.
  - Cut m²/m³ and slab/job measures match the prototype formulas. Multiwire cuts require wire parameters.
  - New tenant trigger seeds branding, profile, feature row, the prototype core module set (19 on), and grades CL / C / UP.
  - Guards: child rows stay on the parent tenant, stage updates move exactly one step forward, `tenant_id` cannot change.
- Smoke insert: 260×150×150 cm at 2500 per m³ → m³ `5.8500`, tons `21.3525`, block cost `14625.00`.

## Partial

- RLS, grants, and the `internal` access helpers (`current_tenant_id`, `has_aal2`, role checks) are not written. Tables are readable by the migration role only. PostgREST is not locked down yet.
- `public.custom_access_token_hook` is not created. The hook block in `config.toml` is commented out on purpose so GoTrue does not boot against a missing function.
- No RPCs (`receive_block`, `record_cut`, `advance_stage_by_barcode`, `compute_recovery`), no Edge Functions, no views (stage board, KPIs, uncut, unpolished, recovery, redacted columns).
- No `seed.sql`, no pgTAP, no GitHub Actions, no OpenAPI export, no `API.md` / `SETUP.md` / `ROADMAP.md`. README is still the one-line stub.
- Audit table and triggers are not written.
- Column visibility is stored as catalogue rows only. Nothing hides a column on read.
- Disabled-module blocking is not enforced. `tenant_features.production` is only a flag.

## Next steps to resume

1. Add `supabase/migrations/20261117120400_access.sql`: security-definer helpers in schema `internal` (not exposed in `[api].schemas`), then RLS. Platform staff with `aal2` see every tenant. Tenant members see only `current_tenant_id()`. Writes require `aal2`. `tenant_admin` and platform staff require `aal2` for reads as well. Viewers cannot write. Operators cannot change settings or delete. Production tables additionally require `tenant_features.production` (platform staff may read while it is off, nobody may write).
2. Add the audit table and an append-only trigger (block `UPDATE`/`DELETE` for every role except the migration owner). Attach it to business tables.
3. Add `public.custom_access_token_hook(event jsonb)`, grant execute only to `supabase_auth_admin`, then uncomment the hook in `config.toml`.
4. Add RPCs and thin Edge Functions: `receive-block`, `record-cut`, `advance-stage`, `compute-recovery`, `invite-user`. Invite stores a SHA-256 of the token. A trigger on `auth.users` accepts pending invites for that email.
5. Add views: `v_stage_board`, `v_production_kpis`, `v_block_recovery`, `v_uncut_blocks`, `v_unpolished_blocks`, and screen views that null hidden columns. Use `security_invoker = true`.
6. Write `supabase/seed.sql` with fictional tenants only (Top Quartz production off, The Granite Warehouse production on, platform owner `liam@omnivate.co.za`). Local demo password is the published prototype password. Do not commit a hosted service role key.
7. pgTAP in `supabase/tests`: tenant A cannot read or write tenant B, role limits, disabled production blocked, audit row written and not editable, the measure numbers above, barcode advance.
8. `.github/workflows/ci.yml`: `supabase start` (exclude studio, analytics, storage if memory is tight) and `supabase test db`. Generate `docs/openapi.json` from `GET /rest/v1/` and write `API.md`.
9. Replace README. Add `ROADMAP.md` (customers, stock, GRVs, quotes, invoices at 15% VAT, sales order book, labels, timesheets/BCEA, WhatsApp) and `SETUP.md` (hosted project, no South Africa region, copy URL and anon key, never share `service_role`, db push, Auth URLs, enable TOTP, enable the access-token hook).
10. Re-check on a fresh `supabase db reset` before marking Phase 1 done.

## Liam does not need to do anything for this pause

No hosted project, no API keys. Keep `service_role` off git when the hosted project exists.
