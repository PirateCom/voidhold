import { FACILITIES, RESEARCHES, SHIPS, type FacilityId, type ResearchId, type ShipStat, type TechRequirement } from "./ogame-data";

export const GALAXY = 1;
export const SYSTEM_MAX = 10;
export const SLOT_MAX = 10;

/** One game-hour of production elapses every 60 real seconds. */
export const GAME_HOUR_SECONDS = 60;

export const RAID_LOOT_MIN = 0.25;
export const RAID_LOOT_MAX = 0.75;
export type { FacilityId, FacilityRequirement, FacilityStat, ResearchGroup, ResearchId, ShipResearch, ShipStat, TechRequirement } from "./ogame-data";
export { FACILITIES, RESEARCH_GROUPS, RESEARCHES, SHIPS } from "./ogame-data";

const SMALL_CARGO = SHIPS.find((ship) => ship.id === "small_cargo") as ShipStat;
export const RAIDER_CARGO = SMALL_CARGO.cargo;
export const RAIDER_COST = { ore: SMALL_CARGO.cost.ore, crystal: SMALL_CARGO.cost.crystal } as const;
export const RAIDER_BUILD_SECONDS = 15;

export function shipSpec(id: string): ShipStat | undefined {
  return SHIPS.find((ship) => ship.id === id);
}

export const STARTING_ORE = 1200;
export const STARTING_CRYSTAL = 500;
export const STARTING_RAIDERS = 0;

export type BuildingId =
  | "ore_mine"
  | "crystal_mine"
  | "deuterium_extractor"
  | "power_plant"
  | "fusion_reactor"
  | "ore_storage"
  | "crystal_storage"
  | "deuterium_storage"
  | FacilityId;

export type ResourceBuildingId =
  | "ore_mine"
  | "crystal_mine"
  | "deuterium_extractor"
  | "ore_storage"
  | "crystal_storage"
  | "deuterium_storage"
  | "power_plant"
  | "fusion_reactor";

export type DefenceId =
  | "small_shield_dome"
  | "large_shield_dome"
  | "rocket_launcher"
  | "light_laser"
  | "heavy_laser"
  | "gauss_cannon"
  | "ion_cannon"
  | "plasma_turret"
  | "antiballistic_missile"
  | "interplanetary_missile";

export type DefenceGroup = "dome" | "turret" | "missile";

export const DEFENCE_GROUPS: { id: DefenceGroup; title: string }[] = [
  { id: "dome", title: "Domes" },
  { id: "turret", title: "Turrets" },
  { id: "missile", title: "Missiles" },
];

export const BUILDINGS: {
  id: ResourceBuildingId;
  name: string;
  blurb: string;
}[] = [
  { id: "ore_mine", name: "Ore mine", blurb: "Pulls metal from the crust." },
  { id: "crystal_mine", name: "Crystal mine", blurb: "Cuts lattice from the ice." },
  { id: "deuterium_extractor", name: "Deuterium extractor", blurb: "The wiki synthesizer. Colder worlds make more deuterium. Draws energy." },
  { id: "ore_storage", name: "Ore storage", blurb: "Raises the ore hold. Does not draw energy." },
  { id: "crystal_storage", name: "Crystal storage", blurb: "Raises the crystal hold. Does not draw energy." },
  { id: "deuterium_storage", name: "Deuterium storage", blurb: "The wiki deuterium tank. Caps deuterium like the metal and crystal holds." },
  { id: "power_plant", name: "Solar plant", blurb: "Feeds the mines. Shortfalls slow production." },
  { id: "fusion_reactor", name: "Fusion reactor", blurb: "Burns deuterium for energy. Needs Energy technology 3 and Deuterium extractor 5." },
];

