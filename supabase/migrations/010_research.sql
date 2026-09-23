-- Research technologies from the sprite row. Combustion drive stays in propulsion_level.

alter table public.empires
  add column if not exists energy_tech smallint not null default 0,
  add column if not exists laser_tech smallint not null default 0,
  add column if not exists ion_tech smallint not null default 0,
  add column if not exists hyperspace_tech smallint not null default 0,
  add column if not exists plasma_tech smallint not null default 0,
  add column if not exists impulse_drive smallint not null default 0,
  add column if not exists hyperspace_drive smallint not null default 0,
  add column if not exists espionage_tech smallint not null default 0,
  add column if not exists computer_tech smallint not null default 0,
  add column if not exists astrophysics smallint not null default 0,
  add column if not exists intergalactic_research_network smallint not null default 0,
  add column if not exists graviton_tech smallint not null default 0,
  add column if not exists weapons_tech smallint not null default 0,
  add column if not exists shielding_tech smallint not null default 0,
  add column if not exists armour_tech smallint not null default 0,
  add column if not exists research_tech text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'empires_energy_tech_check') then
    alter table public.empires add constraint empires_energy_tech_check check (energy_tech >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'empires_laser_tech_check') then
    alter table public.empires add constraint empires_laser_tech_check check (laser_tech >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'empires_ion_tech_check') then
    alter table public.empires add constraint empires_ion_tech_check check (ion_tech >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'empires_hyperspace_tech_check') then
    alter table public.empires add constraint empires_hyperspace_tech_check check (hyperspace_tech >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'empires_plasma_tech_check') then
    alter table public.empires add constraint empires_plasma_tech_check check (plasma_tech >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'empires_impulse_drive_check') then
    alter table public.empires add constraint empires_impulse_drive_check check (impulse_drive >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'empires_hyperspace_drive_check') then
    alter table public.empires add constraint empires_hyperspace_drive_check check (hyperspace_drive >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'empires_espionage_tech_check') then
    alter table public.empires add constraint empires_espionage_tech_check check (espionage_tech >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'empires_computer_tech_check') then
    alter table public.empires add constraint empires_computer_tech_check check (computer_tech >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'empires_astrophysics_check') then
    alter table public.empires add constraint empires_astrophysics_check check (astrophysics >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'empires_irn_check') then
    alter table public.empires add constraint empires_irn_check check (intergalactic_research_network >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'empires_graviton_tech_check') then
    alter table public.empires add constraint empires_graviton_tech_check check (graviton_tech >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'empires_weapons_tech_check') then
    alter table public.empires add constraint empires_weapons_tech_check check (weapons_tech >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'empires_shielding_tech_check') then
    alter table public.empires add constraint empires_shielding_tech_check check (shielding_tech >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'empires_armour_tech_check') then
    alter table public.empires add constraint empires_armour_tech_check check (armour_tech >= 0);
  end if;
end $$;

alter table public.empires drop constraint if exists empires_research_tech_check;
alter table public.empires add constraint empires_research_tech_check check (
  research_tech is null or research_tech in (
    'energy_tech',
    'laser_tech',
    'ion_tech',
    'hyperspace_tech',
    'plasma_tech',
    'combustion_drive',
    'impulse_drive',
    'hyperspace_drive',
    'espionage_tech',
    'computer_tech',
    'astrophysics',
    'intergalactic_research_network',
    'graviton_tech',
    'weapons_tech',
    'shielding_tech',
    'armour_tech'
  )
);

update public.empires
set research_tech = 'combustion_drive'
where research_completes_at is not null and research_tech is null;

