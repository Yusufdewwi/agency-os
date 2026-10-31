-- Agency OS database foundation
-- Run in a NEW Supabase project first. Review policies before production.
create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  default_currency char(3) not null default 'USD',
  timezone text not null default 'Europe/Istanbul',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text not null default '',
  last_name text not null default '',
  display_name text,
  avatar_path text,
  phone text,
  locale text not null default 'en',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.departments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, name),
  unique (id, organization_id)
);

create table if not exists public.roles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  is_system boolean not null default false,
  permissions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (organization_id, name),
  unique (id, organization_id)
);

create table if not exists public.organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  department_id uuid,
  role_id uuid,
  job_title text,
  employment_type text check (employment_type in ('full_time','part_time','contractor','commission','intern')),
  status text not null default 'active' check (status in ('invited','active','suspended','left')),
  joined_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id),
  foreign key (department_id, organization_id) references public.departments(id, organization_id),
  foreign key (role_id, organization_id) references public.roles(id, organization_id),
  unique (id, organization_id)
);

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  legal_name text,
  website text,
  industry text,
  primary_contact text,
  email text,
  phone text,
  service_scope text,
  status text not null default 'prospect' check (status in ('prospect','onboarding','active','paused','churned')),
  account_owner uuid references auth.users(id) on delete set null,
  start_date date,
  renewal_date date,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organization_id)
);

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  company text,
  contact_name text,
  email text,
  phone text,
  source text,
  stage text not null default 'new' check (stage in ('new','contacted','qualified','proposal','won','lost')),
  estimated_value numeric(14,2) not null default 0 check (estimated_value >= 0),
  currency char(3) not null default 'USD',
  owner_id uuid references auth.users(id) on delete set null,
  next_step text,
  next_follow_up_at timestamptz,
  lost_reason text,
  client_id uuid,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (client_id, organization_id) references public.clients(id, organization_id),
  unique (id, organization_id)
);

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  entity_type text not null,
  entity_id uuid,
  activity_type text not null,
  description text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  client_id uuid,
  name text not null,
  description text,
  status text not null default 'planned' check (status in ('planned','active','on_hold','completed','cancelled')),
  start_date date,
  due_date date,
  project_manager uuid references auth.users(id) on delete set null,
  budget numeric(14,2) check (budget is null or budget >= 0),
  currency char(3) not null default 'USD',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (client_id, organization_id) references public.clients(id, organization_id),
  unique (id, organization_id)
);

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  project_id uuid,
  client_id uuid,
  title text not null,
  description text,
  status text not null default 'todo' check (status in ('todo','in_progress','review','blocked','done','cancelled')),
  priority text not null default 'medium' check (priority in ('low','medium','high','urgent')),
  assignee_id uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  due_at timestamptz,
  completed_at timestamptz,
  estimated_minutes integer check (estimated_minutes is null or estimated_minutes >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (project_id, organization_id) references public.projects(id, organization_id),
  foreign key (client_id, organization_id) references public.clients(id, organization_id),
  unique (id, organization_id)
);

create table if not exists public.time_entries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid,
  description text,
  started_at timestamptz not null,
  ended_at timestamptz,
  duration_seconds integer check (duration_seconds is null or duration_seconds >= 0),
  created_at timestamptz not null default now(),
  foreign key (task_id, organization_id) references public.tasks(id, organization_id),
  unique (id, organization_id)
);

create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  client_id uuid,
  name text not null,
  platform text,
  objective text,
  status text not null default 'planning' check (status in ('planning','active','paused','completed','archived')),
  budget numeric(14,2) check (budget is null or budget >= 0),
  currency char(3) not null default 'USD',
  owner_id uuid references auth.users(id) on delete set null,
  start_date date,
  end_date date,
  external_account_id text,
  external_campaign_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (client_id, organization_id) references public.clients(id, organization_id),
  unique (id, organization_id)
);

create table if not exists public.campaign_metrics (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  campaign_id uuid not null,
  metric_date date not null,
  spend numeric(14,2) not null default 0,
  impressions bigint not null default 0,
  clicks bigint not null default 0,
  leads bigint not null default 0,
  conversions bigint not null default 0,
  revenue numeric(14,2) not null default 0,
  currency char(3) not null default 'USD',
  source text,
  created_at timestamptz not null default now(),
  foreign key (campaign_id, organization_id) references public.campaigns(id, organization_id),
  unique (campaign_id, metric_date, source)
);

