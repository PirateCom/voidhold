import type { BuildingId } from "./types";
import { energyNow, type StarType } from "./catalog";

export type DirectiveObjective =
  | { kind: "building"; building: BuildingId; level: number; label: string }
  | { kind: "energy_surplus"; label: string };

export type DirectiveSpec = {
  id: string;
  title: string;
  blurb: string;
  objectives: DirectiveObjective[];
  reward: { ore: number; crystal: number; deuterium: number };
};

/** Beginner directives, adapted from the OGame officer tutorial. Mine % sliders are omitted. */
export const DIRECTIVES: DirectiveSpec[] = [
  {
    id: "ore_l1",
    title: "Ore",
    blurb:
      "Ore is one of your most important resources. You can produce it from Ore mines, but these need energy to run.",
    objectives: [{ kind: "building", building: "ore_mine", level: 1, label: "Upgrade Ore mine to level 1" }],
    reward: { ore: 50, crystal: 0, deuterium: 0 },
  },
  {
    id: "energy",
    title: "Energy",
    blurb:
      "Many buildings require energy. Produce enough to cover their needs. Upgrade a Solar plant until your energy balance is positive.",
    objectives: [
      { kind: "building", building: "power_plant", level: 1, label: "Upgrade Solar plant to level 1" },
      { kind: "energy_surplus", label: "Achieve a positive energy balance" },
    ],
    reward: { ore: 50, crystal: 0, deuterium: 0 },
  },
  {
    id: "ore_l2",
    title: "Powerful mines",
    blurb: "With this energy we can run stronger mines. Upgrade your Ore mine to raise production.",
    objectives: [{ kind: "building", building: "ore_mine", level: 2, label: "Upgrade Ore mine to level 2" }],
    reward: { ore: 50, crystal: 0, deuterium: 0 },
  },
  {
    id: "solar_l2",
    title: "Upgrade your Solar plant",
    blurb: "Another way to raise energy is to upgrade the Solar plant. Take it to level 2.",
    objectives: [{ kind: "building", building: "power_plant", level: 2, label: "Upgrade Solar plant to level 2" }],
    reward: { ore: 50, crystal: 30, deuterium: 0 },
  },
  {
    id: "ore_solar_mid",
    title: "Upgrade your Ore mine",
    blurb:
      "Keep upgrading the Ore mine. Watch energy use and upgrade the Solar plant so production stays at full power.",
    objectives: [
      { kind: "building", building: "ore_mine", level: 3, label: "Upgrade Ore mine to level 3" },
      { kind: "building", building: "power_plant", level: 3, label: "Upgrade Solar plant to level 3" },
      { kind: "building", building: "ore_mine", level: 4, label: "Upgrade Ore mine to level 4" },
    ],
    reward: { ore: 150, crystal: 50, deuterium: 0 },
  },
  {
    id: "crystal_l1",
    title: "Build a Crystal mine",
    blurb:
      "Crystal is required for almost every structure and for research. A Crystal mine starts that production.",
    objectives: [{ kind: "building", building: "crystal_mine", level: 1, label: "Upgrade Crystal mine to level 1" }],
    reward: { ore: 50, crystal: 30, deuterium: 0 },
  },
  {
    id: "continue_prod",
    title: "Continue increasing production",
    blurb:
      "Kick resource production higher. Expand the mines, but keep a constant eye on energy so nothing runs starved.",
    objectives: [
      { kind: "building", building: "power_plant", level: 4, label: "Upgrade Solar plant to level 4" },
      { kind: "building", building: "ore_mine", level: 5, label: "Upgrade Ore mine to level 5" },
      { kind: "building", building: "crystal_mine", level: 2, label: "Upgrade Crystal mine to level 2" },
      { kind: "building", building: "power_plant", level: 5, label: "Upgrade Solar plant to level 5" },
      { kind: "building", building: "crystal_mine", level: 3, label: "Upgrade Crystal mine to level 3" },
    ],
    reward: { ore: 400, crystal: 200, deuterium: 0 },
  },
  {
    id: "deuterium_l1",
    title: "Deuterium",
    blurb:
      "Deuterium is used for some buildings, research, and ship fuel. Build the Deuterium extractor to start production.",
    objectives: [
      {
        kind: "building",
        building: "deuterium_extractor",
        level: 1,
        label: "Upgrade Deuterium extractor to level 1",
      },
    ],
    reward: { ore: 200, crystal: 100, deuterium: 0 },
  },
  {
    id: "sufficient",
    title: "Sufficient resources",
    blurb: "Keep expanding the economy so later growth is not starved for materials.",
    objectives: [
      { kind: "building", building: "power_plant", level: 6, label: "Upgrade Solar plant to level 6" },
      { kind: "building", building: "ore_mine", level: 7, label: "Upgrade Ore mine to level 7" },
      { kind: "building", building: "power_plant", level: 7, label: "Upgrade Solar plant to level 7" },
      { kind: "building", building: "crystal_mine", level: 5, label: "Upgrade Crystal mine to level 5" },
      { kind: "building", building: "deuterium_extractor", level: 2, label: "Upgrade Deuterium extractor to level 2" },
      { kind: "building", building: "power_plant", level: 8, label: "Upgrade Solar plant to level 8" },
      { kind: "building", building: "deuterium_extractor", level: 4, label: "Upgrade Deuterium extractor to level 4" },
      { kind: "building", building: "power_plant", level: 9, label: "Upgrade Solar plant to level 9" },
      { kind: "building", building: "deuterium_extractor", level: 5, label: "Upgrade Deuterium extractor to level 5" },
    ],
    reward: { ore: 3000, crystal: 1000, deuterium: 0 },
  },
  {
    id: "storage",
    title: "Storage and capacity",
    blurb:
      "Tanks raise how much a planet can hold. When a hold is full, that resource stops accumulating. Build a tank for each resource.",
    objectives: [
      { kind: "building", building: "ore_storage", level: 1, label: "Upgrade Ore storage to level 1" },
      { kind: "building", building: "crystal_storage", level: 1, label: "Upgrade Crystal storage to level 1" },
      { kind: "building", building: "deuterium_storage", level: 1, label: "Upgrade Deuterium storage to level 1" },
    ],
    reward: { ore: 3000, crystal: 1500, deuterium: 0 },
  },
];

