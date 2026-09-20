export const GALAXY = 1;
export const SYSTEM_MAX = 10;
export const SLOT_MAX = 10;

/** One game-hour of production elapses every 60 real seconds. */
export const GAME_HOUR_SECONDS = 60;

export const RAID_LOOT_RATIO = 0.5;
export const RAIDER_CARGO = 5000;
export const RAIDER_COST = { ore: 400, crystal: 100 } as const;
export const RAIDER_BUILD_SECONDS = 15;

export const STARTING_ORE = 1200;
export const STARTING_CRYSTAL = 500;
export const STARTING_RAIDERS = 0;

export type BuildingId = "ore_mine" | "crystal_mine" | "power_plant";

export const BUILDINGS: {
  id: BuildingId;
  name: string;
  blurb: string;
}[] = [
  { id: "ore_mine", name: "Ore mine", blurb: "Pulls metal from the crust." },
  { id: "crystal_mine", name: "Crystal mine", blurb: "Cuts lattice from the ice." },
  { id: "power_plant", name: "Power plant", blurb: "Feeds the mines. Shortfalls slow production." },
];

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

export function raidLoot(available: number, cargoLeft: number): number {
  return Math.min(Math.max(0, cargoLeft), Math.floor(Math.max(0, available) * RAID_LOOT_RATIO));
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