create table if not exists public.content_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  client_id uuid,
  campaign_id uuid,
  title text not null,
  channel text,
  content_type text,
  caption text,
  status text not null default 'idea' check (status in ('idea','brief','production','review','approved','scheduled','published')),
  due_at timestamptz,
  publish_at timestamptz,
  owner_id uuid references auth.users(id) on delete set null,
  asset_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (client_id, organization_id) references public.clients(id, organization_id),
  foreign key (campaign_id, organization_id) references public.campaigns(id, organization_id),
  unique (id, organization_id)
);

create table if not exists public.job_openings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  title text not null,
  department_id uuid,
  employment_type text,
  location text,
  description text,
  status text not null default 'draft' check (status in ('draft','open','paused','closed')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (department_id, organization_id) references public.departments(id, organization_id),
  unique (id, organization_id)
);

create table if not exists public.candidates (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  job_opening_id uuid,
  full_name text not null,
  email text,
  phone text,
  source text,
  stage text not null default 'applied' check (stage in ('applied','screening','interview','assessment','offer','hired','rejected')),
  cv_path text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (job_opening_id, organization_id) references public.job_openings(id, organization_id),
  unique (id, organization_id)
);

create table if not exists public.affiliates (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  email text,
  source text,
  status text not null default 'pending' check (status in ('pending','active','paused','rejected')),
  referral_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, referral_code),
  unique (id, organization_id)
);

create table if not exists public.commission_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  calculation_type text not null check (calculation_type in ('percentage','fixed')),
  rate numeric(12,4) not null check (rate >= 0),
  applies_to text not null default 'revenue',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organization_id)
);

create table if not exists public.commission_entries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  affiliate_id uuid,
  member_user_id uuid references auth.users(id) on delete set null,
  client_id uuid,
  invoice_id uuid,
  basis_amount numeric(14,2) not null default 0 check (basis_amount >= 0),
  commission_amount numeric(14,2) not null default 0 check (commission_amount >= 0),
  currency char(3) not null default 'USD',
  status text not null default 'pending' check (status in ('pending','approved','payable','paid','void')),
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key (affiliate_id, organization_id) references public.affiliates(id, organization_id),
  foreign key (client_id, organization_id) references public.clients(id, organization_id),
  unique (id, organization_id)
);

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  client_id uuid not null,
  invoice_number text not null,
  status text not null default 'draft' check (status in ('draft','sent','partially_paid','paid','overdue','void')),
  issue_date date,
  due_date date,
  subtotal numeric(14,2) not null default 0,
  tax_amount numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  amount_paid numeric(14,2) not null default 0,
  currency char(3) not null default 'USD',
  external_payment_reference text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (client_id, organization_id) references public.clients(id, organization_id),
  unique (organization_id, invoice_number),
  unique (id, organization_id)
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  description text not null,
  category text,
  amount numeric(14,2) not null check (amount >= 0),
  currency char(3) not null default 'USD',
  expense_date date not null default current_date,
  status text not null default 'submitted' check (status in ('submitted','approved','rejected','reimbursed')),
  submitted_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  receipt_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organization_id)
);

create table if not exists public.wallet_accounts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  wallet_type text not null check (wallet_type in ('operating','receivables','affiliate','contractor','reserve','provider')),
  provider text,
  external_account_ref text,
  currency char(3) not null default 'USD',
  status text not null default 'unconnected' check (status in ('unconnected','connected','restricted','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organization_id)
);

create table if not exists public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  wallet_account_id uuid not null,
  entry_type text not null check (entry_type in ('credit','debit','adjustment','reversal')),
  amount numeric(14,2) not null check (amount > 0),
  currency char(3) not null default 'USD',
  reference_type text,
  reference_id uuid,
  description text not null,
  idempotency_key text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  foreign key (wallet_account_id, organization_id) references public.wallet_accounts(id, organization_id),
  unique (organization_id, idempotency_key)
);

