-- Four UTC daily contracts: belt mine, spy, pirate wave (or 20 RL), transport/deploy/expedition.

create table if not exists public.daily_missions (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  slot text not null check (slot in ('belt', 'spy', 'wave', 'hop')),
  kind text not null check (kind in (
    'mine',
    'espionage',
    'pirate',
    'guns',
    'transport',
    'deploy',
    'expedition'
  )),
  status text not null check (status in ('active', 'ready', 'claimed')),
  dest_galaxy smallint,
  dest_system smallint,
  dest_slot smallint,
  title text not null,
  blurb text not null,
  reward_ore bigint not null default 0 check (reward_ore >= 0),
  reward_crystal bigint not null default 0 check (reward_crystal >= 0),
  reward_deuterium bigint not null default 0 check (reward_deuterium >= 0),
  baseline_guns integer not null default 0 check (baseline_guns >= 0),
  sort_order smallint not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  unique (user_id, day, slot)
);

create index if not exists daily_missions_user_day on public.daily_missions (user_id, day);

alter table public.daily_missions enable row level security;
revoke all on table public.daily_missions from public, anon, authenticated;

create or replace function private.daily_day_start(p_day date)
returns timestamptz
language sql
immutable
set search_path = ''
as $$
  select (p_day::text || ' 00:00:00+00')::timestamptz;
$$;

revoke all on function private.daily_day_start(date) from public, anon, authenticated;

create or replace function private.pick_daily_spy_target(uid uuid)
returns public.planets
language sql
stable
security definer
set search_path = public
as $$
  select p.*
  from public.planets p
  where p.owner_id is not null
    and p.owner_id is distinct from uid
    and p.slot between 1 and 15
  order by random()
  limit 1;
$$;

revoke all on function private.pick_daily_spy_target(uuid) from public, anon, authenticated;

