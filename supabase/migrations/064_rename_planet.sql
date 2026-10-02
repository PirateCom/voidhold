-- Commanders can rename planets they own.

create or replace function public.rename_planet(p_planet_id bigint, p_name text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  cleaned text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  cleaned := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  if cleaned = '' then
    raise exception 'Give the planet a name.';
  end if;
  if char_length(cleaned) > 20 then
    raise exception 'Planet names can be at most 20 characters.';
  end if;
  if cleaned ~ '[[:cntrl:]]' then
    raise exception 'That name is not allowed.';
  end if;

  if not exists (
    select 1 from public.planets p where p.id = p_planet_id and p.owner_id = uid
  ) then
    raise exception 'That is not your planet.';
  end if;

  update public.planets set name = cleaned where id = p_planet_id and owner_id = uid;
  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.rename_planet(bigint, text) from public, anon;
grant execute on function public.rename_planet(bigint, text) to authenticated;
