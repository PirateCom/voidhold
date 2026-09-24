create table if not exists public.debris_fields (
  galaxy smallint not null check (galaxy between 1 and 9),
  system smallint not null check (system between 1 and 499),
  slot smallint not null check (slot between 1 and 16),
  ore bigint not null default 0 check (ore >= 0),
  crystal bigint not null default 0 check (crystal >= 0),
  primary key (galaxy, system, slot)
);

alter table public.debris_fields enable row level security;

revoke all on table public.debris_fields from public, anon, authenticated;

create or replace function private.bump_debris(
  p_galaxy smallint,
  p_system smallint,
  p_slot smallint,
  p_ore bigint,
  p_crystal bigint
)
returns void
language plpgsql
set search_path = public
as $$
begin
  if coalesce(p_ore, 0) = 0 and coalesce(p_crystal, 0) = 0 then
    return;
  end if;
  insert into public.debris_fields (galaxy, system, slot, ore, crystal)
  values (p_galaxy, p_system, p_slot, greatest(p_ore, 0), greatest(p_crystal, 0))
  on conflict (galaxy, system, slot)
  do update set
    ore = public.debris_fields.ore + excluded.ore,
    crystal = public.debris_fields.crystal + excluded.crystal;
end;
$$;

revoke all on function private.bump_debris(smallint, smallint, smallint, bigint, bigint) from public, anon, authenticated;

create or replace function private.resolve_pirate_wave(
  p public.planets,
  uid uuid,
  at timestamptz,
  p_ships integer
)
returns public.planets
language plpgsql
set search_path = ''
as $$
declare
  units integer;
  ships integer;
  planet_atk integer;
  planet_def integer;
  pirate_atk integer;
  pirate_def integer;
  pirates_lost integer;
  pirates_left integer;
  before public.planets;
  loot_ore bigint := 0;
  loot_crystal bigint := 0;
  held boolean;
  body text;
  debris_ore bigint;
  debris_crystal bigint;
begin
  before := p;
  units := private.defence_units(p);
  ships := coalesce(nullif(p_ships, 0), private.pirate_wave_size(units));
  planet_atk := private.planet_attack(p);
  planet_def := private.planet_defence(p);
  pirate_atk := ships * 10;
  pirate_def := ships * 20;
  pirates_lost := least(ships, floor(greatest(planet_atk, 0)::numeric / 20)::integer);
  pirates_left := ships - pirates_lost;
  p := private.apply_pirate_damage(p, pirate_atk);
  held := pirates_left <= 0;
  if not held then
    select h.loot_ore, h.loot_crystal
      into loot_ore, loot_crystal
    from private.raid_haul(p.ore, p.crystal, pirates_left * 800) as h;
    p.ore := p.ore - loot_ore;
    p.crystal := p.crystal - loot_crystal;
  end if;

  debris_ore := floor(pirates_lost * 3000 * 0.3)::bigint;
  debris_crystal := floor(pirates_lost * 1000 * 0.3)::bigint;
  if debris_ore + debris_crystal = 0 then
    debris_crystal := 300;
  end if;
  perform private.bump_debris(p.galaxy, p.system, p.slot, debris_ore, debris_crystal);

  body := format(
    '%s pirate hull%s ATK %s DEF %s. Planet ATK %s DEF %s. Destroyed %s pirate%s. Guns lost: %s. Debris +%s ore +%s crystal. %s',
    ships,
    case when ships = 1 then '' else 's' end,
    pirate_atk,
    pirate_def,
    planet_atk,
    planet_def,
    pirates_lost,
    case when pirates_lost = 1 then '' else 's' end,
    private.lost_guns_text(before, p),
    debris_ore,
    debris_crystal,
    case
      when held then 'The hold held.'
      else format('Looted %s ore, %s crystal.', loot_ore, loot_crystal)
    end
  );
  insert into public.battle_reports (user_id, created_at, title, body, loot_ore, loot_crystal)
  values (
    uid,
    at,
    case when held then 'Pirate raid repelled' else 'Pirate raid' end,
    body,
    loot_ore,
    loot_crystal
  );
  return p;
end;
$$;