create or replace function private.research_level(e public.empires, id text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case id
    when 'energy_tech' then e.energy_tech
    when 'laser_tech' then e.laser_tech
    when 'ion_tech' then e.ion_tech
    when 'hyperspace_tech' then e.hyperspace_tech
    when 'plasma_tech' then e.plasma_tech
    when 'combustion_drive' then e.propulsion_level
    when 'impulse_drive' then e.impulse_drive
    when 'hyperspace_drive' then e.hyperspace_drive
    when 'espionage_tech' then e.espionage_tech
    when 'computer_tech' then e.computer_tech
    when 'astrophysics' then e.astrophysics
    when 'intergalactic_research_network' then e.intergalactic_research_network
    when 'graviton_tech' then e.graviton_tech
    when 'weapons_tech' then e.weapons_tech
    when 'shielding_tech' then e.shielding_tech
    when 'armour_tech' then e.armour_tech
    else 0
  end;
$$;

create or replace function private.research_tech_cost_ore(id text, current_level integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select floor((case id
    when 'energy_tech' then 0
    when 'laser_tech' then 100
    when 'ion_tech' then 200
    when 'hyperspace_tech' then 0
    when 'plasma_tech' then 250
    when 'combustion_drive' then 200
    when 'impulse_drive' then 400
    when 'hyperspace_drive' then 800
    when 'espionage_tech' then 100
    when 'computer_tech' then 0
    when 'astrophysics' then 500
    when 'intergalactic_research_network' then 800
    when 'graviton_tech' then 0
    when 'weapons_tech' then 200
    when 'shielding_tech' then 80
    when 'armour_tech' then 250
    else 0
  end) * power(2, greatest(current_level, 0)))::bigint;
$$;

create or replace function private.research_tech_cost_crystal(id text, current_level integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select floor((case id
    when 'energy_tech' then 200
    when 'laser_tech' then 50
    when 'ion_tech' then 80
    when 'hyperspace_tech' then 400
    when 'plasma_tech' then 500
    when 'combustion_drive' then 400
    when 'impulse_drive' then 800
    when 'hyperspace_drive' then 1600
    when 'espionage_tech' then 250
    when 'computer_tech' then 200
    when 'astrophysics' then 1000
    when 'intergalactic_research_network' then 1200
    when 'graviton_tech' then 2000
    when 'weapons_tech' then 80
    when 'shielding_tech' then 200
    when 'armour_tech' then 0
    else 0
  end) * power(2, greatest(current_level, 0)))::bigint;
$$;

create or replace function private.apply_research(e public.empires, id text)
returns public.empires
language plpgsql
set search_path = ''
as $$
begin
  if id = 'energy_tech' then
    e.energy_tech := e.energy_tech + 1;
  elsif id = 'laser_tech' then
    e.laser_tech := e.laser_tech + 1;
  elsif id = 'ion_tech' then
    e.ion_tech := e.ion_tech + 1;
  elsif id = 'hyperspace_tech' then
    e.hyperspace_tech := e.hyperspace_tech + 1;
  elsif id = 'plasma_tech' then
    e.plasma_tech := e.plasma_tech + 1;
  elsif id = 'impulse_drive' then
    e.impulse_drive := e.impulse_drive + 1;
  elsif id = 'hyperspace_drive' then
    e.hyperspace_drive := e.hyperspace_drive + 1;
  elsif id = 'espionage_tech' then
    e.espionage_tech := e.espionage_tech + 1;
  elsif id = 'computer_tech' then
    e.computer_tech := e.computer_tech + 1;
  elsif id = 'astrophysics' then
    e.astrophysics := e.astrophysics + 1;
  elsif id = 'intergalactic_research_network' then
    e.intergalactic_research_network := e.intergalactic_research_network + 1;
  elsif id = 'graviton_tech' then
    e.graviton_tech := e.graviton_tech + 1;
  elsif id = 'weapons_tech' then
    e.weapons_tech := e.weapons_tech + 1;
  elsif id = 'shielding_tech' then
    e.shielding_tech := e.shielding_tech + 1;
  elsif id = 'armour_tech' then
    e.armour_tech := e.armour_tech + 1;
  else
    e.propulsion_level := e.propulsion_level + 1;
  end if;
  e.research_tech := null;
  e.research_completes_at := null;
  return e;
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
  waves integer;
begin
  select * into e from public.empires where user_id = uid for update;
  if not found then
    return;
  end if;

  select * into home from public.planets where id = e.home_planet_id for update;

  if e.research_completes_at is not null and e.research_completes_at <= at then
    e := private.apply_research(e, coalesce(e.research_tech, 'combustion_drive'));
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
      flight := private.flight_seconds(
        origin.system,
        origin.slot,
        dest.system,
        dest.slot,
        e.propulsion_level,
        origin.galaxy,
        dest.galaxy
      );

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
      origin.ore := least(private.storage_cap(origin.ore_storage), origin.ore + f.cargo_ore);
      origin.crystal := least(private.storage_cap(origin.crystal_storage), origin.crystal + f.cargo_crystal);
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

  if e.next_pirate_at is null then
    e.next_pirate_at := at + make_interval(secs => private.pirate_interval_seconds(private.defence_units(home)));
  else
    waves := 0;
    while e.next_pirate_at is not null and e.next_pirate_at <= at and waves < 8 loop
      home := private.resolve_pirate_wave(home, uid, e.next_pirate_at);
      e.next_pirate_at := e.next_pirate_at + make_interval(secs => private.pirate_interval_seconds(private.defence_units(home)));
      waves := waves + 1;
    end loop;
    if e.next_pirate_at is not null and e.next_pirate_at <= at then
      e.next_pirate_at := at + make_interval(secs => private.pirate_interval_seconds(private.defence_units(home)));
    end if;
  end if;

  perform private.persist_planet(home);

  update public.empires
  set
    propulsion_level = e.propulsion_level,
    energy_tech = e.energy_tech,
    laser_tech = e.laser_tech,
    ion_tech = e.ion_tech,
    hyperspace_tech = e.hyperspace_tech,
    plasma_tech = e.plasma_tech,
    impulse_drive = e.impulse_drive,
    hyperspace_drive = e.hyperspace_drive,
    espionage_tech = e.espionage_tech,
    computer_tech = e.computer_tech,
    astrophysics = e.astrophysics,
    intergalactic_research_network = e.intergalactic_research_network,
    graviton_tech = e.graviton_tech,
    weapons_tech = e.weapons_tech,
    shielding_tech = e.shielding_tech,
    armour_tech = e.armour_tech,
    raiders = e.raiders,
    raiders_queued = e.raiders_queued,
    raider_completes_at = e.raider_completes_at,
    research_tech = e.research_tech,
    research_completes_at = e.research_completes_at,
    next_pirate_at = e.next_pirate_at
  where user_id = uid;
end;
$$;

drop function if exists public.start_research();

create or replace function public.start_research(p_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  e public.empires%rowtype;
  home public.planets%rowtype;
  at timestamptz := timezone('utc', now());
  cost_ore bigint;
  cost_crystal bigint;
  lvl integer;
  valid boolean;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  valid := p_id in (
    'energy_tech',
    'laser_tech',
    'ion_tech',
    'hyperspace_tech',
    'plasma_tech',
    'combustion_drive',
    'impulse_drive',
    'hyperspace_drive',
    'espionage_tech',
    'computer_tech',
    'astrophysics',
    'intergalactic_research_network',
    'graviton_tech',
    'weapons_tech',
    'shielding_tech',
    'armour_tech'
  );
  if not valid then
    raise exception 'Unknown research.';
  end if;

  perform private.catch_up(uid, at);
  select * into e from public.empires where user_id = uid for update;
  select * into home from public.planets where id = e.home_planet_id for update;

  if e.research_completes_at is not null then
    raise exception 'Research already running.';
  end if;

  lvl := private.research_level(e, p_id);
  cost_ore := private.research_tech_cost_ore(p_id, lvl);
  cost_crystal := private.research_tech_cost_crystal(p_id, lvl);
  if home.ore < cost_ore or home.crystal < cost_crystal then
    raise exception 'Not enough resources.';
  end if;

  update public.planets
  set ore = home.ore - cost_ore, crystal = home.crystal - cost_crystal
  where id = home.id;

  update public.empires
  set
    research_tech = p_id,
    research_completes_at = at + make_interval(secs => private.research_time_seconds(lvl))
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function public.start_research(text) from public, anon;
grant execute on function public.start_research(text) to authenticated;

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

  delete from public.fleets where owner_id = uid;
  delete from public.battle_reports where user_id = uid;

  update public.planets
  set
    ore = 1200,
    crystal = 500,
    last_harvested_at = at,
    ore_mine = 1,
    crystal_mine = 1,
    power_plant = 1,
    ore_storage = 0,
    crystal_storage = 0,
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
    research_tech = null,
    research_completes_at = null,
    next_pirate_at = null
  where user_id = uid;

  return private.empire_state_json(uid, timezone('utc', now()));
end;
$$;

revoke all on function private.research_level(public.empires, text) from public, anon, authenticated;
revoke all on function private.research_tech_cost_ore(text, integer) from public, anon, authenticated;
revoke all on function private.research_tech_cost_crystal(text, integer) from public, anon, authenticated;
revoke all on function private.apply_research(public.empires, text) from public, anon, authenticated;
