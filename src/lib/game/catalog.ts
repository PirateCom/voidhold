export const GALAXY = 1;
export const SYSTEM_MAX = 10;
export const SLOT_MAX = 10;

/** One game-hour of production elapses every 60 real seconds. */
export const GAME_HOUR_SECONDS = 60;

export const RAID_LOOT_MIN = 0.25;
export const RAID_LOOT_MAX = 0.75;
export const RAIDER_CARGO = 5000;
export const RAIDER_COST = { ore: 400, crystal: 100 } as const;
export const RAIDER_BUILD_SECONDS = 15;

export const STARTING_ORE = 1200;
export const STARTING_CRYSTAL = 500;
export const STARTING_RAIDERS = 0;

export type BuildingId = "ore_mine" | "crystal_mine" | "power_plant";

export type DefenceId =
  | "small_shield_dome"
  | "large_shield_dome"
  | "rocket_launcher"
  | "light_laser"
  | "heavy_laser"
  | "ion_cannon"
  | "gauss_cannon";

export const BUILDINGS: {
  id: BuildingId;
  name: string;
  blurb: string;
}[] = [
  { id: "ore_mine", name: "Ore mine", blurb: "Pulls metal from the crust." },
  { id: "crystal_mine", name: "Crystal mine", blurb: "Cuts lattice from the ice." },
  { id: "power_plant", name: "Power plant", blurb: "Feeds the mines. Shortfalls slow production." },
];

export const DEFENCES: {
  id: DefenceId;
  name: string;
  blurb: string;
  unique: boolean;
  tier: number | null;
  attack: number;
  defence: number;
  cost: { ore: number; crystal: number };
  buildSeconds: number;
}[] = [
  {
    id: "small_shield_dome",
    name: "Small shield dome",
    blurb: "One screen around the hold. Unique.",
    unique: true,
    tier: null,
    attack: 0,
    defence: 200,
    cost: { ore: 800, crystal: 800 },
    buildSeconds: 30,
  },
  {
    id: "large_shield_dome",
    name: "Large shield dome",
    blurb: "A heavier screen. Unique.",
    unique: true,
    tier: null,
    attack: 0,
    defence: 1000,
    cost: { ore: 4000, crystal: 4000 },
    buildSeconds: 75,
  },
  {
    id: "rocket_launcher",
    name: "Rocket launcher",
    blurb: "Tier 1 turret. Cheap volley fire.",
    unique: false,
    tier: 1,
    attack: 8,
    defence: 20,
    cost: { ore: 120, crystal: 30 },
    buildSeconds: 10,
  },
  {
    id: "light_laser",
    name: "Light laser turret",
    blurb: "Tier 2 turret. Fast crystal beams.",
    unique: false,
    tier: 2,
    attack: 10,
    defence: 25,
    cost: { ore: 180, crystal: 60 },
    buildSeconds: 14,
  },
  {
    id: "heavy_laser",
    name: "Heavy laser turret",
    blurb: "Tier 3 turret. Harder burn.",
    unique: false,
    tier: 3,
    attack: 25,
    defence: 90,
    cost: { ore: 480, crystal: 160 },
    buildSeconds: 22,
  },
  {
    id: "ion_cannon",
    name: "Ion cannon",
    blurb: "Tier 4. Crystal-heavy disruptor.",
    unique: false,
    tier: 4,
    attack: 15,
    defence: 130,
    cost: { ore: 160, crystal: 480 },
    buildSeconds: 28,
  },
  {
    id: "gauss_cannon",
    name: "Gaussian cannon turret",
    blurb: "Tier 5. Highest kinetic punch.",
    unique: false,
    tier: 5,
    attack: 110,
    defence: 370,
    cost: { ore: 1600, crystal: 1200 },
    buildSeconds: 45,
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
    ion_cannon: 0,
    gauss_cannon: 0,
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

export function powerOutput(level: number): number {
  if (level <= 0) return 0;
  return Math.floor(20 * level * Math.pow(1.1, level));
}

export function mineEnergyDrain(level: number): number {
  if (level <= 0) return 0;
  return Math.floor(10 * level * Math.pow(1.1, level));
}

export function energyFactor(oreMine: number, crystalMine: number, powerPlant: number): number {
  const drain = mineEnergyDrain(oreMine) + mineEnergyDrain(crystalMine);
  if (drain <= 0) return 1;
  return Math.min(1, powerOutput(powerPlant) / drain);
}

export function energyNow(oreMine: number, crystalMine: number, powerPlant: number): {
  output: number;
  drain: number;
  factor: number;
} {
  const output = powerOutput(powerPlant);
  const drain = mineEnergyDrain(oreMine) + mineEnergyDrain(crystalMine);
  return { output, drain, factor: energyFactor(oreMine, crystalMine, powerPlant) };
}

/** Extra energy a building uses (mines) or makes (power plant) at the next level. */
export function upgradeEnergyDelta(id: BuildingId, currentLevel: number): number {
  if (id === "power_plant") {
    return powerOutput(currentLevel + 1) - powerOutput(currentLevel);
  }
  return mineEnergyDrain(currentLevel + 1) - mineEnergyDrain(currentLevel);
}

export function energyAfterUpgrade(
  id: BuildingId,
  oreMine: number,
  crystalMine: number,
  powerPlant: number,
): { output: number; drain: number; factor: number } {
  if (id === "ore_mine") return energyNow(oreMine + 1, crystalMine, powerPlant);
  if (id === "crystal_mine") return energyNow(oreMine, crystalMine + 1, powerPlant);
  return energyNow(oreMine, crystalMine, powerPlant + 1);
}

export function storageCap(mineLevel: number): number {
  return 10000 + 5000 * Math.max(mineLevel, 0);
}

export function buildingCost(id: BuildingId, currentLevel: number): { ore: number; crystal: number } {
  const mul = Math.pow(1.5, currentLevel);
  switch (id) {
    case "ore_mine":
      return { ore: Math.floor(60 * mul), crystal: Math.floor(15 * mul) };
    case "crystal_mine":
      return { ore: Math.floor(48 * mul), crystal: Math.floor(24 * mul) };
    case "power_plant":
      return { ore: Math.floor(75 * mul), crystal: Math.floor(30 * mul) };
  }
}

export function buildingTimeSeconds(currentLevel: number): number {
  return Math.floor(20 * Math.pow(1.5, currentLevel));
}

export function researchCost(currentLevel: number): { ore: number; crystal: number } {
  const mul = Math.pow(2, currentLevel);
  return { ore: Math.floor(200 * mul), crystal: Math.floor(400 * mul) };
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
): number {
  const distance = Math.abs(fromSystem - toSystem) + Math.abs(fromSlot - toSlot);
  const raw = 20 + 12 * Math.max(distance, 1);
  return Math.max(15, Math.floor(raw / fleetSpeedMultiplier(propulsionLevel)));
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
