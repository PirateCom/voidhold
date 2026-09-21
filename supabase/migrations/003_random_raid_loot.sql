-- Independent random ore/crystal hauls on NPC raids (25–75% of each stockpile, cargo-capped).

create or replace function private.raid_haul(p_ore bigint, p_crystal bigint, p_cargo bigint)
returns table (loot_ore bigint, loot_crystal bigint)
language plpgsql
volatile
set search_path = ''
as $$
declare
  take_ore bigint;
  take_crystal bigint;
  total bigint;
  cargo bigint := greatest(coalesce(p_cargo, 0), 0);
begin
  take_ore := floor(greatest(coalesce(p_ore, 0), 0) * (0.25 + random() * 0.50))::bigint;
  take_crystal := floor(greatest(coalesce(p_crystal, 0), 0) * (0.25 + random() * 0.50))::bigint;
  total := take_ore + take_crystal;
  if total > cargo and total > 0 then
    take_ore := floor(take_ore::numeric * cargo / total)::bigint;
    take_crystal := least(take_crystal, cargo - take_ore);
  elsif take_ore > cargo then
    take_ore := cargo;
    take_crystal := 0;
  end if;
  loot_ore := take_ore;
  loot_crystal := take_crystal;
  return next;
end;
$$;

create or replace function private.catch_up(uid uuid, at timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  e public.empires%rowtype;
  home public.planets%rowtype;
  dest public.planets%rowtype;
  origin public.planets%rowtype;
  f public.fleets%rowtype;
  loot_ore bigint;
  loot_crystal bigint;
  cargo_left bigint;
  flight integer;
begin
  select * into e from public.empires where user_id = uid for update;
  if not found then
    return;
  end if;

  select * into home from public.planets where id = e.home_planet_id for update;

  if e.research_completes_at is not null and e.research_completes_at <= at then
    e.propulsion_level := e.propulsion_level + 1;
    e.research_completes_at := null;
  end if;

  while e.raiders_queued > 0 and e.raider_completes_at is not null and e.raider_completes_at <= at loop
    e.raiders := e.raiders + 1;
    e.raiders_queued := e.raiders_queued - 1;
    if e.raiders_queued > 0 then
      e.raider_completes_at := e.raider_completes_at + make_interval(secs => 15);
    else
      e.raider_completes_at := null;
    end if;
  end loop;

  loop
    select * into f
    from public.fleets
    where owner_id = uid
      and status = 'en_route'
      and arrives_at <= at
    order by arrives_at
    limit 1
    for update skip locked;

    exit when not found;

    if f.mission = 'attack' then
      select * into dest from public.planets where id = f.dest_planet_id for update;
      dest := private.catch_up_planet(dest, f.arrives_at);
      cargo_left := f.raiders * 5000;
      select h.loot_ore, h.loot_crystal
        into loot_ore, loot_crystal
      from private.raid_haul(dest.ore, dest.crystal, cargo_left) as h;
      dest.ore := dest.ore - loot_ore;
      dest.crystal := dest.crystal - loot_crystal;
      perform private.persist_planet(dest);

      select * into origin from public.planets where id = f.origin_planet_id;
      flight := private.flight_seconds(origin.system, origin.slot, dest.system, dest.slot, e.propulsion_level);

      update public.fleets
      set
        mission = 'return',
        cargo_ore = loot_ore,
        cargo_crystal = loot_crystal,
        arrives_at = f.arrives_at + make_interval(secs => flight),
        report = format('Raid on %s: +%s ore, +%s crystal.', dest.name, loot_ore, loot_crystal)
      where id = f.id;
    else
      select * into origin from public.planets where id = f.origin_planet_id for update;
      origin := private.catch_up_planet(origin, f.arrives_at);
      origin.ore := least(private.storage_cap(origin.ore_mine), origin.ore + f.cargo_ore);
      origin.crystal := least(private.storage_cap(origin.crystal_mine), origin.crystal + f.cargo_crystal);
      perform private.persist_planet(origin);

      e.raiders := e.raiders + f.raiders;
      if origin.id = home.id then
        home := origin;
      end if;

      update public.fleets
      set status = 'completed'
      where id = f.id;

      insert into public.battle_reports (user_id, title, body, loot_ore, loot_crystal)
      values (
        uid,
        'Fleet returned',
        coalesce(f.report, 'The raiders dumped their holds.'),
        f.cargo_ore,
        f.cargo_crystal
      );
    end if;
  end loop;

  home := private.catch_up_planet(home, at);
  perform private.persist_planet(home);

  update public.empires
  set
    propulsion_level = e.propulsion_level,
    raiders = e.raiders,
    raiders_queued = e.raiders_queued,
    raider_completes_at = e.raider_completes_at,
    research_completes_at = e.research_completes_at
  where user_id = uid;
end;
$$;

revoke all on function private.raid_haul(bigint, bigint, bigint) from public, anon, authenticated;
revoke all on function private.catch_up(uuid, timestamptz) from public, anon, authenticated;