create or replace function private.daily_report_matches(
  p_kind text,
  p_title text,
  p_body text,
  p_galaxy smallint,
  p_system smallint,
  p_slot smallint
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case p_kind
    when 'mine' then p_title = 'Mining barge returned' and p_body not ilike '%empty holds%'
    when 'espionage' then
      p_title = 'Espionage report'
      and (
        p_galaxy is null
        or p_body like ('%[' || p_galaxy::text || ':' || p_system::text || ':' || p_slot::text || ']%')
      )
    when 'pirate' then p_title like 'Pirates struck%'
    when 'transport' then p_title in ('Transport fleet returned', 'Transport received')
    when 'deploy' then p_title = 'Fleet deployed'
    when 'expedition' then p_title = 'Expedition returned'
    else false
  end;
$$;

revoke all on function private.daily_report_matches(text, text, text, smallint, smallint, smallint)
  from public, anon, authenticated;

create or replace function private.insert_daily_offer(
  uid uuid,
  p_day date,
  p_slot text,
  p_sort smallint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  home public.planets%rowtype;
  e public.empires%rowtype;
  belt record;
  spy public.planets%rowtype;
  colony public.planets%rowtype;
  p_kind text;
  g smallint;
  s smallint;
  sl smallint;
  p_title text;
  p_blurb text;
  ore bigint;
  crystal bigint;
  deut bigint;
  guns integer := 0;
  raids_on boolean;
begin
  select * into e from public.empires where user_id = uid;
  if not found then
    raise exception 'No empire.';
  end if;
  select * into home from public.planets where id = e.home_planet_id;
  if not found then
    raise exception 'No homeworld.';
  end if;

  if p_slot = 'belt' then
    select b.galaxy, b.system, b.belt_slot
    into belt
    from public.asteroid_belts b
    where b.galaxy = home.galaxy and b.system = home.system
    order by b.belt_slot
    limit 1;
    if found then
      p_kind := 'mine';
      g := belt.galaxy;
      s := belt.system;
      sl := belt.belt_slot;
      p_title := 'Fill the hoppers';
      p_blurb := format(
        'Mine the asteroid belt at [%s:%s:%s] and bring a barge home with cargo.',
        g, s, sl
      );
      ore := 2500;
      crystal := 800;
      deut := 100;
    else
      spy := private.pick_daily_spy_target(uid);
      if spy.id is not null then
        p_kind := 'espionage';
        g := spy.galaxy;
        s := spy.system;
        sl := spy.slot;
        p_title := 'Name the guns';
        p_blurb := format(
          'No belt in this system. Send probes to [%s:%s:%s] and bring back an espionage report.',
          g, s, sl
        );
        ore := 600;
        crystal := 1200;
        deut := 400;
      else
        p_kind := 'expedition';
        g := home.galaxy;
        s := home.system;
        sl := 16;
        p_title := 'Deep void survey';
        p_blurb := format('No belt and no neighbors. Launch an expedition at [%s:%s:16] and return.', g, s);
        ore := 500;
        crystal := 500;
        deut := 800;
      end if;
    end if;
  elsif p_slot = 'spy' then
    spy := private.pick_daily_spy_target(uid);
    if spy.id is not null then
      p_kind := 'espionage';
      g := spy.galaxy;
      s := spy.system;
      sl := spy.slot;
      p_title := 'Name the guns';
      p_blurb := format(
        'Send probes to [%s:%s:%s] and bring back an espionage report.',
        g, s, sl
      );
      ore := 600;
      crystal := 1200;
      deut := 400;
    else
      p_kind := 'expedition';
      g := home.galaxy;
      s := home.system;
      sl := 16;
      p_title := 'Deep void survey';
      p_blurb := format('No occupied neighbors. Launch an expedition at [%s:%s:16] and return.', g, s);
      ore := 500;
      crystal := 500;
      deut := 800;
    end if;
  elsif p_slot = 'wave' then
    raids_on := coalesce(e.pirate_raids_enabled, true);
    if raids_on then
      p_kind := 'pirate';
      g := home.galaxy;
      s := home.system;
      sl := home.slot;
      p_title := 'Wave tax';
      p_blurb := 'Survive one pirate wave on your hold today.';
      ore := 800;
      crystal := 1500;
      deut := 600;
    else
      p_kind := 'guns';
      g := home.galaxy;
      s := home.system;
      sl := home.slot;
      guns := greatest(coalesce(home.rocket_launcher, 0), 0);
      p_title := 'Wave tax';
      p_blurb := 'Pirate raids are off. Build 20 rocket launchers on this world.';
      ore := 1000;
      crystal := 400;
      deut := 0;
    end if;
  elsif p_slot = 'hop' then
    select * into colony
    from public.planets
    where owner_id = uid and id is distinct from home.id
    order by id
    limit 1;
    if found then
      p_kind := 'transport';
      g := colony.galaxy;
      s := colony.system;
      sl := colony.slot;
      p_title := 'Move the stock';
      p_blurb := format(
        'Transport resources to %s [%s:%s:%s], or deploy a hull there.',
        colony.name, g, s, sl
      );
      ore := 1000;
      crystal := 1000;
      deut := 500;
    else
      p_kind := 'expedition';
      g := home.galaxy;
      s := home.system;
      sl := 16;
      p_title := 'Move the stock';
      p_blurb := format(
        'No colony yet. Launch an expedition into outer space at [%s:%s:16] and return.',
        g, s
      );
      ore := 500;
      crystal := 500;
      deut := 800;
    end if;
  else
    raise exception 'Unknown daily slot.';
  end if;

  insert into public.daily_missions (
    user_id, day, slot, kind, status,
    dest_galaxy, dest_system, dest_slot,
    title, blurb, reward_ore, reward_crystal, reward_deuterium,
    baseline_guns, sort_order
  ) values (
    uid, p_day, p_slot, p_kind, 'active',
    g, s, sl,
    p_title, p_blurb, ore, crystal, deut,
    guns, p_sort
  );
end;
$$;

revoke all on function private.insert_daily_offer(uuid, date, text, smallint) from public, anon, authenticated;

create or replace function private.ensure_daily_missions(uid uuid, at timestamptz)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  today date := (at at time zone 'utc')::date;
  rec record;
begin
  delete from public.daily_missions
  where user_id = uid
    and day < today
    and status in ('active', 'ready');

  if exists (select 1 from public.daily_missions where user_id = uid and day = today) then
    return;
  end if;

  for rec in
    select slot, row_number() over (order by random())::smallint as sort_order
    from unnest(array['belt', 'spy', 'wave', 'hop']) as slot
  loop
    perform private.insert_daily_offer(uid, today, rec.slot, rec.sort_order);
  end loop;
end;
$$;

revoke all on function private.ensure_daily_missions(uuid, timestamptz) from public, anon, authenticated;

create or replace function private.refresh_daily_missions(uid uuid, at timestamptz)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  today date := (at at time zone 'utc')::date;
  stamp timestamptz := private.daily_day_start(today);
  home public.planets%rowtype;
  m public.daily_missions%rowtype;
begin
  select * into home
  from public.planets
  where id = (select home_planet_id from public.empires where user_id = uid);

  for m in
    select * from public.daily_missions
    where user_id = uid and day = today and status = 'active'
  loop
    if m.kind = 'guns' then
      if home.id is not null and coalesce(home.rocket_launcher, 0) >= m.baseline_guns + 20 then
        update public.daily_missions set status = 'ready' where id = m.id;
      end if;
    elsif exists (
      select 1
      from public.battle_reports r
      where r.user_id = uid
        and r.created_at >= stamp
        and private.daily_report_matches(
          m.kind,
          r.title,
          coalesce(r.body, ''),
          m.dest_galaxy,
          m.dest_system,
          m.dest_slot
        )
    ) then
      update public.daily_missions set status = 'ready' where id = m.id;
    elsif m.kind = 'transport' and exists (
      select 1
      from public.battle_reports r
      where r.user_id = uid
        and r.created_at >= stamp
        and r.title = 'Fleet deployed'
    ) then
      update public.daily_missions set status = 'ready' where id = m.id;
    end if;
  end loop;
end;
$$;

revoke all on function private.refresh_daily_missions(uuid, timestamptz) from public, anon, authenticated;

create or replace function private.daily_missions_payload(uid uuid, at timestamptz)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', m.id,
    'day', m.day,
    'slot', m.slot,
    'kind', m.kind,
    'status', m.status,
    'dest_galaxy', m.dest_galaxy,
    'dest_system', m.dest_system,
    'dest_slot', m.dest_slot,
    'title', m.title,
    'blurb', m.blurb,
    'reward_ore', m.reward_ore,
    'reward_crystal', m.reward_crystal,
    'reward_deuterium', m.reward_deuterium,
    'sort_order', m.sort_order
  ) order by m.sort_order, m.id), '[]'::jsonb)
  from public.daily_missions m
  where m.user_id = uid
    and m.day = (at at time zone 'utc')::date
    and m.status in ('active', 'ready');
