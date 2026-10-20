-- Raise the test signup cap from 20 to 30 commanders. Existing accounts are unchanged.

create or replace function private.max_registered_users()
returns integer
language sql
immutable
set search_path = ''
as $$
  select 30;
$$;

revoke all on function private.max_registered_users() from public, anon, authenticated;