export const DEFENCES: {
  id: DefenceId;
  name: string;
  blurb: string;
  group: DefenceGroup;
  unique: boolean;
  tier: number | null;
  hull: number;
  shield: number;
  attack: number;
  cost: { ore: number; crystal: number; deuterium: number };
  buildSeconds: number;
  shipyard: number;
  silo: number;
  research: TechRequirement[];
}[] = [
  {
    id: "small_shield_dome",
    name: "Small shield dome",
    blurb: "One screen around the hold. Unique.",
    group: "dome",
    unique: true,
    tier: null,
    hull: 20000,
    shield: 2000,
    attack: 1,
    cost: { ore: 10000, crystal: 10000, deuterium: 0 },
    buildSeconds: 30,
    shipyard: 1,
    silo: 0,
    research: [{ id: "shielding_tech", level: 2 }],
  },
  {
    id: "large_shield_dome",
    name: "Large shield dome",
    blurb: "A heavier screen. Unique.",
    group: "dome",
    unique: true,
    tier: null,
    hull: 100000,
    shield: 10000,
    attack: 1,
    cost: { ore: 50000, crystal: 50000, deuterium: 0 },
    buildSeconds: 75,
    shipyard: 6,
    silo: 0,
    research: [{ id: "shielding_tech", level: 6 }],
  },
  {
    id: "rocket_launcher",
    name: "Rocket launcher",
    blurb: "Tier 1 turret. Cheap volley fire.",
    group: "turret",
    unique: false,
    tier: 1,
    hull: 2000,
    shield: 20,
    attack: 80,
    cost: { ore: 2000, crystal: 0, deuterium: 0 },
    buildSeconds: 10,
    shipyard: 1,
    silo: 0,
    research: [],
  },
  {
    id: "light_laser",
    name: "Light laser turret",
    blurb: "Tier 2 turret. Fast crystal beams.",
    group: "turret",
    unique: false,
    tier: 2,
    hull: 2000,
    shield: 25,
    attack: 100,
    cost: { ore: 1500, crystal: 500, deuterium: 0 },
    buildSeconds: 14,
    shipyard: 2,
    silo: 0,
    research: [
      { id: "energy_tech", level: 1 },
      { id: "laser_tech", level: 3 },
    ],
  },
  {
    id: "heavy_laser",
    name: "Heavy laser turret",
    blurb: "Tier 3 turret. Harder burn.",
    group: "turret",
    unique: false,
    tier: 3,
    hull: 8000,
    shield: 100,
    attack: 250,
    cost: { ore: 6000, crystal: 2000, deuterium: 0 },
    buildSeconds: 22,
    shipyard: 4,
    silo: 0,
    research: [
      { id: "energy_tech", level: 3 },
      { id: "laser_tech", level: 6 },
    ],
  },
  {
    id: "gauss_cannon",
    name: "Gaussian cannon turret",
    blurb: "Kinetic turret. Highest punch.",
    group: "turret",
    unique: false,
    tier: 5,
    hull: 35000,
    shield: 200,
    attack: 1100,
    cost: { ore: 20000, crystal: 15000, deuterium: 2000 },
    buildSeconds: 45,
    shipyard: 6,
    silo: 0,
    research: [
      { id: "energy_tech", level: 6 },
      { id: "weapons_tech", level: 3 },
      { id: "shielding_tech", level: 1 },
    ],
  },
  {
    id: "ion_cannon",
    name: "Ion cannon",
    blurb: "Crystal-heavy disruptor.",
    group: "turret",
    unique: false,
    tier: 4,
    hull: 8000,
    shield: 500,
    attack: 150,
    cost: { ore: 5000, crystal: 3000, deuterium: 0 },
    buildSeconds: 28,
    shipyard: 4,
    silo: 0,
    research: [{ id: "ion_tech", level: 4 }],
  },
  {
    id: "plasma_turret",
    name: "Plasma turret",
    blurb: "Heaviest battery.",
    group: "turret",
    unique: false,
    tier: 6,
    hull: 100000,
    shield: 300,
    attack: 3000,
    cost: { ore: 50000, crystal: 50000, deuterium: 30000 },
    buildSeconds: 70,
    shipyard: 8,
    silo: 0,
    research: [{ id: "plasma_tech", level: 7 }],
  },
  {
    id: "antiballistic_missile",
    name: "Antiballistic missile",
    blurb: "Stops one incoming interplanetary missile.",
    group: "missile",
    unique: false,
    tier: null,
    hull: 8000,
    shield: 1,
    attack: 1,
    cost: { ore: 8000, crystal: 0, deuterium: 2000 },
    buildSeconds: 16,
    shipyard: 1,
    silo: 2,
    research: [],
  },
  {
    id: "interplanetary_missile",
    name: "Interplanetary missile",
    blurb: "Strikes guns on another hold.",
    group: "missile",
    unique: false,
    tier: null,
    hull: 15000,
    shield: 1,
    attack: 12000,
    cost: { ore: 12500, crystal: 2500, deuterium: 10000 },
    buildSeconds: 32,
    shipyard: 1,
    silo: 4,
    research: [{ id: "impulse_drive", level: 1 }],
  },
];

export const PIRATE_ATTACK = 10;
export const PIRATE_DEFENCE = 20;
export const PIRATE_CARGO = 800;
export const PIRATE_HOUR_SECONDS = 3600;
export const PIRATE_FLIGHT_SECONDS = 600;
/** Wiki: 30% of wrecked ships' metal and crystal. Deuterium never enters the field. */
export const DEBRIS_RATIO = 0.3;
/** Wiki: fields of 300 or less stay hidden on the galaxy map. */
export const DEBRIS_VISIBLE_MIN = 300;
/** Wiki: a fight with no wrecks still leaves 300 crystal (invisible). */
export const EMPTY_BATTLE_DEBRIS_CRYSTAL = 300;
export const PIRATE_WAVE_CAP = 8;

export function isInboundFleet(
  fleet: { owner_id?: string | null; dest_planet_id?: number | null; inbound?: boolean },
  userId: string,
  homeId: number,
): boolean {
  if (fleet.inbound != null) return fleet.inbound;
  return fleet.dest_planet_id === homeId && fleet.owner_id !== userId;
}
export const DESTROY_ORDER: DefenceId[] = [
  "rocket_launcher",
  "light_laser",
  "heavy_laser",
  "ion_cannon",
  "gauss_cannon",
  "plasma_turret",
  "antiballistic_missile",
  "interplanetary_missile",
  "small_shield_dome",
  "large_shield_dome",
];

const DEFENCE_BY_ID = Object.fromEntries(DEFENCES.map((d) => [d.id, d])) as Record<DefenceId, (typeof DEFENCES)[number]>;

export function isDefenceId(id: string): id is DefenceId {
  return id in DEFENCE_BY_ID;
}