create or replace function public.get_solar_system(p_galaxy smallint, p_system smallint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  result jsonb;
  star text;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_galaxy < 1 or p_galaxy > 9 or p_system < 1 or p_system > 499 then
    raise exception 'That coordinate is outside the universe.';
  end if;

  select s.star_type into star
  from public.solar_systems s
  where s.galaxy = p_galaxy and s.system = p_system;

  select jsonb_build_object(
    'galaxy', p_galaxy,
    'system', p_system,
    'star_type', coalesce(star, 'medium'),
    'multiplier', private.star_multiplier(coalesce(star, 'medium')),
    'slots', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'slot', sl.slot,
        'kind', case
          when sl.slot = 16 then 'outer'
          when pl.id is null then 'empty'
          when pl.owner_id = uid then 'home'
          when pl.owner_id is not null then 'player'
          else 'npc'
        end,
        'planet_id', pl.id,
        'name', case when sl.slot = 16 then 'Outer space' else pl.name end,
        'owner_name', pf.display_name,
        'debris_ore', coalesce(df.ore, 0),
        'debris_crystal', coalesce(df.crystal, 0)
      ) order by sl.slot), '[]'::jsonb)
      from generate_series(1, 16) as sl(slot)
      left join public.planets pl
        on pl.galaxy = p_galaxy
        and pl.system = p_system
        and pl.slot = sl.slot
        and sl.slot <= 15
      left join public.profiles pf on pf.user_id = pl.owner_id
      left join public.debris_fields df
        on df.galaxy = p_galaxy
        and df.system = p_system
        and df.slot = sl.slot
    )
  )
  into result;

  return result;
end;
$$;

create or replace function private.fleets_raid_debris()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  dest public.planets%rowtype;
begin
  if new.mission = 'return'
    and old.mission = 'attack'
    and coalesce(new.report, '') like 'Raid on%'
  then
    select * into dest from public.planets where id = old.dest_planet_id;
    if found then
      perform private.bump_debris(dest.galaxy, dest.system, dest.slot, 0, 300);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists fleets_raid_debris on public.fleets;
create trigger fleets_raid_debris
after update on public.fleets
for each row
execute function private.fleets_raid_debris();

revoke all on function private.fleets_raid_debris() from public, anon, authenticated;

grant execute on function public.get_solar_system(smallint, smallint) to authenticated;

create or replace function public.reset_empire()
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

  delete from public.fleets
  where owner_id = uid
     or dest_planet_id in (select id from public.planets where owner_id = uid);
  delete from public.battle_reports where user_id = uid;
  delete from public.debris_fields
  where (galaxy, system, slot) in (
    select galaxy, system, slot from public.planets where owner_id = uid
  );

  update public.planets
  set
    ore = 1200,
    crystal = 500,
    deuterium = 0,
    last_harvested_at = at,
    ore_mine = 1,
    crystal_mine = 1,
    deuterium_extractor = 0,
    power_plant = 1,
    fusion_reactor = 0,
    ore_storage = 0,
    crystal_storage = 0,
    deuterium_storage = 0,
    robotics_factory = 0,
    shipyard = 0,
    research_lab = 0,
    alliance_depot = 0,
    missile_silo = 0,
    nanite_factory = 0,
    terraformer = 0,
    lunar_base = 0,
    phalanx_sensor = 0,
    stargate = 0,
    space_station = 0,
    upgrade_building = null,
    upgrade_completes_at = null,
    small_shield_dome = 0,
    large_shield_dome = 0,
    rocket_launcher = 0,
    light_laser = 0,
    heavy_laser = 0,
    ion_cannon = 0,
    gauss_cannon = 0,
    plasma_turret = 0,
    antiballistic_missile = 0,
    interplanetary_missile = 0,
    defence_building = null,
    defences_queued = 0,
    defence_completes_at = null
  where owner_id = uid;

  update public.empires
  set
    propulsion_level = 0,
    energy_tech = 0,
    laser_tech = 0,
    ion_tech = 0,
    hyperspace_tech = 0,
    plasma_tech = 0,
    impulse_drive = 0,
    hyperspace_drive = 0,
    espionage_tech = 0,
    computer_tech = 0,
    astrophysics = 0,
    intergalactic_research_network = 0,
    graviton_tech = 0,
    weapons_tech = 0,
    shielding_tech = 0,
    armour_tech = 0,
    raiders = 0,
    raiders_queued = 0,
    raider_completes_at = null,
    ships = '{}'::jsonb,
    ship_building = null,
    research_tech = null,
    research_completes_at = null,
    next_pirate_at = null
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

