-- RLS helpers and tenant isolation.
create or replace function public.is_org_member(target_org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.organization_members m
    where m.organization_id = target_org
      and m.user_id = auth.uid()
      and m.status = 'active'
  );
$$;

create or replace function public.has_org_role(target_org uuid, allowed_roles text[])
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.organization_members m
    join public.roles r on r.id = m.role_id and r.organization_id = m.organization_id
    where m.organization_id = target_org
      and m.user_id = auth.uid()
      and m.status = 'active'
      and (r.name = any(allowed_roles) or r.name = 'Owner')
  );
$$;

create or replace function public.is_org_finance(target_org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.has_org_role(target_org, array['Admin','Finance Manager','Accountant']);
$$;

-- Organization rows are visible only to active members.
alter table public.organizations enable row level security;
drop policy if exists organizations_member_select on public.organizations;
create policy organizations_member_select on public.organizations for select to authenticated using (public.is_org_member(id));
drop policy if exists organizations_admin_update on public.organizations;
create policy organizations_admin_update on public.organizations for update to authenticated using (public.has_org_role(id, array['Admin','Owner'])) with check (public.has_org_role(id, array['Admin','Owner']));

-- Profiles are readable to users who share an organization; users edit only themselves.
alter table public.profiles enable row level security;
drop policy if exists profiles_select_shared on public.profiles;
create policy profiles_select_shared on public.profiles for select to authenticated
using (id = auth.uid() or exists (
  select 1 from public.organization_members mine
  join public.organization_members theirs on theirs.organization_id = mine.organization_id
  where mine.user_id = auth.uid() and theirs.user_id = profiles.id
  and mine.status='active' and theirs.status='active'
));
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update to authenticated using (id=auth.uid()) with check (id=auth.uid());
drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self on public.profiles for insert to authenticated with check (id=auth.uid());

-- Organization-scoped default policies. Sensitive tables get stricter rules below.
do $$
declare t text;
begin
  foreach t in array array[
    'departments','roles','organization_members','clients','leads','activities',
    'projects','tasks','time_entries','campaigns','campaign_metrics','content_items',
    'job_openings','candidates','affiliates','commission_rules','commission_entries',
    'invoices','expenses','wallet_accounts','ledger_entries','payout_requests',
    'meetings','meeting_participants','internal_messages','documents',
    'integration_connections','notifications','audit_logs'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists org_member_select on public.%I', t);
    execute format('create policy org_member_select on public.%I for select to authenticated using (public.is_org_member(organization_id))', t);
  end loop;
end $$;

-- General organization members may create/update operational records. RLS still
-- prevents cross-organization access. Department-specific rules can be tightened
-- after the exact role matrix is approved.
do $$
declare t text;
begin
  foreach t in array array[
    'clients','leads','activities','projects','tasks','time_entries','campaigns',
    'campaign_metrics','content_items','job_openings','candidates','affiliates',
    'meetings','meeting_participants','internal_messages','documents','notifications'
  ] loop
    execute format('drop policy if exists org_member_insert on public.%I', t);
    execute format('create policy org_member_insert on public.%I for insert to authenticated with check (public.is_org_member(organization_id))', t);
    execute format('drop policy if exists org_member_update on public.%I', t);
    execute format('create policy org_member_update on public.%I for update to authenticated using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id))', t);
  end loop;
end $$;

-- Organization members can read their own membership, departments and role definitions;
-- only admins can manage memberships, departments and roles.
drop policy if exists org_member_select on public.organization_members;
create policy membership_self_or_admin_select on public.organization_members for select to authenticated
using (user_id = auth.uid() or public.has_org_role(organization_id, array['Admin','Owner']));
drop policy if exists org_member_select on public.departments;
create policy departments_member_select on public.departments for select to authenticated
using (public.is_org_member(organization_id));
drop policy if exists org_member_select on public.roles;
create policy roles_member_select on public.roles for select to authenticated
using (public.is_org_member(organization_id));

-- Admin-only organization structure and integration management.
do $$
declare t text;
begin
  foreach t in array array['departments','roles','organization_members','integration_connections'] loop
    execute format('drop policy if exists org_member_select on public.%I', t);
    execute format('create policy org_member_select on public.%I for select to authenticated using (public.is_org_member(organization_id))', t);
    execute format('drop policy if exists org_admin_insert on public.%I', t);
    execute format('create policy org_admin_insert on public.%I for insert to authenticated with check (public.has_org_role(organization_id, array[''Admin'',''Owner'']))', t);
    execute format('drop policy if exists org_admin_update on public.%I', t);
    execute format('create policy org_admin_update on public.%I for update to authenticated using (public.has_org_role(organization_id, array[''Admin'',''Owner''])) with check (public.has_org_role(organization_id, array[''Admin'',''Owner'']))', t);
  end loop;
end $$;

-- Financial records: visible only to finance roles and Admin/Owner.
do $$
declare t text;
begin
  foreach t in array array['commission_entries','invoices','expenses','wallet_accounts','ledger_entries','payout_requests'] loop
    execute format('drop policy if exists org_member_select on public.%I', t);
    execute format('create policy finance_select on public.%I for select to authenticated using (public.is_org_finance(organization_id))', t);
    execute format('drop policy if exists org_member_insert on public.%I', t);
    execute format('drop policy if exists org_member_update on public.%I', t);
    execute format('create policy finance_insert on public.%I for insert to authenticated with check (public.is_org_finance(organization_id))', t);
    execute format('create policy finance_update on public.%I for update to authenticated using (public.is_org_finance(organization_id)) with check (public.is_org_finance(organization_id))', t);
  end loop;
end $$;

-- Notifications are private to their intended recipient.
drop policy if exists org_member_select on public.notifications;
create policy notifications_recipient_select on public.notifications for select to authenticated
using (user_id = auth.uid());
drop policy if exists org_member_insert on public.notifications;
create policy notifications_member_insert on public.notifications for insert to authenticated
with check (public.is_org_member(organization_id));

-- A user sees their own time entries; managers/admins can see the organization.
drop policy if exists org_member_select on public.time_entries;
create policy time_entries_select on public.time_entries for select to authenticated
using (user_id = auth.uid() or public.has_org_role(organization_id, array['Admin','Owner','Operations Manager']));
drop policy if exists org_member_insert on public.time_entries;
create policy time_entries_insert on public.time_entries for insert to authenticated
with check (user_id = auth.uid() and public.is_org_member(organization_id));
drop policy if exists org_member_update on public.time_entries;
create policy time_entries_update on public.time_entries for update to authenticated
using (user_id = auth.uid() or public.has_org_role(organization_id, array['Admin','Owner']))
with check (user_id = auth.uid() or public.has_org_role(organization_id, array['Admin','Owner']));

-- Messages: sender, recipient, management and department scope.
drop policy if exists org_member_select on public.internal_messages;
create policy messages_select on public.internal_messages for select to authenticated
using (
  public.is_org_member(organization_id) and (
    sender_id = auth.uid()
    or recipient_user_id = auth.uid()
    or recipient_scope = 'all'
    or (recipient_scope = 'management' and public.has_org_role(organization_id, array['Admin','Owner','Managing Director']))
    or (recipient_scope = 'department' and exists (
      select 1 from public.organization_members m
      where m.organization_id = internal_messages.organization_id
      and m.user_id = auth.uid() and m.department_id = internal_messages.department_id
    ))
  )
);
drop policy if exists org_member_insert on public.internal_messages;
create policy messages_insert on public.internal_messages for insert to authenticated
with check (sender_id = auth.uid() and public.is_org_member(organization_id));

-- Audit log is append-only for authenticated app users; only admins can read.
drop policy if exists org_member_select on public.audit_logs;
create policy audit_admin_select on public.audit_logs for select to authenticated
using (public.has_org_role(organization_id, array['Admin','Owner']));
create policy audit_member_insert on public.audit_logs for insert to authenticated
with check (actor_id = auth.uid() and public.is_org_member(organization_id));

-- No authenticated user may delete financial/audit records through the API.
revoke delete on public.ledger_entries, public.audit_logs from authenticated;