export function defenceSpec(id: DefenceId) {
  return DEFENCE_BY_ID[id];
}

export function defenceCost(id: DefenceId): { ore: number; crystal: number; deuterium: number } {
  return DEFENCE_BY_ID[id].cost;
}

export function defenceTimeSeconds(id: DefenceId): number {
  return DEFENCE_BY_ID[id].buildSeconds;
}

export type DefenceCounts = Record<DefenceId, number>;

export function emptyDefenceCounts(): DefenceCounts {
  return {
    small_shield_dome: 0,
    large_shield_dome: 0,
    rocket_launcher: 0,
    light_laser: 0,
    heavy_laser: 0,
    gauss_cannon: 0,
    ion_cannon: 0,
    plasma_turret: 0,
    antiballistic_missile: 0,
    interplanetary_missile: 0,
  };
}

export function defenceUnitCount(counts: DefenceCounts): number {
  return DEFENCES.reduce((sum, d) => sum + Math.max(0, counts[d.id] ?? 0), 0);
}

export function planetAttack(counts: DefenceCounts): number {
  return DEFENCES.reduce((sum, d) => sum + Math.max(0, counts[d.id] ?? 0) * d.attack, 0);
}

export function planetHull(counts: DefenceCounts): number {
  return DEFENCES.reduce((sum, d) => sum + Math.max(0, counts[d.id] ?? 0) * d.hull, 0);
}

export function planetDefence(counts: DefenceCounts): number {
  return DEFENCES.reduce((sum, d) => sum + Math.max(0, counts[d.id] ?? 0) * d.shield, 0);
}

/** 1–2 waves per real hour; more guns pull the second wave. */
export function pirateWavesPerHour(units: number): number {
  if (units <= 0) return 1;
  return Math.min(2, 1 + units / 8);
}

export function debrisFromWrecks(shipsLost: number, hullOre: number, hullCrystal: number): { ore: number; crystal: number } {
  const ore = Math.floor(Math.max(0, shipsLost) * hullOre * DEBRIS_RATIO);
  const crystal = Math.floor(Math.max(0, shipsLost) * hullCrystal * DEBRIS_RATIO);
  if (ore + crystal === 0) return { ore: 0, crystal: EMPTY_BATTLE_DEBRIS_CRYSTAL };
  return { ore, crystal };
}

export function debrisVisible(ore: number, crystal: number): boolean {
  return ore + crystal > DEBRIS_VISIBLE_MIN;
}

export function pirateIntervalSeconds(units: number, roll = Math.random()): number {
  const base = PIRATE_HOUR_SECONDS / pirateWavesPerHour(units);
  return Math.max(900, Math.floor(base * (0.85 + roll * 0.3)));
}

export function pirateWaveSize(units: number, roll = Math.random()): number {
  const extra = roll >= 0.5 ? 1 : 0;
  return Math.max(1, units + extra);
}

export function piratesDestroyed(planetAtk: number, pirateCount: number): number {
  if (pirateCount <= 0 || PIRATE_DEFENCE <= 0) return 0;
  return Math.min(pirateCount, Math.floor(Math.max(0, planetAtk) / PIRATE_DEFENCE));
}

export function applyPirateDamage(
  counts: DefenceCounts,
  damage: number,
): { counts: DefenceCounts; lost: Partial<Record<DefenceId, number>> } {
  const next = { ...counts };
  const lost: Partial<Record<DefenceId, number>> = {};
  let remaining = Math.max(0, damage);
  for (const id of DESTROY_ORDER) {
    const spec = DEFENCE_BY_ID[id];
    if (spec.shield <= 0) continue;
    while (next[id] > 0 && remaining >= spec.shield) {
      next[id] -= 1;
      lost[id] = (lost[id] ?? 0) + 1;
      remaining -= spec.shield;
    }
  }
  return { counts: next, lost };
}

export function pirateCombat(
  counts: DefenceCounts,
  pirateCount: number,
  ore: number,
  crystal: number,
  oreRoll = Math.random(),
  crystalRoll = Math.random(),
): {
  counts: DefenceCounts;
  piratesLost: number;
  piratesLeft: number;
  lost: Partial<Record<DefenceId, number>>;
  loot: { ore: number; crystal: number };
  planetAtk: number;
  planetDef: number;
  pirateAtk: number;
  pirateDef: number;
} {
  const ships = Math.max(1, pirateCount);
  const planetAtk = planetAttack(counts);
  const planetDef = planetDefence(counts);
  const pirateAtk = ships * PIRATE_ATTACK;
  const pirateDef = ships * PIRATE_DEFENCE;
  const piratesLost = piratesDestroyed(planetAtk, ships);
  const piratesLeft = ships - piratesLost;
  const damaged = applyPirateDamage(counts, pirateAtk);
  const loot =
    piratesLeft > 0 ? raidHaul(ore, crystal, piratesLeft * PIRATE_CARGO, oreRoll, crystalRoll) : { ore: 0, crystal: 0 };
  return {
    counts: damaged.counts,
    piratesLost,
    piratesLeft,
    lost: damaged.lost,
    loot,
    planetAtk,
    planetDef,
    pirateAtk,
    pirateDef,
  };
}