create table if not exists public.payout_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  wallet_account_id uuid,
  payee_user_id uuid references auth.users(id) on delete set null,
  affiliate_id uuid,
  amount numeric(14,2) not null check (amount > 0),
  currency char(3) not null default 'USD',
  reason text not null,
  status text not null default 'requested' check (status in ('requested','approved','rejected','processing','paid','failed','cancelled')),
  requested_by uuid references auth.users(id) on delete set null,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  provider_reference text,
  proof_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (wallet_account_id, organization_id) references public.wallet_accounts(id, organization_id),
  foreign key (affiliate_id, organization_id) references public.affiliates(id, organization_id),
  unique (id, organization_id),
  check (approved_by is null or approved_by <> requested_by)
);

create table if not exists public.meetings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  title text not null,
  description text,
  meeting_type text not null default 'internal',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  timezone text not null default 'Europe/Istanbul',
  provider text,
  external_event_id text,
  meeting_url text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  unique (id, organization_id)
);

create table if not exists public.meeting_participants (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  meeting_id uuid not null,
  user_id uuid references auth.users(id) on delete cascade,
  email text,
  response_status text not null default 'invited' check (response_status in ('invited','accepted','declined','tentative')),
  created_at timestamptz not null default now(),
  foreign key (meeting_id, organization_id) references public.meetings(id, organization_id),
  unique (meeting_id, user_id)
);

create table if not exists public.internal_messages (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_user_id uuid references auth.users(id) on delete cascade,
  recipient_scope text not null default 'user' check (recipient_scope in ('user','management','department','all')),
  department_id uuid,
  subject text not null,
  body text not null,
  message_type text not null default 'general',
  read_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key (department_id, organization_id) references public.departments(id, organization_id),
  unique (id, organization_id)
);

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  storage_path text not null,
  mime_type text,
  size_bytes bigint,
  entity_type text,
  entity_id uuid,
  uploaded_by uuid references auth.users(id) on delete set null,
  visibility text not null default 'department' check (visibility in ('private','department','organization','client')),
  created_at timestamptz not null default now(),
  unique (id, organization_id)
);

create table if not exists public.integration_connections (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  provider text not null,
  status text not null default 'disconnected' check (status in ('disconnected','connected','expired','error')),
  account_email text,
  encrypted_access_token text,
  encrypted_refresh_token text,
  token_expires_at timestamptz,
  scopes text[] not null default '{}',
  connected_by uuid references auth.users(id) on delete set null,
  connected_at timestamptz,
  last_synced_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, provider),
  unique (id, organization_id)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text,
  category text,
  entity_type text,
  entity_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  ip_address inet,
  user_agent text,
  created_at timestamptz not null default now()
);

-- Indexes for the most common workspace queries.
create index if not exists idx_members_user on public.organization_members(user_id, status);
create index if not exists idx_clients_org_status on public.clients(organization_id, status);
create index if not exists idx_leads_org_stage on public.leads(organization_id, stage);
create index if not exists idx_tasks_org_assignee on public.tasks(organization_id, assignee_id, status);
create index if not exists idx_tasks_due on public.tasks(organization_id, due_at);
create index if not exists idx_projects_org_status on public.projects(organization_id, status);
create index if not exists idx_activities_org_created on public.activities(organization_id, created_at desc);
create index if not exists idx_messages_recipient on public.internal_messages(organization_id, recipient_user_id, created_at desc);
create index if not exists idx_notifications_user on public.notifications(user_id, read_at, created_at desc);
create index if not exists idx_ledger_wallet on public.ledger_entries(wallet_account_id, created_at desc);
create index if not exists idx_payout_status on public.payout_requests(organization_id, status, created_at desc);

-- Updated-at triggers.
do $$
declare t text;
begin
  foreach t in array array['organizations','profiles','departments','organization_members','clients','leads','projects','tasks','campaigns','content_items','job_openings','candidates','affiliates','commission_rules','invoices','expenses','wallet_accounts','payout_requests','meetings','integration_connections'] loop
    execute format('drop trigger if exists trg_%I_updated_at on public.%I', t, t);
    execute format('create trigger trg_%I_updated_at before update on public.%I for each row execute function public.set_updated_at()', t, t);
  end loop;
end $$;
