# Agency OS — Backend & Supabase foundation

This package is the backend/database layer intended to connect to the existing Agency OS HTML/CSS/JS frontend. It does not redesign the frontend.

## What is included

- Node.js + Express API (`/api/v1`)
- Supabase Auth token verification
- User-scoped Supabase client so database Row Level Security (RLS) remains active
- Resource API for the CRM, projects, tasks, campaigns, HR, finance and collaboration records
- Health endpoint, CORS allowlist, Helmet headers, rate limiting, validation and centralized errors
- SQL migrations for the core organization, user, CRM, delivery, marketing, HR, finance, wallet, payout, meeting, messaging, integration, document, notification and audit tables
- RLS policies for organization isolation and stricter finance/admin/message/time-entry access
- Frontend API helper with a placeholder backend URL
- `.env.example` with placeholders only

## Important: what is not connected yet

No real Supabase project, Google OAuth, ad-platform account, payment provider, wallet, email inbox or calendar is connected by this package. Those require your own project URLs, credentials, callback URLs, scopes and provider approval. The placeholders are intentionally blank.

This is a production-oriented foundation, not a claim of a fully deployed/independently audited production service. Before launch, run the security checklist below and test every permission against real test accounts.

## Requirements

- Node.js 22.22+
- A Supabase project
- VS Code / terminal

## 1. Install

```bash
npm install
cp .env.example .env
```

On Windows PowerShell:

```powershell
Copy-Item .env.example .env
```

Fill in only:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `APP_BASE_URL`
- `CORS_ORIGINS`

Do not add the service-role key to this API configuration. The API uses the caller's access token and the public/publishable (or anon) key so RLS is enforced. Never expose a service-role key in browser code.

## 2. Create the database

In Supabase Dashboard:
1. Create a NEW project for Agency OS (or confirm the target project is empty and backed up).
2. Open SQL Editor.
3. Run migrations in numeric order:
   - `supabase/migrations/001_initial_schema.sql`
   - `supabase/migrations/002_security_rls.sql`
   - `supabase/migrations/003_bootstrap_functions.sql`
4. Confirm all tables and policies exist.
5. Configure Auth providers and allowed redirect URLs.

Do not run these migrations against a database containing important tables without reviewing the changes first.

## 3. Bootstrap the first organization owner

1. Sign up the owner through Supabase Auth.
2. Copy the new Auth user's UUID.
3. Insert the organization and record its UUID.
4. Create the Owner/Admin role and departments.
5. Insert the first `organization_members` row linking the Auth user to the organization and role.

Use the following SQL as a starting point, replacing the placeholders:

```sql
insert into public.organizations (name, slug, default_currency)
values ('Agency OS', 'agency-os', 'USD')
returning id;

insert into public.roles (organization_id, name, is_system, permissions)
values ('REPLACE_ORG_UUID', 'Owner', true, '{"*": true}'::jsonb)
returning id;

insert into public.organization_members
  (organization_id, user_id, role_id, status, joined_at)
values
  ('REPLACE_ORG_UUID', 'REPLACE_AUTH_USER_UUID', 'REPLACE_ROLE_UUID', 'active', now());
```

Create department rows and optional department memberships after this. Never share real user UUIDs or secrets publicly.

## 4. Start the API

```bash
npm run check
npm run dev
```

Health check:
`http://localhost:4000/health`

Authenticated user:
`GET /api/v1/auth/me`

Resource examples:
- `GET /api/v1/clients?page=1&pageSize=25`
- `POST /api/v1/leads`
- `PATCH /api/v1/tasks/REPLACE_UUID`
- `GET /api/v1/invoices`
- `GET /api/v1/integrations`

All resource endpoints require `Authorization: Bearer SUPABASE_ACCESS_TOKEN`.

## 5. Connect the existing frontend

1. Add the Supabase browser client to the frontend using the project URL and public/publishable key only.
2. Implement sign-in/sign-out and session persistence.
3. Copy `frontend/api-client.js` into the existing frontend assets.
4. Set `API_BASE_URL` to the deployed API URL.
5. Replace each localStorage read/write with API calls section by section.
6. Keep UI state optimistic only where rollback/error handling exists.

The API helper expects a function `getAccessToken()` that returns the current Supabase session access token.

## Data model coverage

| Area | Tables |
|---|---|
| Organization & access | organizations, profiles, departments, roles, organization_members |
| Sales & clients | leads, clients, activities |
| Delivery | projects, tasks, time_entries |
| Marketing | campaigns, campaign_metrics, content_items |
| Recruitment | job_openings, candidates |
| Partners | affiliates, commission_rules, commission_entries |
| Finance | invoices, expenses |
| Wallets & payouts | wallet_accounts, ledger_entries, payout_requests |
| Meetings & messages | meetings, meeting_participants, internal_messages |
| Integrations & files | integration_connections, documents |
| Operations | notifications, audit_logs |

## Security and launch checklist

- [ ] Confirm RLS is enabled on every exposed table.
- [ ] Test two separate organizations; neither may read or mutate the other's records.
- [ ] Test employee, department lead, owner/admin and finance roles using separate Auth accounts.
- [ ] Review department-level restrictions. The current SQL enforces tenant and selected finance/admin restrictions; the exact department permission matrix still needs approval and implementation.
- [ ] Add server-side audit logging for every sensitive mutation.
- [ ] Add invitation and employee onboarding flows.
- [ ] Configure storage buckets and private signed URLs for CVs, receipts, proofs and client files.
- [ ] Add OAuth authorization-code flows, encrypted token storage, refresh, revoke and reconnect handling before enabling Gmail/Calendar/Meet.
- [ ] Add signed webhook verification and idempotency before processing provider events.
- [ ] Implement a real payment provider adapter only after selecting the provider and confirming jurisdiction/account requirements.
- [ ] Add automated integration tests, backup/restore test, monitoring and staging deployment.
- [ ] Review legal, privacy, tax and financial requirements for the countries where the company operates.

## Deliberately reserved placeholders

- `REPLACE_WITH_SUPABASE_PROJECT_URL`
- `REPLACE_WITH_SUPABASE_PUBLISHABLE_OR_ANON_KEY`
- `REPLACE_WITH_BACKEND_API_URL`
- Google OAuth client ID/secret and redirect URI
- Meta/TikTok developer credentials
- Payment provider and webhook configuration

Do not paste secrets into chat, source files, or frontend JavaScript. Put them in local `.env` or the deployment platform's secret manager.