export function formatLostGuns(lost: Partial<Record<DefenceId, number>>): string {
  const parts = DESTROY_ORDER.filter((id) => (lost[id] ?? 0) > 0).map((id) => {
    const spec = DEFENCE_BY_ID[id];
    const n = lost[id] ?? 0;
    return `${n} ${spec.name}${n === 1 ? "" : "s"}`;
  });
  return parts.length > 0 ? parts.join(", ") : "no guns";
}

export function mineProductionPerHour(level: number): number {
  if (level <= 0) return 0;
  return Math.floor(30 * level * Math.pow(1.1, level));
}

export function crystalProductionPerHour(level: number): number {
  if (level <= 0) return 0;
  return Math.floor(20 * level * Math.pow(1.1, level));
}

/** Wiki synthesizer: floor(10 * L * 1.44^L * (1.36 - 0.004 * Tmax)). */
export function deuteriumProductionPerHour(level: number, tempMax = 30): number {
  const safe = Math.max(0, Math.floor(level));
  if (safe <= 0) return 0;
  const climate = 1.36 - 0.004 * tempMax;
  return Math.max(0, Math.floor(10 * safe * Math.pow(1.44, safe) * climate));
}

/** Wiki fusion plant consumption: floor(10 * L * 1.1^L) deut per hour. */
export function fusionDeuteriumBurnPerHour(level: number): number {
  const safe = Math.max(0, Math.floor(level));
  if (safe <= 0) return 0;
  return Math.floor(10 * safe * Math.pow(1.1, safe));
}

export function wikiFlightDistance(
  fromGalaxy: number,
  fromSystem: number,
  fromSlot: number,
  toGalaxy: number,
  toSystem: number,
  toSlot: number,
): number {
  const gal = Math.abs(fromGalaxy - toGalaxy);
  if (gal > 0) return 20000 * gal;
  const sys = Math.abs(fromSystem - toSystem);
  if (sys > 0) return 2700 + 95 * sys;
  const slot = Math.abs(fromSlot - toSlot);
  if (slot > 0) return 1000 + 5 * slot;
  return 5;
}

export function hullFuelUse(shipId: string, impulseLevel = 0): number {
  const hull = shipSpec(shipId);
  if (!hull) return 0;
  if (hull.fuelUpgraded != null && impulseLevel >= 5) return hull.fuelUpgraded;
  return hull.fuel;
}

/** One-way wiki fuel at 100% speed: round(ships * consumption * distance / 35000 * 4). */
export function fleetFuelOneWay(ships: number, consumption: number, distance: number): number {
  const n = Math.max(0, Math.trunc(ships));
  const use = Math.max(0, consumption);
  if (n <= 0 || use <= 0) return 0;
  return Math.max(1, Math.round(((n * use * Math.max(1, distance)) / 35000) * 4));
}

export function fleetFuelRoundTrip(
  ships: number,
  fromGalaxy: number,
  fromSystem: number,
  fromSlot: number,
  toGalaxy: number,
  toSystem: number,
  toSlot: number,
  shipId = "small_cargo",
  impulseLevel = 0,
): number {
  const distance = wikiFlightDistance(fromGalaxy, fromSystem, fromSlot, toGalaxy, toSystem, toSlot);
  return 2 * fleetFuelOneWay(ships, hullFuelUse(shipId, impulseLevel), distance);
}

export type StarType = "young_hot" | "medium" | "old_cold" | "pulsar";

export function starMultiplier(star: StarType = "medium"): number {
  if (star === "young_hot") return 1.5;
  if (star === "old_cold") return 0.75;
  if (star === "pulsar") return 3;
  return 1;
}

export function starLabel(star: StarType): string {
  if (star === "young_hot") return "Young hot star";
  if (star === "old_cold") return "Old cold star";
  if (star === "pulsar") return "Pulsar";
  return "Medium star";
}

export function powerOutput(level: number, star: StarType = "medium"): number {
  if (level <= 0) return 0;
  return Math.floor(20 * level * Math.pow(1.1, level) * starMultiplier(star));
}

export function mineEnergyDrain(level: number): number {
  if (level <= 0) return 0;
  return Math.floor(10 * level * Math.pow(1.1, level));
}

/** Wiki v1.0: floor((average temperature + 160) / 6), then the system star bonus. */
export function solarSatelliteEnergy(
  tempMin: number,
  tempMax: number,
  star: StarType = "medium",
  count = 1,
): number {
  const sats = Math.max(0, Math.floor(count));
  if (sats <= 0) return 0;
  const avg = (tempMin + tempMax) / 2;
  const per = Math.max(0, Math.floor((avg + 160) / 6));
  return Math.floor(per * starMultiplier(star)) * sats;
}

export function energyFactor(
  oreMine: number,
  crystalMine: number,
  powerPlant: number,
  star: StarType = "medium",
  deutMine = 0,
  fusion = 0,
  energyTech = 0,
  satellites = 0,
  tempMin = 30,
  tempMax = 30,
): number {
  return energyNow(
    oreMine,
    crystalMine,
    powerPlant,
    star,
    deutMine,
    fusion,
    energyTech,
    satellites,
    tempMin,
    tempMax,
  ).factor;
}

export function fusionOutput(level: number, energyTech = 0): number {
  const safe = Math.max(0, Math.floor(level));
  if (safe <= 0) return 0;
  return Math.floor(30 * safe * Math.pow(1.05 + 0.01 * Math.max(0, energyTech), safe));
}

