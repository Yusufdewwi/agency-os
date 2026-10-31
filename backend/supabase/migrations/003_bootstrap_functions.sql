-- Create a profile automatically when a Supabase Auth user is created.
create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, first_name, last_name, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'first_name',''),
    coalesce(new.raw_user_meta_data->>'last_name',''),
    coalesce(new.raw_user_meta_data->>'display_name', new.email)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_auth_user();

-- Bootstrap an organization only after the first Auth user has signed up.
-- Run manually after replacing the values; do not seed production user credentials.
-- Example:
-- insert into public.organizations(name, slug) values ('Agency OS', 'agency-os')
-- returning id;
-- Then insert roles, departments, and organization_members for the owner.
