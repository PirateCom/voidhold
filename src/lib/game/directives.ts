import type { BuildingId, DefenceId, EmpireRow, PlanetRow } from "./types";
import { energyNow, type StarType } from "./catalog";
import type { ResearchId } from "./ogame-data";

export type DirectiveObjective =
  | { kind: "building"; building: BuildingId; level: number; label: string }
  | { kind: "energy_surplus"; label: string }
  | { kind: "research"; tech: ResearchId; level: number; label: string }
  | { kind: "ship"; ship: string; count: number; label: string }
  | { kind: "defence"; defence: DefenceId; count: number; label: string };

export type DirectiveSpec = {
  id: string;
  title: string;
  blurb: string;
  objectives: DirectiveObjective[];
  reward: { ore: number; crystal: number; deuterium: number };
};

function b(building: BuildingId, level: number): DirectiveObjective {
  const names: Record<string, string> = {
    ore_mine: "Ore mine",
    crystal_mine: "Crystal mine",
    deuterium_extractor: "Deuterium extractor",
    power_plant: "Solar plant",
    fusion_reactor: "Fusion reactor",
    ore_storage: "Ore storage",
    crystal_storage: "Crystal storage",
    deuterium_storage: "Deuterium storage",
    robotics_factory: "Robotics factory",
    shipyard: "Shipyard",
    research_lab: "Research lab",
    missile_silo: "Missile silo",
    nanite_factory: "Nanite factory",
  };
  return {
    kind: "building",
    building,
    level,
    label: `Upgrade ${names[building] ?? building} to level ${level}`,
  };
}

function r(tech: ResearchId, level: number, name: string): DirectiveObjective {
  return { kind: "research", tech, level, label: `Research ${name} to level ${level}` };
}

function s(ship: string, count: number, name: string): DirectiveObjective {
  return {
    kind: "ship",
    ship,
    count,
    label: count === 1 ? `Build 1 ${name}` : `Build ${count} ${name}s`,
  };
}

function g(defence: DefenceId, count: number, name: string): DirectiveObjective {
  const plural = count === 1 ? name : `${name}s`;
  return {
    kind: "defence",
    defence,
    count,
    label: count === 1 ? `Build 1 ${name}` : `Build ${count} ${plural}`,
  };
}