export function deutEnergyDrain(level: number): number {
  const safe = Math.max(0, Math.floor(level));
  if (safe <= 0) return 0;
  return Math.floor(20 * safe * Math.pow(1.1, safe));
}

export function energyNow(
  oreMine: number,
  crystalMine: number,
  powerPlant: number,
  star: StarType = "medium",
  deutMine = 0,
  fusion = 0,
  energyTech = 0,
  satellites = 0,
  tempMin = 30,
  tempMax = 30,
): {
  output: number;
  drain: number;
  factor: number;
} {
  const output =
    powerOutput(powerPlant, star) +
    fusionOutput(fusion, energyTech) +
    solarSatelliteEnergy(tempMin, tempMax, star, satellites);
  const drain = mineEnergyDrain(oreMine) + mineEnergyDrain(crystalMine) + deutEnergyDrain(deutMine);
  const factor = drain <= 0 ? 1 : Math.min(1, output / drain);
  return { output, drain, factor };
}

/** Extra energy a building uses (mines) or makes (power plant) at the next level. */
export function upgradeEnergyDelta(
  id: BuildingId,
  currentLevel: number,
  star: StarType = "medium",
  energyTech = 0,
): number {
  if (id === "ore_storage" || id === "crystal_storage" || id === "deuterium_storage") return 0;
  if (id === "power_plant") {
    return powerOutput(currentLevel + 1, star) - powerOutput(currentLevel, star);
  }
  if (id === "fusion_reactor") {
    return fusionOutput(currentLevel + 1, energyTech) - fusionOutput(currentLevel, energyTech);
  }
  if (id === "deuterium_extractor") {
    return deutEnergyDrain(currentLevel + 1) - deutEnergyDrain(currentLevel);
  }
  if (id !== "ore_mine" && id !== "crystal_mine") return 0;
  return mineEnergyDrain(currentLevel + 1) - mineEnergyDrain(currentLevel);
}

export function energyAfterUpgrade(
  id: BuildingId,
  oreMine: number,
  crystalMine: number,
  powerPlant: number,
  star: StarType = "medium",
  deutMine = 0,
  fusion = 0,
  energyTech = 0,
  satellites = 0,
  tempMin = 30,
  tempMax = 30,
): { output: number; drain: number; factor: number } {
  const ore = id === "ore_mine" ? oreMine + 1 : oreMine;
  const crystal = id === "crystal_mine" ? crystalMine + 1 : crystalMine;
  const plant = id === "power_plant" ? powerPlant + 1 : powerPlant;
  const deut = id === "deuterium_extractor" ? deutMine + 1 : deutMine;
  const fus = id === "fusion_reactor" ? fusion + 1 : fusion;
  return energyNow(ore, crystal, plant, star, deut, fus, energyTech, satellites, tempMin, tempMax);
}

export function upgradeWouldCauseEnergyDeficit(
  id: BuildingId,
  oreMine: number,
  crystalMine: number,
  powerPlant: number,
  star: StarType = "medium",
  deutMine = 0,
  fusion = 0,
  energyTech = 0,
  satellites = 0,
  tempMin = 30,
  tempMax = 30,
): boolean {
  const after = energyAfterUpgrade(
    id,
    oreMine,
    crystalMine,
    powerPlant,
    star,
    deutMine,
    fusion,
    energyTech,
    satellites,
    tempMin,
    tempMax,
  );
  return after.drain > after.output;
}

/** floor(2.5 * e^((20/33) * level)) * 5000. Level 0 is 10,000. */
export function storageCap(level: number): number {
  const safe = Math.max(0, Math.floor(level));
  return Math.floor(2.5 * Math.exp((20 / 33) * safe)) * 5000;
}

export type ResourceStock = { ore: number; crystal: number; deuterium?: number };

export function canPayResources(have: ResourceStock, cost: ResourceStock, count = 1): boolean {
  const n = Math.max(1, Math.floor(count));
  return (
    have.ore >= (cost.ore ?? 0) * n &&
    have.crystal >= (cost.crystal ?? 0) * n &&
    (have.deuterium ?? 0) >= (cost.deuterium ?? 0) * n
  );
}

export function buildingCost(id: BuildingId, currentLevel: number): { ore: number; crystal: number; deuterium: number } {
  const mul = Math.pow(1.5, currentLevel);
  switch (id) {
    case "ore_mine":
      return { ore: Math.floor(60 * mul), crystal: Math.floor(15 * mul), deuterium: 0 };
    case "crystal_mine":
      return { ore: Math.floor(48 * mul), crystal: Math.floor(24 * mul), deuterium: 0 };
    case "deuterium_extractor":
      return { ore: Math.floor(225 * mul), crystal: Math.floor(75 * mul), deuterium: 0 };
    case "power_plant":
      return { ore: Math.floor(75 * mul), crystal: Math.floor(30 * mul), deuterium: 0 };
    case "fusion_reactor": {
      const fusionMul = Math.pow(1.8, currentLevel);
      return {
        ore: Math.floor(900 * fusionMul),
        crystal: Math.floor(360 * fusionMul),
        deuterium: Math.floor(180 * fusionMul),
      };
    }
    case "ore_storage":
      return { ore: Math.floor(1000 * Math.pow(2, currentLevel)), crystal: 0, deuterium: 0 };
    case "crystal_storage":
      return {
        ore: Math.floor(1000 * Math.pow(2, currentLevel)),
        crystal: Math.floor(500 * Math.pow(2, currentLevel)),
        deuterium: 0,
      };
    case "deuterium_storage":
      return {
        ore: Math.floor(1000 * Math.pow(2, currentLevel)),
        crystal: Math.floor(1000 * Math.pow(2, currentLevel)),
        deuterium: 0,
      };
    default: {
      const spec = FACILITY_BY_ID[id];
      const factor = Math.pow(spec.costFactor, Math.max(0, currentLevel));
      return {
        ore: Math.floor(spec.cost.ore * factor),
        crystal: Math.floor(spec.cost.crystal * factor),
        deuterium: Math.floor(spec.cost.deuterium * factor),
      };
    }
  }
}

