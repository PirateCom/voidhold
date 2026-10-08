-- Cap new auth signups at 20 commanders (existing accounts unchanged).

create or replace function private.max_registered_users()
returns integer
language sql
immutable
set search_path = ''
as $$
  select 20;
$$;

revoke all on function private.max_registered_users() from public, anon, authenticated;

create or replace function private.enforce_registration_cap()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  cap integer := private.max_registered_users();
  have integer;
begin
  perform pg_advisory_xact_lock(42424242);
  select count(*)::integer into have from auth.users;
  if have >= cap then
    raise exception 'REGISTRATION_CAP: All % commander slots are taken.', cap
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_registration_cap() from public, anon, authenticated;

drop trigger if exists enforce_registration_cap on auth.users;
create trigger enforce_registration_cap
  before insert on auth.users
  for each row execute function private.enforce_registration_cap();

create or replace function public.registration_open()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select count(*)::integer from auth.users) < private.max_registered_users();
$$;

revoke all on function public.registration_open() from public;
grant execute on function public.registration_open() to anon, authenticated;

notify pgrst, 'reload schema';