/** Beginner directives, then a mixed ship/defence climb. Mine % sliders are omitted. */
export const DIRECTIVES: DirectiveSpec[] = [
  {
    id: "ore_l1",
    title: "Ore",
    blurb:
      "Ore is one of your most important resources. You can produce it from Ore mines, but these need energy to run.",
    objectives: [b("ore_mine", 1)],
    reward: { ore: 50, crystal: 0, deuterium: 0 },
  },
  {
    id: "energy",
    title: "Energy",
    blurb:
      "Many buildings require energy. Produce enough to cover their needs. Upgrade a Solar plant until your energy balance is positive.",
    objectives: [b("power_plant", 1), { kind: "energy_surplus", label: "Achieve a positive energy balance" }],
    reward: { ore: 50, crystal: 0, deuterium: 0 },
  },
  {
    id: "ore_l2",
    title: "Powerful mines",
    blurb: "With this energy we can run stronger mines. Upgrade your Ore mine to raise production.",
    objectives: [b("ore_mine", 2)],
    reward: { ore: 50, crystal: 0, deuterium: 0 },
  },
  {
    id: "solar_l2",
    title: "Upgrade your Solar plant",
    blurb: "Another way to raise energy is to upgrade the Solar plant. Take it to level 2.",
    objectives: [b("power_plant", 2)],
    reward: { ore: 50, crystal: 30, deuterium: 0 },
  },
  {
    id: "ore_solar_mid",
    title: "Upgrade your Ore mine",
    blurb:
      "Keep upgrading the Ore mine. Watch energy use and upgrade the Solar plant so production stays at full power.",
    objectives: [b("ore_mine", 3), b("power_plant", 3), b("ore_mine", 4)],
    reward: { ore: 150, crystal: 50, deuterium: 0 },
  },
  {
    id: "crystal_l1",
    title: "Build a Crystal mine",
    blurb:
      "Crystal is required for almost every structure and for research. A Crystal mine starts that production.",
    objectives: [b("crystal_mine", 1)],
    reward: { ore: 50, crystal: 30, deuterium: 0 },
  },
  {
    id: "continue_prod",
    title: "Continue increasing production",
    blurb:
      "Kick resource production higher. Expand the mines, but keep a constant eye on energy so nothing runs starved.",
    objectives: [
      b("power_plant", 4),
      b("ore_mine", 5),
      b("crystal_mine", 2),
      b("power_plant", 5),
      b("crystal_mine", 3),
    ],
    reward: { ore: 400, crystal: 200, deuterium: 0 },
  },
  {
    id: "deuterium_l1",
    title: "Deuterium",
    blurb:
      "Deuterium is used for some buildings, research, and ship fuel. Build the Deuterium extractor to start production.",
    objectives: [b("deuterium_extractor", 1)],
    reward: { ore: 200, crystal: 100, deuterium: 0 },
  },
  {
    id: "sufficient",
    title: "Sufficient resources",
    blurb: "Keep expanding the economy so later growth is not starved for materials.",
    objectives: [
      b("power_plant", 6),
      b("ore_mine", 7),
      b("power_plant", 7),
      b("crystal_mine", 5),
      b("deuterium_extractor", 2),
      b("power_plant", 8),
      b("deuterium_extractor", 4),
      b("power_plant", 9),
      b("deuterium_extractor", 5),
    ],
    reward: { ore: 3000, crystal: 1000, deuterium: 0 },
  },
  {
    id: "storage",
    title: "Storage and capacity",
    blurb:
      "Tanks raise how much a planet can hold. When a hold is full, that resource stops accumulating. Build a tank for each resource.",
    objectives: [b("ore_storage", 1), b("crystal_storage", 1), b("deuterium_storage", 1)],
    reward: { ore: 3000, crystal: 1500, deuterium: 0 },
  },
  {
    id: "yard_foundations",
    title: "Open the yards",
    blurb: "Robotics, a lab, and a shipyard unlock both hulls and guns. Robotics 2 is the gate for the yard.",
    objectives: [b("robotics_factory", 2), b("research_lab", 1), b("shipyard", 1)],
    reward: { ore: 800, crystal: 400, deuterium: 200 },
  },
  {
    id: "energy_theory",
    title: "Energy technology",
    blurb: "Energy technology is the first research. It unlocks combustion drive and later weapon theories.",
    objectives: [r("energy_tech", 1, "Energy technology")],
    reward: { ore: 0, crystal: 400, deuterium: 200 },
  },
  {
    id: "combustion_fighter",
    title: "First fighter",
    blurb: "Combustion drive 1 and shipyard 1 let you launch a Light fighter, the smallest combat hull.",
    objectives: [r("combustion_drive", 1, "Combustion drive"), s("light_fighter", 1, "Light fighter")],
    reward: { ore: 2000, crystal: 1000, deuterium: 0 },
  },
  {
    id: "rocket_screen",
    title: "Rocket screen",
    blurb: "Rocket launchers need only the yard. Put a cheap volley on the perimeter.",
    objectives: [g("rocket_launcher", 5, "Rocket launcher")],
    reward: { ore: 2000, crystal: 0, deuterium: 0 },
  },
  {
    id: "orbit_sats",
    title: "Orbital power",
    blurb: "Solar satellites need the yard and no research. They add energy from this planet’s temperature and star.",
    objectives: [s("solar_satellite", 2, "Solar satellite")],
    reward: { ore: 0, crystal: 2000, deuterium: 500 },
  },
  {
    id: "laser_screen",
    title: "Light lasers",
    blurb: "Laser technology 3 and shipyard 2 open Light laser turrets. Mix them with the rocket line.",
    objectives: [
      r("laser_tech", 3, "Laser technology"),
      b("shipyard", 2),
      g("light_laser", 5, "Light laser turret"),
    ],
    reward: { ore: 3000, crystal: 2000, deuterium: 0 },
  },
  {
    id: "small_hauler",
    title: "Small cargo",
    blurb: "Combustion 2 and shipyard 2 open the Small cargo, the first hauler.",
    objectives: [r("combustion_drive", 2, "Combustion drive"), s("small_cargo", 1, "Small cargo")],
    reward: { ore: 2000, crystal: 2000, deuterium: 0 },
  },
  {
    id: "spy_net",
    title: "Probes",
    blurb: "Lab 3, Espionage 2, and Combustion 3 open Espionage probes. Computer technology adds a fleet slot.",
    objectives: [
      b("research_lab", 3),
      r("espionage_tech", 2, "Espionage technology"),
      r("combustion_drive", 3, "Combustion drive"),
      r("computer_tech", 1, "Computer technology"),
      s("espionage_probe", 1, "Espionage probe"),
    ],
    reward: { ore: 0, crystal: 2500, deuterium: 400 },
  },
  {
    id: "heavy_fighter",
    title: "Heavy fighter",
    blurb: "Impulse 2, Armour 2, and shipyard 3 open the Heavy fighter.",
    objectives: [
      r("impulse_drive", 2, "Impulse drive"),
      r("armour_tech", 2, "Armour technology"),
      b("shipyard", 3),
      s("heavy_fighter", 1, "Heavy fighter"),
    ],
    reward: { ore: 4000, crystal: 3000, deuterium: 0 },
  },
  {
    id: "small_dome",
    title: "Small shield dome",
    blurb: "Shielding 2 lets you raise one Small shield dome. Unique on the planet.",
    objectives: [r("shielding_tech", 2, "Shielding technology"), g("small_shield_dome", 1, "Small shield dome")],
    reward: { ore: 5000, crystal: 5000, deuterium: 0 },
  },
  {
    id: "large_hauler",
    title: "Large cargo",
    blurb: "Combustion 6 and shipyard 4 open the Large cargo.",
    objectives: [r("combustion_drive", 6, "Combustion drive"), b("shipyard", 4), s("large_cargo", 1, "Large cargo")],
    reward: { ore: 4000, crystal: 4000, deuterium: 0 },
  },
  {
    id: "recycler_crew",
    title: "Recycler",
    blurb: "A Recycler needs Combustion 6 and Shielding 2. Harvest debris after fights.",
    objectives: [s("recycler", 1, "Recycler")],
    reward: { ore: 5000, crystal: 4000, deuterium: 1000 },
  },
  {
    id: "colony_line",
    title: "Colony ship",
    blurb: "Impulse 3 opens the Colony ship so you can found another world.",
    objectives: [r("impulse_drive", 3, "Impulse drive"), s("colony_ship", 1, "Colony ship")],
    reward: { ore: 5000, crystal: 10000, deuterium: 5000 },
  },
  {
    id: "ion_guns",
    title: "Ion cannon",
    blurb: "Lab 4, Energy 4, Laser 5, and Ion 4 open the Ion cannon.",
    objectives: [
      b("research_lab", 4),
      r("energy_tech", 4, "Energy technology"),
      r("laser_tech", 5, "Laser technology"),
      r("ion_tech", 4, "Ion technology"),
      g("ion_cannon", 1, "Ion cannon"),
    ],
    reward: { ore: 4000, crystal: 3000, deuterium: 0 },
  },
  {
    id: "cruiser_wing",
    title: "Cruiser",
    blurb: "Impulse 4, Ion 2, and shipyard 5 open the Cruiser. Mix it with the ion guns.",
    objectives: [r("impulse_drive", 4, "Impulse drive"), b("shipyard", 5), s("cruiser", 1, "Cruiser")],
    reward: { ore: 10000, crystal: 4000, deuterium: 1000 },
  },
  {
    id: "crawler_line",
    title: "Crawler",
    blurb: "Combustion 4, Armour 4, and Laser 4 open Crawlers. They stay on the planet.",
    objectives: [
      r("combustion_drive", 4, "Combustion drive"),
      r("armour_tech", 4, "Armour technology"),
      r("laser_tech", 4, "Laser technology"),
      s("crawler", 1, "Crawler"),
    ],
    reward: { ore: 2000, crystal: 2000, deuterium: 1000 },
  },
  {
    id: "heavy_laser_battery",
    title: "Heavy lasers",
    blurb: "Energy 3, Laser 6, and shipyard 4 open Heavy laser turrets.",
    objectives: [
      r("energy_tech", 3, "Energy technology"),
      r("laser_tech", 6, "Laser technology"),
      g("heavy_laser", 5, "Heavy laser turret"),
    ],
    reward: { ore: 8000, crystal: 4000, deuterium: 0 },
  },
  {
    id: "hyperspace_theory",
    title: "Hyperspace theory",
    blurb: "Lab 7, Energy 5, Shielding 5, and Hyperspace technology 3 open the hyperspace drive line.",
    objectives: [
      b("research_lab", 7),
      r("energy_tech", 5, "Energy technology"),
      r("shielding_tech", 5, "Shielding technology"),
      r("hyperspace_tech", 3, "Hyperspace technology"),
      r("hyperspace_drive", 2, "Hyperspace drive"),
    ],
    reward: { ore: 8000, crystal: 15000, deuterium: 4000 },
  },
  {
    id: "pathfinder_scout",
    title: "Pathfinder",
    blurb: "Hyperspace drive 2 and shipyard 5 open the Pathfinder.",
    objectives: [s("pathfinder", 1, "Pathfinder")],
    reward: { ore: 5000, crystal: 8000, deuterium: 4000 },
  },
  {
    id: "gauss_line",
    title: "Gauss cannon",
    blurb: "Energy 6, Weapons 3, Shielding 1, and shipyard 6 open the Gauss cannon.",
    objectives: [
      r("energy_tech", 6, "Energy technology"),
      r("weapons_tech", 3, "Weapons technology"),
      b("shipyard", 6),
      g("gauss_cannon", 1, "Gaussian cannon turret"),
    ],
    reward: { ore: 10000, crystal: 8000, deuterium: 1000 },
  },
  {
    id: "large_dome",
    title: "Large shield dome",
    blurb: "Shielding 6 and shipyard 6 raise the Large shield dome. Unique on the planet.",
    objectives: [r("shielding_tech", 6, "Shielding technology"), g("large_shield_dome", 1, "Large shield dome")],
    reward: { ore: 20000, crystal: 20000, deuterium: 0 },
  },
  {
    id: "battleship_line",
    title: "Battleship",
    blurb: "Hyperspace drive 4 and shipyard 7 open the Battleship.",
    objectives: [r("hyperspace_drive", 4, "Hyperspace drive"), b("shipyard", 7), s("battleship", 1, "Battleship")],
    reward: { ore: 20000, crystal: 8000, deuterium: 0 },
  },
  {
    id: "plasma_bomber",
    title: "Bomber",
    blurb: "Energy 8, Laser 10, Ion 5, Plasma 5, Impulse 6, and shipyard 8 open the Bomber.",
    objectives: [
      r("energy_tech", 8, "Energy technology"),
      r("laser_tech", 10, "Laser technology"),
      r("ion_tech", 5, "Ion technology"),
      r("plasma_tech", 5, "Plasma technology"),
      r("impulse_drive", 6, "Impulse drive"),
      b("shipyard", 8),
      s("bomber", 1, "Bomber"),
    ],
    reward: { ore: 25000, crystal: 15000, deuterium: 8000 },
  },
  {
    id: "plasma_guns",
    title: "Plasma turret",
    blurb: "Plasma technology 7 opens the Plasma turret, the heaviest battery.",
    objectives: [r("plasma_tech", 7, "Plasma technology"), g("plasma_turret", 1, "Plasma turret")],
    reward: { ore: 25000, crystal: 25000, deuterium: 15000 },
  },
  {
    id: "battlecruiser_wing",
    title: "Battlecruiser",
    blurb: "Hyperspace drive 5, Hyperspace technology 5, and Laser 12 open the Battlecruiser.",
    objectives: [
      r("hyperspace_drive", 5, "Hyperspace drive"),
      r("hyperspace_tech", 5, "Hyperspace technology"),
      r("laser_tech", 12, "Laser technology"),
      s("battlecruiser", 1, "Battlecruiser"),
    ],
    reward: { ore: 20000, crystal: 25000, deuterium: 8000 },
  },
  {
    id: "destroyer_wing",
    title: "Destroyer",
    blurb: "Hyperspace drive 6 and shipyard 9 open the Destroyer.",
    objectives: [r("hyperspace_drive", 6, "Hyperspace drive"), b("shipyard", 9), s("destroyer", 1, "Destroyer")],
    reward: { ore: 30000, crystal: 25000, deuterium: 8000 },
  },
  {
    id: "missile_abm",
    title: "Antiballistic missiles",
    blurb: "Missile silo 2 stores Antiballistic missiles that stop incoming interplanetary shots.",
    objectives: [b("missile_silo", 2), g("antiballistic_missile", 1, "Antiballistic missile")],
    reward: { ore: 8000, crystal: 4000, deuterium: 2000 },
  },
  {
    id: "missile_ipm",
    title: "Interplanetary missiles",
    blurb: "Silo 4 and Impulse 1 open Interplanetary missiles that strike guns on another hold.",
    objectives: [b("missile_silo", 4), g("interplanetary_missile", 1, "Interplanetary missile")],
    reward: { ore: 8000, crystal: 2000, deuterium: 5000 },
  },
  {
    id: "reaper_wing",
    title: "Reaper",
    blurb: "Hyperspace drive 7, Hyperspace technology 6, Shielding 6, and shipyard 10 open the Reaper.",
    objectives: [
      r("hyperspace_drive", 7, "Hyperspace drive"),
      r("hyperspace_tech", 6, "Hyperspace technology"),
      b("shipyard", 10),
      s("reaper", 1, "Reaper"),
    ],
    reward: { ore: 40000, crystal: 30000, deuterium: 10000 },
  },
  {
    id: "nanite_works",
    title: "Nanite factory",
    blurb: "Robotics 10, Computer 10, and a yard let you raise the Nanite factory and cut construction time in half.",
    objectives: [
      b("robotics_factory", 10),
      r("computer_tech", 10, "Computer technology"),
      b("nanite_factory", 1),
    ],
    reward: { ore: 50000, crystal: 25000, deuterium: 10000 },
  },
  {
    id: "deathstar",
    title: "Deathstar",
    blurb: "Lab 12, Graviton 1, Hyperspace drive 7, Hyperspace technology 6, and shipyard 12 open the Deathstar.",
    objectives: [
      b("research_lab", 12),
      r("graviton_tech", 1, "Graviton technology"),
      b("shipyard", 12),
      s("deathstar", 1, "Deathstar"),
    ],
    reward: { ore: 100000, crystal: 80000, deuterium: 20000 },
  },
];

