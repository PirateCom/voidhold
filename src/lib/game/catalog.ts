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
  { id: "deuterium_extractor", name: "Deuterium extractor", blurb: "The wiki synthesizer. Deuterium stays at 0 here." },
  { id: "ore_storage", name: "Ore storage", blurb: "Raises the ore hold. Does not draw energy." },
  { id: "crystal_storage", name: "Crystal storage", blurb: "Raises the crystal hold. Does not draw energy." },
  { id: "deuterium_storage", name: "Deuterium storage", blurb: "The wiki deuterium tank. Unused while deuterium stays at 0." },
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
  attack: number;
  defence: number;
  cost: { ore: number; crystal: number };
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
    attack: 0,
    defence: 200,
    cost: { ore: 800, crystal: 800 },
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
    attack: 0,
    defence: 1000,
    cost: { ore: 4000, crystal: 4000 },
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
    attack: 8,
    defence: 20,
    cost: { ore: 120, crystal: 30 },
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
    attack: 10,
    defence: 25,
    cost: { ore: 180, crystal: 60 },
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
    attack: 25,
    defence: 90,
    cost: { ore: 480, crystal: 160 },
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
    attack: 110,
    defence: 370,
    cost: { ore: 1600, crystal: 1200 },
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
    attack: 15,
    defence: 130,
    cost: { ore: 160, crystal: 480 },
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
    attack: 280,
    defence: 900,
    cost: { ore: 4500, crystal: 4000 },
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
    attack: 0,
    defence: 40,
    cost: { ore: 400, crystal: 0 },
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
    attack: 80,
    defence: 50,
    cost: { ore: 1200, crystal: 400 },
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
export const PIRATE_WAVE_CAP = 8;
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

export function defenceCost(id: DefenceId): { ore: number; crystal: number } {
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

export function planetDefence(counts: DefenceCounts): number {
  return DEFENCES.reduce((sum, d) => sum + Math.max(0, counts[d.id] ?? 0) * d.defence, 0);
}

/** 1–2 waves per real hour; more guns pull the second wave. */
export function pirateWavesPerHour(units: number): number {
  if (units <= 0) return 1;
  return Math.min(2, 1 + units / 8);
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
    if (spec.defence <= 0) continue;
    while (next[id] > 0 && remaining >= spec.defence) {
      next[id] -= 1;
      lost[id] = (lost[id] ?? 0) + 1;
      remaining -= spec.defence;
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

export function energyFactor(
  oreMine: number,
  crystalMine: number,
  powerPlant: number,
  star: StarType = "medium",
  deutMine = 0,
  fusion = 0,
  energyTech = 0,
): number {
  return energyNow(oreMine, crystalMine, powerPlant, star, deutMine, fusion, energyTech).factor;
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
): {
  output: number;
  drain: number;
  factor: number;
} {
  const output = powerOutput(powerPlant, star) + fusionOutput(fusion, energyTech);
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
): { output: number; drain: number; factor: number } {
  if (id === "ore_mine") return energyNow(oreMine + 1, crystalMine, powerPlant, star);
  if (id === "crystal_mine") return energyNow(oreMine, crystalMine + 1, powerPlant, star);
  if (id === "power_plant") return energyNow(oreMine, crystalMine, powerPlant + 1, star);
  return energyNow(oreMine, crystalMine, powerPlant, star);
}

/** floor(2.5 * e^((20/33) * level)) * 5000. Level 0 is 10,000. */
export function storageCap(level: number): number {
  const safe = Math.max(0, Math.floor(level));
  return Math.floor(2.5 * Math.exp((20 / 33) * safe)) * 5000;
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
  cost: { ore: number; crystal: number },
  progress: number,
): { ore: number; crystal: number } {
  const remaining = 1 - Math.min(1, Math.max(0, progress));
  return {
    ore: Math.floor(cost.ore * remaining),
    crystal: Math.floor(cost.crystal * remaining),
  };
}