$$;

revoke all on function private.daily_missions_payload(uuid, timestamptz) from public, anon, authenticated;

create or replace function public.list_daily_missions()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  perform private.catch_up(uid, at);
  perform private.ensure_daily_missions(uid, at);
  perform private.refresh_daily_missions(uid, at);
  return private.daily_missions_payload(uid, at);
end;
$$;

revoke all on function public.list_daily_missions() from public, anon;
grant execute on function public.list_daily_missions() to authenticated;

create or replace function public.claim_daily_mission(p_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  at timestamptz := timezone('utc', now());
  m public.daily_missions%rowtype;
  home public.planets%rowtype;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  perform private.catch_up(uid, at);
  perform private.refresh_daily_missions(uid, at);

  select * into m
  from public.daily_missions
  where id = p_id and user_id = uid and status = 'ready'
  for update;
  if not found then
    raise exception 'Nothing to collect.';
  end if;
  if m.day is distinct from (at at time zone 'utc')::date then
    raise exception 'That contract expired.';
  end if;

  select * into home
  from public.planets
  where id = (select home_planet_id from public.empires where user_id = uid)
  for update;
  if not found then
    raise exception 'No homeworld.';
  end if;

  update public.planets
  set
    ore = least(private.storage_cap(ore_storage), ore + m.reward_ore),
    crystal = least(private.storage_cap(crystal_storage), crystal + m.reward_crystal),
    deuterium = least(private.storage_cap(deuterium_storage), deuterium + m.reward_deuterium)
  where id = home.id;

  update public.daily_missions set status = 'claimed' where id = m.id;
  return private.daily_missions_payload(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.claim_daily_mission(bigint) from public, anon;
grant execute on function public.claim_daily_mission(bigint) to authenticated;

do $$
begin
  if to_regprocedure('public.reset_empire_pre_daily()') is null then
    alter function public.reset_empire() rename to reset_empire_pre_daily;
  end if;
end $$;

create or replace function public.reset_empire()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  result jsonb;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  result := public.reset_empire_pre_daily();
  delete from public.daily_missions where user_id = uid;
  return result;
end;
$$;

revoke all on function public.reset_empire() from public, anon;
grant execute on function public.reset_empire() to authenticated;
revoke all on function public.reset_empire_pre_daily() from public, anon, authenticated;

do $$
begin
  if to_regprocedure('public.delete_own_account_pre_daily(text)') is null then
    alter function public.delete_own_account(text) rename to delete_own_account_pre_daily;
  end if;
end $$;

create or replace function public.delete_own_account(p_confirmation text)
returns void
language plpgsql
security definer
set search_path = public
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
  delete from public.daily_missions where user_id = uid;
  perform public.delete_own_account_pre_daily(p_confirmation);
end;
$$;

revoke all on function public.delete_own_account(text) from public, anon;
grant execute on function public.delete_own_account(text) to authenticated;
revoke all on function public.delete_own_account_pre_daily(text) from public, anon;

notify pgrst, 'reload schema';
