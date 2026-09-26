-- Self-serve account deletion: wipe empire data, then remove auth.users.
-- SECURITY DEFINER is required to delete from auth.users; the body only
-- deletes auth.uid(), never a client-supplied id.

create or replace function public.delete_own_account(p_confirmation text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  if lower(btrim(coalesce(p_confirmation, ''))) <> 'delete' then
    raise exception 'Type delete to confirm.';
  end if;

  delete from public.fleets
  where owner_id = uid
     or dest_planet_id in (select id from public.planets where owner_id = uid)
     or origin_planet_id in (select id from public.planets where owner_id = uid);

  delete from public.battle_reports where user_id = uid;

  delete from public.debris_fields
  where (galaxy, system, slot) in (
    select galaxy, system, slot from public.planets where owner_id = uid
  );

  -- Empires reference planets without ON DELETE CASCADE; drop them first.
  delete from public.empires where user_id = uid;
  delete from public.planets where owner_id = uid;
  delete from public.profiles where user_id = uid;
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_own_account(text) from public, anon;
grant execute on function public.delete_own_account(text) to authenticated;