export type DirectiveLevels = Partial<Record<BuildingId, number>> & {
  energyOutput?: number;
  energyDrain?: number;
  starType?: StarType;
};

export function buildingLevelOf(levels: DirectiveLevels, id: BuildingId): number {
  return Math.max(0, Math.floor(levels[id] ?? 0));
}

export function hasEnergySurplus(levels: DirectiveLevels): boolean {
  if (levels.energyOutput != null && levels.energyDrain != null) {
    return levels.energyOutput > levels.energyDrain;
  }
  const energy = energyNow(
    buildingLevelOf(levels, "ore_mine"),
    buildingLevelOf(levels, "crystal_mine"),
    buildingLevelOf(levels, "power_plant"),
    levels.starType ?? "medium",
    buildingLevelOf(levels, "deuterium_extractor"),
    buildingLevelOf(levels, "fusion_reactor"),
  );
  return energy.output > energy.drain;
}

export function objectiveMet(objective: DirectiveObjective, levels: DirectiveLevels): boolean {
  if (objective.kind === "energy_surplus") return hasEnergySurplus(levels);
  return buildingLevelOf(levels, objective.building) >= objective.level;
}

export function directiveProgress(spec: DirectiveSpec, levels: DirectiveLevels): { done: number; total: number } {
  const total = spec.objectives.length;
  const done = spec.objectives.filter((o) => objectiveMet(o, levels)).length;
  return { done, total };
}

export function directiveComplete(spec: DirectiveSpec, levels: DirectiveLevels): boolean {
  return spec.objectives.every((o) => objectiveMet(o, levels));
}

export function previousDirectiveId(id: string): string | null {
  const i = DIRECTIVES.findIndex((d) => d.id === id);
  if (i <= 0) return null;
  return DIRECTIVES[i - 1].id;
}

export function isDirectiveClaimed(claimed: string[] | null | undefined, id: string): boolean {
  return (claimed ?? []).includes(id);
}

export function directiveUnlocked(claimed: string[] | null | undefined, id: string): boolean {
  const prev = previousDirectiveId(id);
  if (!prev) return true;
  return isDirectiveClaimed(claimed, prev);
}

export function isDirectiveTracked(tracked: string[] | null | undefined, id: string): boolean {
  return (tracked ?? []).includes(id);
}

export function trackedDirectiveSpecs(
  tracked: string[] | null | undefined,
  claimed: string[] | null | undefined,
): DirectiveSpec[] {
  const pins = new Set(tracked ?? []);
  return DIRECTIVES.filter((d) => pins.has(d.id) && !isDirectiveClaimed(claimed, d.id));
}

export function activeDirective(claimed: string[] | null | undefined): DirectiveSpec | null {
  return DIRECTIVES.find((d) => !isDirectiveClaimed(claimed, d.id) && directiveUnlocked(claimed, d.id)) ?? null;
}

export function formatDirectiveReward(reward: DirectiveSpec["reward"]): string {
  const parts: string[] = [];
  if (reward.ore) parts.push(`${reward.ore.toLocaleString()} ore`);
  if (reward.crystal) parts.push(`${reward.crystal.toLocaleString()} crystal`);
  if (reward.deuterium) parts.push(`${reward.deuterium.toLocaleString()} deuterium`);
  return parts.join(" · ") || "Nothing";
}

export function levelsFromPlanet(input: {
  ore_mine: number;
  crystal_mine: number;
  deuterium_extractor?: number;
  power_plant: number;
  fusion_reactor?: number;
  ore_storage?: number;
  crystal_storage?: number;
  deuterium_storage?: number;
  energyOutput?: number;
  energyDrain?: number;
  starType?: StarType;
}): DirectiveLevels {
  return {
    ore_mine: input.ore_mine,
    crystal_mine: input.crystal_mine,
    deuterium_extractor: input.deuterium_extractor ?? 0,
    power_plant: input.power_plant,
    fusion_reactor: input.fusion_reactor ?? 0,
    ore_storage: input.ore_storage ?? 0,
    crystal_storage: input.crystal_storage ?? 0,
    deuterium_storage: input.deuterium_storage ?? 0,
    energyOutput: input.energyOutput,
    energyDrain: input.energyDrain,
    starType: input.starType,
  };
}