export function buildingTimeSeconds(
  currentLevel: number,
  roboticsLevel = 0,
  naniteLevel = 0,
): number {
  const base = Math.floor(20 * Math.pow(1.5, currentLevel));
  const robotics = Math.max(0, Math.trunc(roboticsLevel));
  const nanites = Math.max(0, Math.trunc(naniteLevel));
  return Math.max(1, Math.floor(base / (1 + robotics) / 2 ** nanites));
}

const RESEARCH_BY_ID = Object.fromEntries(RESEARCHES.map((tech) => [tech.id, tech])) as Record<
  ResearchId,
  (typeof RESEARCHES)[number]
>;

const FACILITY_BY_ID = Object.fromEntries(FACILITIES.map((facility) => [facility.id, facility])) as Record<
  FacilityId,
  (typeof FACILITIES)[number]
>;

export function isFacilityId(id: string): id is FacilityId {
  return id in FACILITY_BY_ID;
}

export function isBuildingId(id: string): id is BuildingId {
  return (
    id === "ore_mine" ||
    id === "crystal_mine" ||
    id === "deuterium_extractor" ||
    id === "power_plant" ||
    id === "fusion_reactor" ||
    id === "ore_storage" ||
    id === "crystal_storage" ||
    id === "deuterium_storage" ||
    isFacilityId(id)
  );
}

export function facilitySpec(id: FacilityId) {
  return FACILITY_BY_ID[id];
}

export function unmetFacility(
  id: FacilityId,
  facilityLevelOf: (facility: FacilityId) => number,
  researchLevelOf: (research: ResearchId) => number,
): { name: string; level: number }[] {
  return FACILITY_BY_ID[id].requires
    .filter((req) =>
      req.kind === "facility" ? facilityLevelOf(req.id) < req.level : researchLevelOf(req.id) < req.level,
    )
    .map((req) => ({
      name: req.kind === "facility" ? FACILITY_BY_ID[req.id].name : RESEARCH_BY_ID[req.id].name,
      level: req.level,
    }));
}

/** Wiki: energy is only checked at click. Total production, not leftover after mines. */
export function terraformerEnergy(currentLevel: number): number {
  return Math.floor(1000 * Math.pow(2, Math.max(0, currentLevel)));
}

/** Wiki: extra fields = floor(5.5 × terraformer level). */
export function terraformerExtraFields(level: number): number {
  return Math.floor(5.5 * Math.max(0, Math.trunc(level)));
}

export function terraformerFreeFields(level: number): number {
  const safe = Math.max(0, Math.trunc(level));
  return terraformerExtraFields(safe) - safe;
}

export function planetFieldCap(maxFields: number, terraformerLevel: number): number {
  return maxFields + terraformerExtraFields(terraformerLevel);
}

export function fieldsUsed(
  oreMine: number,
  crystalMine: number,
  powerPlant: number,
  oreStorage = 0,
  crystalStorage = 0,
  facilities = 0,
  deutMine = 0,
  deutStorage = 0,
  fusion = 0,
): number {
  return (
    oreMine +
    crystalMine +
    powerPlant +
    oreStorage +
    crystalStorage +
    facilities +
    deutMine +
    deutStorage +
    fusion
  );
}

export function isResearchId(id: string): id is ResearchId {
  return id in RESEARCH_BY_ID;
}

export function researchSpec(id: ResearchId) {
  return RESEARCH_BY_ID[id];
}

export function researchTechCost(
  id: ResearchId,
  currentLevel: number,
): { ore: number; crystal: number; deuterium: number } {
  const spec = RESEARCH_BY_ID[id];
  const mul = Math.pow(spec.costFactor, Math.max(0, currentLevel));
  return {
    ore: Math.floor(spec.baseOre * mul),
    crystal: Math.floor(spec.baseCrystal * mul),
    deuterium: Math.floor(spec.baseDeuterium * mul),
  };
}

export function unmetShipBuild(
  ship: ShipStat,
  shipyardLevel: number,
  levelOf: (id: ResearchId) => number,
): { name: string; level: number }[] {
  const missing: { name: string; level: number }[] = [];
  if (shipyardLevel < ship.shipyard) {
    missing.push({ name: "Shipyard", level: ship.shipyard });
  }
  for (const req of ship.research) {
    if (req.upgrade) continue;
    if (levelOf(req.id) < req.level) {
      missing.push({ name: RESEARCH_BY_ID[req.id].name, level: req.level });
    }
  }
  return missing;
}