export type DirectiveLevels = Partial<Record<BuildingId, number>> & {
  energyOutput?: number;
  energyDrain?: number;
  starType?: StarType;
  research?: Partial<Record<ResearchId, number>>;
  ships?: Record<string, number>;
  defences?: Partial<Record<DefenceId, number>>;
};

export function buildingLevelOf(levels: DirectiveLevels, id: BuildingId): number {
  return Math.max(0, Math.floor(levels[id] ?? 0));
}

export function researchLevelOf(levels: DirectiveLevels, id: ResearchId): number {
  return Math.max(0, Math.floor(levels.research?.[id] ?? 0));
}

export function shipCountOf(levels: DirectiveLevels, id: string): number {
  return Math.max(0, Math.floor(levels.ships?.[id] ?? 0));
}

export function defenceCountOf(levels: DirectiveLevels, id: DefenceId): number {
  return Math.max(0, Math.floor(levels.defences?.[id] ?? 0));
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
  if (objective.kind === "research") return researchLevelOf(levels, objective.tech) >= objective.level;
  if (objective.kind === "ship") return shipCountOf(levels, objective.ship) >= objective.count;
  if (objective.kind === "defence") return defenceCountOf(levels, objective.defence) >= objective.count;
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

export function researchFromEmpire(empire: Pick<
  EmpireRow,
  | "propulsion_level"
  | "energy_tech"
  | "laser_tech"
  | "ion_tech"
  | "hyperspace_tech"
  | "plasma_tech"
  | "impulse_drive"
  | "hyperspace_drive"
  | "espionage_tech"
  | "computer_tech"
  | "astrophysics"
  | "intergalactic_research_network"
  | "graviton_tech"
  | "weapons_tech"
  | "shielding_tech"
  | "armour_tech"
>): Partial<Record<ResearchId, number>> {
  return {
    combustion_drive: empire.propulsion_level ?? 0,
    energy_tech: empire.energy_tech ?? 0,
    laser_tech: empire.laser_tech ?? 0,
    ion_tech: empire.ion_tech ?? 0,
    hyperspace_tech: empire.hyperspace_tech ?? 0,
    plasma_tech: empire.plasma_tech ?? 0,
    impulse_drive: empire.impulse_drive ?? 0,
    hyperspace_drive: empire.hyperspace_drive ?? 0,
    espionage_tech: empire.espionage_tech ?? 0,
    computer_tech: empire.computer_tech ?? 0,
    astrophysics: empire.astrophysics ?? 0,
    intergalactic_research_network: empire.intergalactic_research_network ?? 0,
    graviton_tech: empire.graviton_tech ?? 0,
    weapons_tech: empire.weapons_tech ?? 0,
    shielding_tech: empire.shielding_tech ?? 0,
    armour_tech: empire.armour_tech ?? 0,
  };
}

export function shipsFromEmpire(empire: Pick<EmpireRow, "raiders" | "ships">): Record<string, number> {
  return { ...(empire.ships ?? {}), small_cargo: empire.raiders ?? 0 };
}

export function defencesFromPlanet(planet: Pick<PlanetRow, DefenceId>): Partial<Record<DefenceId, number>> {
  return {
    small_shield_dome: planet.small_shield_dome ?? 0,
    large_shield_dome: planet.large_shield_dome ?? 0,
    rocket_launcher: planet.rocket_launcher ?? 0,
    light_laser: planet.light_laser ?? 0,
    heavy_laser: planet.heavy_laser ?? 0,
    gauss_cannon: planet.gauss_cannon ?? 0,
    ion_cannon: planet.ion_cannon ?? 0,
    plasma_turret: planet.plasma_turret ?? 0,
    antiballistic_missile: planet.antiballistic_missile ?? 0,
    interplanetary_missile: planet.interplanetary_missile ?? 0,
  };
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
  robotics_factory?: number;
  shipyard?: number;
  research_lab?: number;
  missile_silo?: number;
  nanite_factory?: number;
  energyOutput?: number;
  energyDrain?: number;
  starType?: StarType;
  research?: Partial<Record<ResearchId, number>>;
  ships?: Record<string, number>;
  defences?: Partial<Record<DefenceId, number>>;
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
    robotics_factory: input.robotics_factory ?? 0,
    shipyard: input.shipyard ?? 0,
    research_lab: input.research_lab ?? 0,
    missile_silo: input.missile_silo ?? 0,
    nanite_factory: input.nanite_factory ?? 0,
    energyOutput: input.energyOutput,
    energyDrain: input.energyDrain,
    starType: input.starType,
    research: input.research,
    ships: input.ships,
    defences: input.defences,
  };
}

export function levelsFromHold(input: {
  planet: PlanetRow;
  empire: EmpireRow;
  energyOutput?: number;
  energyDrain?: number;
  starType?: StarType;
}): DirectiveLevels {
  const p = input.planet;
  return {
    ...levelsFromPlanet({
      ore_mine: p.ore_mine,
      crystal_mine: p.crystal_mine,
      deuterium_extractor: p.deuterium_extractor,
      power_plant: p.power_plant,
      fusion_reactor: p.fusion_reactor,
      ore_storage: p.ore_storage,
      crystal_storage: p.crystal_storage,
      deuterium_storage: p.deuterium_storage,
      robotics_factory: p.robotics_factory,
      shipyard: p.shipyard,
      research_lab: p.research_lab,
      missile_silo: p.missile_silo,
      nanite_factory: p.nanite_factory,
      energyOutput: input.energyOutput,
      energyDrain: input.energyDrain,
      starType: input.starType,
      research: researchFromEmpire(input.empire),
      ships: shipsFromEmpire(input.empire),
      defences: defencesFromPlanet(p),
    }),
  };
}