export function unmetDefenceBuild(
  spec: (typeof DEFENCES)[number],
  shipyardLevel: number,
  siloLevel: number,
  levelOf: (id: ResearchId) => number,
): { name: string; level: number }[] {
  const missing: { name: string; level: number }[] = [];
  if (shipyardLevel < spec.shipyard) {
    missing.push({ name: "Shipyard", level: spec.shipyard });
  }
  if (spec.silo > 0 && siloLevel < spec.silo) {
    missing.push({ name: facilitySpec("missile_silo").name, level: spec.silo });
  }
  for (const req of spec.research) {
    if (levelOf(req.id) < req.level) {
      missing.push({ name: RESEARCH_BY_ID[req.id].name, level: req.level });
    }
  }
  return missing;
}

export function unmetResearch(
  id: ResearchId,
  levelOf: (research: ResearchId) => number,
  labLevel: number,
): { id?: ResearchId; level: number; name: string }[] {
  const spec = RESEARCH_BY_ID[id];
  const missing: { id?: ResearchId; level: number; name: string }[] = [];
  if (labLevel < spec.lab) {
    missing.push({ level: spec.lab, name: "Research lab" });
  }
  for (const req of spec.requires) {
    if (levelOf(req.id) < req.level) {
      missing.push({ ...req, name: RESEARCH_BY_ID[req.id].name });
    }
  }
  return missing;
}

export function researchCost(currentLevel: number): { ore: number; crystal: number } {
  return researchTechCost("combustion_drive", currentLevel);
}

export function researchTimeSeconds(currentLevel: number): number {
  return Math.floor(45 * Math.pow(1.5, currentLevel));
}

export function fleetSpeedMultiplier(propulsionLevel: number): number {
  return 1 + 0.1 * propulsionLevel;
}

export function flightSeconds(
  fromSystem: number,
  fromSlot: number,
  toSystem: number,
  toSlot: number,
  propulsionLevel: number,
  fromGalaxy = 0,
  toGalaxy = 0,
): number {
  const distance =
    Math.abs(fromGalaxy - toGalaxy) * 40 + Math.abs(fromSystem - toSystem) + Math.abs(fromSlot - toSlot);
  const raw = 20 + 12 * Math.max(distance, 1);
  return Math.max(15, Math.floor(raw / fleetSpeedMultiplier(propulsionLevel)));
}

export const EXPEDITION_SLOT = 16;
export const EXPEDITION_HOLD_SECONDS = GAME_HOUR_SECONDS;

export function expeditionFlightSeconds(
  fromSystem: number,
  fromSlot: number,
  toSystem: number,
  toSlot: number,
  propulsionLevel: number,
  fromGalaxy = 0,
  toGalaxy = 0,
): number {
  return Math.min(30, flightSeconds(fromSystem, fromSlot, toSystem, toSlot, propulsionLevel, fromGalaxy, toGalaxy));
}

export function expeditionFleetCap(astrophysics: number): number {
  return Math.floor(Math.sqrt(Math.max(0, astrophysics)));
}

export type ExpeditionKind = "nothing" | "resources" | "ships" | "pirates" | "aliens" | "lost" | "delay";

/** Wiki-shaped odds: pirates ~5.6%, aliens ~2.6%, plus finds, delay, and black-hole loss. */
export function rollExpeditionKind(roll: number): ExpeditionKind {
  const t = Math.min(1, Math.max(0, roll));
  if (t < 0.3) return "nothing";
  if (t < 0.58) return "resources";
  if (t < 0.68) return "ships";
  if (t < 0.736) return "pirates";
  if (t < 0.762) return "aliens";
  if (t < 0.79) return "lost";
  if (t < 0.89) return "delay";
  return "nothing";
}

export function expeditionResourceAmount(ships: number, amountRoll: number): number {
  const cargo = Math.max(1, Math.trunc(ships)) * RAIDER_CARGO;
  const fraction = 0.15 + 0.35 * Math.min(1, Math.max(0, amountRoll));
  return Math.max(1, Math.floor(cargo * fraction));
}

/** Wiki base temperatures. A planet adds the same offset, from -10 to 10, to both ends. */
export const SLOT_TEMPERATURE: Record<number, { min: number; max: number }> = {
  1: { min: 200, max: 260 },
  2: { min: 150, max: 190 },
  3: { min: 100, max: 140 },
  4: { min: 50, max: 90 },
  5: { min: 40, max: 80 },
  6: { min: 30, max: 70 },
  7: { min: 20, max: 60 },
  8: { min: 10, max: 50 },
  9: { min: 0, max: 40 },
  10: { min: -10, max: 30 },
  11: { min: -20, max: 20 },
  12: { min: -30, max: 10 },
  13: { min: -70, max: -30 },
  14: { min: -110, max: -70 },
  15: { min: -180, max: -110 },
};

export function planetTemperature(slot: number, offset: number): { min: number; max: number } {
  const base = SLOT_TEMPERATURE[slot] ?? SLOT_TEMPERATURE[8];
  const shift = Math.max(-10, Math.min(10, Math.trunc(offset)));
  return { min: base.min + shift, max: base.max + shift };
}

export function fieldBand(slot: number): { lo: number; hi: number } {
  if (slot <= 3) return { lo: 40, hi: 70 };
  if (slot <= 6) return { lo: 120, hi: 310 };
  if (slot <= 9) return { lo: 125, hi: 255 };
  if (slot <= 12) return { lo: 75, hi: 125 };
  return { lo: 60, hi: 190 };
}

const MIN_FIELDS = 20;

function inclusivePick(lo: number, hi: number, valueRoll: number): number {
  if (hi <= lo) return lo;
  const t = Math.min(1, Math.max(0, valueRoll));
  return lo + Math.min(hi - lo, Math.floor(t * (hi - lo + 1)));
}

/** outerRoll below 0.8 stays in the band. Below 0.9 is the low tail. Otherwise the high tail. */
export function rollMaxFields(slot: number, outerRoll: number, valueRoll: number): number {
  const { lo, hi } = fieldBand(slot);
  const width = hi - lo;
  if (outerRoll < 0.8) return inclusivePick(lo, hi, valueRoll);
  if (outerRoll < 0.9) {
    const lowLo = Math.max(MIN_FIELDS, lo - width);
    const lowHi = lo - 1;
    if (lowHi < lowLo) return inclusivePick(hi + 1, hi + width, valueRoll);
    return inclusivePick(lowLo, lowHi, valueRoll);
  }
  return inclusivePick(hi + 1, hi + width, valueRoll);
}

/** OGame homeworld diameter. Fields are floor((km / 1000)^2) plus the universe bonus. */
export const HOMEWORLD_DIAMETER_KM = 12_800;
export const PLANET_FIELD_BONUS = 10;

export function fieldsFromDiameter(diameterKm: number, bonus = PLANET_FIELD_BONUS): number {
  return Math.floor((diameterKm / 1000) ** 2) + bonus;
}

export function diameterKm(fields: number): number {
  return Math.round(1000 * Math.sqrt(Math.max(fields, 0)));
}

export function harvestAmount(stored: number, perHour: number, elapsedSeconds: number, cap: number): number {
  const add = Math.floor((perHour * Math.max(0, elapsedSeconds)) / GAME_HOUR_SECONDS);
  return Math.min(cap, stored + Math.max(0, add));
}

export function raidLootFraction(roll = Math.random()): number {
  const t = Math.min(1, Math.max(0, roll));
  return RAID_LOOT_MIN + t * (RAID_LOOT_MAX - RAID_LOOT_MIN);
}

export function raidLoot(available: number, cargoLeft: number, roll = Math.random()): number {
  return Math.min(
    Math.max(0, cargoLeft),
    Math.floor(Math.max(0, available) * raidLootFraction(roll)),
  );
}

export function raidHaul(
  ore: number,
  crystal: number,
  cargo: number,
  oreRoll = Math.random(),
  crystalRoll = Math.random(),
): { ore: number; crystal: number } {
  let takeOre = raidLoot(ore, Number.MAX_SAFE_INTEGER, oreRoll);
  let takeCrystal = raidLoot(crystal, Number.MAX_SAFE_INTEGER, crystalRoll);
  const cap = Math.max(0, cargo);
  const total = takeOre + takeCrystal;
  if (total > cap) {
    if (total <= 0) return { ore: 0, crystal: 0 };
    takeOre = Math.floor((takeOre / total) * cap);
    takeCrystal = Math.min(takeCrystal, cap - takeOre);
  }
  return { ore: takeOre, crystal: takeCrystal };
}

export function formatDuration(totalSeconds: number): string {
  const s = Math.max(0, Math.ceil(totalSeconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  if (h > 0) return `${h}h ${String(m).padStart(2, "0")}m`;
  if (m > 0) return `${m}m ${String(sec).padStart(2, "0")}s`;
  return `${sec}s`;
}

/** Server time projected onto the local wall clock after a fetch. */
export function gameClock(serverNow: number | string, fetchedAt: number, wallNow: number): number {
  const server = typeof serverNow === "string" ? new Date(serverNow).getTime() : serverNow;
  if (!Number.isFinite(server) || fetchedAt <= 0) return wallNow;
  return server + (wallNow - fetchedAt);
}

/** 0–1 fraction of a timed job that ends at `completesAt` after `durationMs`. */
export function progressToward(
  completesAt: number | string | null | undefined,
  durationMs: number,
  now: number,
): number {
  if (completesAt == null || durationMs <= 0) return 0;
  const end = typeof completesAt === "string" ? new Date(completesAt).getTime() : completesAt;
  if (!Number.isFinite(end)) return 0;
  const start = end - durationMs;
  if (now >= end) return 1;
  if (now <= start) return 0;
  return (now - start) / durationMs;
}

/** Remaining construction returns this share of the original cost. 50% done → 50% back. */
export function cancelRefund(
  cost: { ore: number; crystal: number; deuterium?: number },
  progress: number,
): { ore: number; crystal: number; deuterium: number } {
  const remaining = 1 - Math.min(1, Math.max(0, progress));
  return {
    ore: Math.floor(cost.ore * remaining),
    crystal: Math.floor(cost.crystal * remaining),
    deuterium: Math.floor((cost.deuterium ?? 0) * remaining),
  };
}
