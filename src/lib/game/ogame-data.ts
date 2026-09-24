/** OGame ship and technology stats from ogame.fandom.com, gathered 23 Sep 2026. */

export type ResearchId =
  | "energy_tech"
  | "laser_tech"
  | "ion_tech"
  | "hyperspace_tech"
  | "plasma_tech"
  | "combustion_drive"
  | "impulse_drive"
  | "hyperspace_drive"
  | "espionage_tech"
  | "computer_tech"
  | "astrophysics"
  | "intergalactic_research_network"
  | "graviton_tech"
  | "weapons_tech"
  | "shielding_tech"
  | "armour_tech";

export type ResearchGroup = "basic" | "drive" | "empire" | "combat";

export type TechRequirement = { id: ResearchId; level: number };

export const RESEARCH_GROUPS: { id: ResearchGroup; title: string }[] = [
  { id: "basic", title: "Basic" },
  { id: "drive", title: "Drives" },
  { id: "empire", title: "Empire" },
  { id: "combat", title: "Combat" },
];

export const RESEARCHES: {
  id: ResearchId;
  name: string;
  blurb: string;
  group: ResearchGroup;
  baseOre: number;
  baseCrystal: number;
  baseDeuterium: number;
  /** Most technologies double. Astrophysics rises by 1.75. */
  costFactor: number;
  lab: number;
  requires: TechRequirement[];
  energy?: number;
}[] = [
  {
    id: "energy_tech",
    name: "Energy technology",
    blurb: "Raises fusion-reactor output. Required by the drive line and later weapon theories.",
    group: "basic",
    baseOre: 0,
    baseCrystal: 800,
    baseDeuterium: 400,
    costFactor: 2,
    lab: 1,
    requires: [],
  },
  {
    id: "laser_tech",
    name: "Laser technology",
    blurb: "Opens laser weapons and later ion and plasma research.",
    group: "basic",
    baseOre: 200,
    baseCrystal: 100,
    baseDeuterium: 0,
    costFactor: 2,
    lab: 1,
    requires: [{ id: "energy_tech", level: 2 }],
  },
  {
    id: "ion_tech",
    name: "Ion technology",
    blurb: "Opens ion weapons. Required for cruisers and plasma technology.",
    group: "basic",
    baseOre: 1000,
    baseCrystal: 300,
    baseDeuterium: 100,
    costFactor: 2,
    lab: 4,
    requires: [
      { id: "laser_tech", level: 5 },
      { id: "energy_tech", level: 4 },
    ],
  },
  {
    id: "hyperspace_tech",
    name: "Hyperspace technology",
    blurb: "Opens hyperspace drives, battlecruisers, destroyers, and the deathstar.",
    group: "basic",
    baseOre: 0,
    baseCrystal: 4000,
    baseDeuterium: 2000,
    costFactor: 2,
    lab: 7,
    requires: [
      { id: "shielding_tech", level: 5 },
      { id: "energy_tech", level: 5 },
    ],
  },
  {
    id: "plasma_tech",
    name: "Plasma technology",
    blurb: "Opens plasma weapons. Required for bombers.",
    group: "basic",
    baseOre: 2000,
    baseCrystal: 4000,
    baseDeuterium: 1000,
    costFactor: 2,
    lab: 4,
    requires: [
      { id: "energy_tech", level: 8 },
      { id: "laser_tech", level: 10 },
      { id: "ion_tech", level: 5 },
    ],
  },
  {
    id: "combustion_drive",
    name: "Combustion drive",
    blurb: "Adds 10% speed per level to combustion-drive ships.",
    group: "drive",
    baseOre: 400,
    baseCrystal: 0,
    baseDeuterium: 600,
    costFactor: 2,
    lab: 1,
    requires: [{ id: "energy_tech", level: 1 }],
  },
  {
    id: "impulse_drive",
    name: "Impulse drive",
    blurb: "Adds 20% speed per level to impulse-drive ships. At level 5 it also upgrades the small cargo.",
    group: "drive",
    baseOre: 2000,
    baseCrystal: 4000,
    baseDeuterium: 600,
    costFactor: 2,
    lab: 2,
    requires: [{ id: "energy_tech", level: 1 }],
  },
  {
    id: "hyperspace_drive",
    name: "Hyperspace drive",
    blurb: "Adds 30% speed per level to hyperspace-drive ships. At level 8 it also upgrades the bomber.",
    group: "drive",
    baseOre: 10000,
    baseCrystal: 20000,
    baseDeuterium: 6000,
    costFactor: 2,
    lab: 7,
    requires: [
      { id: "energy_tech", level: 5 },
      { id: "shielding_tech", level: 5 },
      { id: "hyperspace_tech", level: 3 },
    ],
  },
  {
    id: "espionage_tech",
    name: "Espionage technology",
    blurb: "Probe reports show more as this level pulls ahead of the target. Required for probes and astrophysics.",
    group: "empire",
    baseOre: 200,
    baseCrystal: 1000,
    baseDeuterium: 200,
    costFactor: 2,
    lab: 3,
    requires: [],
  },
  {
    id: "computer_tech",
    name: "Computer technology",
    blurb: "Adds one fleet slot per level.",
    group: "empire",
    baseOre: 0,
    baseCrystal: 400,
    baseDeuterium: 600,
    costFactor: 2,
    lab: 1,
    requires: [],
  },
  {
    id: "astrophysics",
    name: "Astrophysics",
    blurb: "One extra colony every two levels. This is the technology whose cost rises by 1.75 instead of doubling.",
    group: "empire",
    baseOre: 4000,
    baseCrystal: 8000,
    baseDeuterium: 4000,
    costFactor: 1.75,
    lab: 3,
    requires: [
      { id: "espionage_tech", level: 4 },
      { id: "impulse_drive", level: 3 },
    ],
  },
  {
    id: "intergalactic_research_network",
    name: "Intergalactic Research Network",
    blurb: "Links one additional research lab per level.",
    group: "empire",
    baseOre: 240000,
    baseCrystal: 400000,
    baseDeuterium: 160000,
    costFactor: 2,
    lab: 10,
    requires: [
      { id: "computer_tech", level: 8 },
      { id: "hyperspace_tech", level: 8 },
    ],
  },
  {
    id: "graviton_tech",
    name: "Graviton technology",
    blurb: "Required for the deathstar. The wiki cost is 300,000 energy, and only level 1 is useful.",
    group: "empire",
    baseOre: 0,
    baseCrystal: 0,
    baseDeuterium: 0,
    costFactor: 2,
    lab: 12,
    requires: [],
    energy: 300000,
  },
  {
    id: "weapons_tech",
    name: "Weapons technology",
    blurb: "Adds 10% attack per level to ships and defences.",
    group: "combat",
    baseOre: 800,
    baseCrystal: 200,
    baseDeuterium: 0,
    costFactor: 2,
    lab: 4,
    requires: [],
  },
  {
    id: "shielding_tech",
    name: "Shielding technology",
    blurb: "Adds 10% shield strength per level.",
    group: "combat",
    baseOre: 200,
    baseCrystal: 600,
    baseDeuterium: 0,
    costFactor: 2,
    lab: 6,
    requires: [{ id: "energy_tech", level: 3 }],
  },
  {
    id: "armour_tech",
    name: "Armour technology",
    blurb: "Adds 10% hull per level.",
    group: "combat",
    baseOre: 1000,
    baseCrystal: 0,
    baseDeuterium: 0,
    costFactor: 2,
    lab: 2,
    requires: [],
  },
];

type Rf = readonly [string, number];

export type ShipResearch = TechRequirement & { upgrade?: boolean };

export type ShipStat = {
  id: string;
  name: string;
  cost: { ore: number; crystal: number; deuterium: number };
  hull: number;
  shield: number;
  attack: number;
  cargo: number;
  speed: number;
  speedUpgraded?: number;
  fuel: number;
  fuelUpgraded?: number;
  shipyard: number;
  research: ShipResearch[];
  rapidFireAgainst: readonly Rf[];
  rapidFireFrom: readonly Rf[];
  note?: string;
};

const probeSatCrawler: readonly Rf[] = [
  ["Espionage probe", 5],
  ["Solar satellite", 5],
  ["Crawler", 5],
];

export const SHIPS: ShipStat[] = [
  {
    id: "light_fighter",
    name: "Light fighter",
    cost: { ore: 3000, crystal: 1000, deuterium: 0 },
    hull: 4000,
    shield: 10,
    attack: 50,
    cargo: 50,
    speed: 12500,
    fuel: 20,
    shipyard: 1,
    research: [{ id: "combustion_drive", level: 1 }],
    rapidFireAgainst: probeSatCrawler,
    rapidFireFrom: [
      ["Cruiser", 6],
      ["Pathfinder", 3],
      ["Deathstar", 200],
    ],
  },
  {
    id: "heavy_fighter",
    name: "Heavy fighter",
    cost: { ore: 6000, crystal: 4000, deuterium: 0 },
    hull: 10000,
    shield: 25,
    attack: 150,
    cargo: 100,
    speed: 10000,
    fuel: 75,
    shipyard: 3,
    research: [
      { id: "impulse_drive", level: 2 },
      { id: "armour_tech", level: 2 },
    ],
    rapidFireAgainst: [["Small cargo", 3], ...probeSatCrawler],
    rapidFireFrom: [
      ["Battlecruiser", 4],
      ["Pathfinder", 2],
      ["Deathstar", 100],
    ],
  },
  {
    id: "cruiser",
    name: "Cruiser",
    cost: { ore: 20000, crystal: 7000, deuterium: 2000 },
    hull: 27000,
    shield: 50,
    attack: 400,
    cargo: 800,
    speed: 15000,
    fuel: 300,
    shipyard: 5,
    research: [
      { id: "impulse_drive", level: 4 },
      { id: "ion_tech", level: 2 },
    ],
    rapidFireAgainst: [
      ["Light fighter", 6],
      ["Rocket launcher", 10],
      ...probeSatCrawler,
    ],
    rapidFireFrom: [
      ["Battlecruiser", 4],
      ["Pathfinder", 3],
      ["Deathstar", 33],
    ],
  },
  {
    id: "battleship",
    name: "Battleship",
    cost: { ore: 45000, crystal: 15000, deuterium: 0 },
    hull: 60000,
    shield: 200,
    attack: 1000,
    cargo: 1500,
    speed: 10000,
    fuel: 500,
    shipyard: 7,
    research: [{ id: "hyperspace_drive", level: 4 }],
    rapidFireAgainst: [["Pathfinder", 5], ...probeSatCrawler],
    rapidFireFrom: [
      ["Battlecruiser", 7],
      ["Reaper", 7],
      ["Deathstar", 30],
    ],
  },
  {
    id: "battlecruiser",
    name: "Battlecruiser",
    cost: { ore: 30000, crystal: 40000, deuterium: 15000 },
    hull: 70000,
    shield: 400,
    attack: 700,
    cargo: 750,
    speed: 10000,
    fuel: 250,
    shipyard: 8,
    research: [
      { id: "hyperspace_drive", level: 5 },
      { id: "hyperspace_tech", level: 5 },
      { id: "laser_tech", level: 12 },
    ],
    rapidFireAgainst: [
      ["Small cargo", 3],
      ["Large cargo", 3],
      ["Heavy fighter", 4],
      ["Cruiser", 4],
      ["Battleship", 7],
      ["Espionage probe", 44],
      ["Solar satellite", 5],
      ["Crawler", 5],
    ],
    rapidFireFrom: [
      ["Destroyer", 2],
      ["Deathstar", 15],
    ],
    note: "The wiki lists rapid fire 44 against espionage probes.",
  },
  {
    id: "bomber",
    name: "Bomber",
    cost: { ore: 50000, crystal: 25000, deuterium: 15000 },
    hull: 75000,
    shield: 500,
    attack: 1000,
    cargo: 500,
    speed: 4000,
    speedUpgraded: 5000,
    fuel: 700,
    shipyard: 8,
    research: [
      { id: "impulse_drive", level: 6 },
      { id: "plasma_tech", level: 5 },
      { id: "hyperspace_drive", level: 8, upgrade: true },
    ],
    rapidFireAgainst: [
      ["Rocket launcher", 20],
      ["Light laser", 20],
      ["Heavy laser", 10],
      ["Ion cannon", 10],
      ["Gauss cannon", 5],
      ["Plasma turret", 5],
      ...probeSatCrawler,
    ],
    rapidFireFrom: [
      ["Reaper", 4],
      ["Deathstar", 25],
    ],
  },
  {
    id: "destroyer",
    name: "Destroyer",
    cost: { ore: 60000, crystal: 50000, deuterium: 15000 },
    hull: 110000,
    shield: 500,
    attack: 2000,
    cargo: 2000,
    speed: 5000,
    fuel: 1000,
    shipyard: 9,
    research: [
      { id: "hyperspace_drive", level: 6 },
      { id: "hyperspace_tech", level: 5 },
    ],
    rapidFireAgainst: [
      ["Battlecruiser", 2],
      ["Light laser", 10],
      ...probeSatCrawler,
    ],
    rapidFireFrom: [
      ["Reaper", 3],
      ["Deathstar", 5],
    ],
  },
  {
    id: "deathstar",
    name: "Deathstar",
    cost: { ore: 5000000, crystal: 4000000, deuterium: 1000000 },
    hull: 9000000,
    shield: 50000,
    attack: 200000,
    cargo: 1000000,
    speed: 100,
    fuel: 1,
    shipyard: 12,
    research: [
      { id: "hyperspace_drive", level: 7 },
      { id: "hyperspace_tech", level: 6 },
      { id: "graviton_tech", level: 1 },
    ],
    rapidFireAgainst: [
      ["Espionage probe", 1250],
      ["Solar satellite", 1250],
      ["Crawler", 1250],
      ["Small cargo", 250],
      ["Large cargo", 250],
      ["Colony ship", 250],
      ["Recycler", 250],
      ["Light fighter", 200],
      ["Rocket launcher", 200],
      ["Light laser", 200],
      ["Heavy fighter", 100],
      ["Heavy laser", 100],
      ["Ion cannon", 100],
      ["Gauss cannon", 50],
      ["Cruiser", 33],
      ["Battleship", 30],
      ["Reaper", 30],
      ["Bomber", 25],
      ["Battlecruiser", 15],
      ["Pathfinder", 10],
      ["Destroyer", 5],
    ],
    rapidFireFrom: [],
    note: "The pathfinder page says the deathstar shoots it at 30, and the reaper page says 10. This card uses the deathstar page: pathfinder 10, reaper 30.",
  },
  {
    id: "small_cargo",
    name: "Small cargo",
    cost: { ore: 2000, crystal: 2000, deuterium: 0 },
    hull: 4000,
    shield: 10,
    attack: 5,
    cargo: 5000,
    speed: 5000,
    speedUpgraded: 10000,
    fuel: 10,
    fuelUpgraded: 20,
    shipyard: 2,
    research: [
      { id: "combustion_drive", level: 2 },
      { id: "impulse_drive", level: 5, upgrade: true },
    ],
    rapidFireAgainst: probeSatCrawler,
    rapidFireFrom: [
      ["Heavy fighter", 3],
      ["Battlecruiser", 3],
      ["Deathstar", 250],
    ],
    note: "Impulse Drive 5 doubles speed and fuel.",
  },
  {
    id: "large_cargo",
    name: "Large cargo",
    cost: { ore: 6000, crystal: 6000, deuterium: 0 },
    hull: 12000,
    shield: 25,
    attack: 5,
    cargo: 25000,
    speed: 7500,
    fuel: 50,
    shipyard: 4,
    research: [{ id: "combustion_drive", level: 6 }],
    rapidFireAgainst: probeSatCrawler,
    rapidFireFrom: [
      ["Battlecruiser", 3],
      ["Deathstar", 250],
    ],
  },
  {
    id: "colony_ship",
    name: "Colony ship",
    cost: { ore: 10000, crystal: 20000, deuterium: 10000 },
    hull: 30000,
    shield: 100,
    attack: 50,
    cargo: 7500,
    speed: 2500,
    fuel: 1000,
    shipyard: 4,
    research: [{ id: "impulse_drive", level: 3 }],
    rapidFireAgainst: probeSatCrawler,
    rapidFireFrom: [["Deathstar", 250]],
  },
  {
    id: "recycler",
    name: "Recycler",
    cost: { ore: 10000, crystal: 6000, deuterium: 2000 },
    hull: 16000,
    shield: 10,
    attack: 1,
    cargo: 20000,
    speed: 2000,
    fuel: 300,
    shipyard: 4,
    research: [
      { id: "combustion_drive", level: 6 },
      { id: "shielding_tech", level: 2 },
    ],
    rapidFireAgainst: probeSatCrawler,
    rapidFireFrom: [["Deathstar", 250]],
  },
  {
    id: "espionage_probe",
    name: "Espionage probe",
    cost: { ore: 0, crystal: 1000, deuterium: 0 },
    hull: 1000,
    shield: 0.01,
    attack: 0.01,
    cargo: 5,
    speed: 100000000,
    fuel: 1,
    shipyard: 3,
    research: [
      { id: "combustion_drive", level: 3 },
      { id: "espionage_tech", level: 2 },
    ],
    rapidFireAgainst: [],
    rapidFireFrom: [
      ["Most ships", 5],
      ["Deathstar", 1250],
    ],
  },
  {
    id: "reaper",
    name: "Reaper",
    cost: { ore: 85000, crystal: 55000, deuterium: 20000 },
    hull: 140000,
    shield: 700,
    attack: 2800,
    cargo: 10000,
    speed: 7000,
    fuel: 1100,
    shipyard: 10,
    research: [
      { id: "hyperspace_drive", level: 7 },
      { id: "hyperspace_tech", level: 6 },
      { id: "shielding_tech", level: 6 },
    ],
    rapidFireAgainst: [
      ["Battleship", 7],
      ["Bomber", 4],
      ["Destroyer", 3],
      ...probeSatCrawler,
    ],
    rapidFireFrom: [
      ["Deathstar", 10],
      ["Ion cannon", 2],
    ],
    note: "The ship's own page lists cargo 10,000 and fuel 1,100. The overview table lists cargo 7,000 and fuel 900. Rapid fire from the deathstar is 10 on this page and 30 on the deathstar page.",
  },
  {
    id: "pathfinder",
    name: "Pathfinder",
    cost: { ore: 8000, crystal: 15000, deuterium: 8000 },
    hull: 23000,
    shield: 100,
    attack: 200,
    cargo: 10000,
    speed: 12000,
    fuel: 300,
    shipyard: 5,
    research: [{ id: "hyperspace_drive", level: 2 }],
    rapidFireAgainst: [
      ["Cruiser", 3],
      ["Light fighter", 3],
      ["Heavy fighter", 2],
      ...probeSatCrawler,
    ],
    rapidFireFrom: [
      ["Battleship", 5],
      ["Deathstar", 30],
    ],
    note: "The ship's own page lists cargo 10,000 and speed 12,000. The overview table swaps those.",
  },
  {
    id: "crawler",
    name: "Crawler",
    cost: { ore: 2000, crystal: 2000, deuterium: 1000 },
    hull: 4000,
    shield: 1,
    attack: 1,
    cargo: 0,
    speed: 0,
    fuel: 0,
    shipyard: 5,
    research: [
      { id: "combustion_drive", level: 4 },
      { id: "armour_tech", level: 4 },
      { id: "laser_tech", level: 4 },
    ],
    rapidFireAgainst: [],
    rapidFireFrom: [
      ["Most ships", 5],
      ["Deathstar", 1250],
    ],
    note: "Stays on the planet. Each crawler adds 0.02% mine production.",
  },
  {
    id: "solar_satellite",
    name: "Solar satellite",
    cost: { ore: 0, crystal: 2000, deuterium: 500 },
    hull: 2000,
    shield: 1,
    attack: 1,
    cargo: 0,
    speed: 0,
    fuel: 0,
    shipyard: 1,
    research: [],
    rapidFireAgainst: [],
    rapidFireFrom: [
      ["Most ships", 5],
      ["Deathstar", 1250],
    ],
    note: "Does not fly. Energy is floor((average temperature + 160) / 6).",
  },
];

export type FacilityId =
  | "robotics_factory"
  | "shipyard"
  | "research_lab"
  | "alliance_depot"
  | "missile_silo"
  | "nanite_factory"
  | "terraformer"
  | "lunar_base"
  | "phalanx_sensor"
  | "stargate"
  | "space_station";

export type FacilityRequirement =
  | { kind: "facility"; id: FacilityId; level: number }
  | { kind: "research"; id: ResearchId; level: number };

export type FacilityStat = {
  id: FacilityId;
  name: string;
  blurb: string;
  cost: { ore: number; crystal: number; deuterium: number };
  costFactor: number;
  energy?: number;
  moon: boolean;
  requires: FacilityRequirement[];
  note?: string;
};

export const FACILITIES: FacilityStat[] = [
  {
    id: "robotics_factory",
    name: "Robotics factory",
    blurb: "Divides building time by 1 plus this level (level 1 halves it). Required for the shipyard.",
    cost: { ore: 400, crystal: 120, deuterium: 200 },
    costFactor: 2,
    moon: false,
    requires: [],
  },
  {
    id: "shipyard",
    name: "Shipyard",
    blurb: "Builds ships and defences. Each hull still lists the shipyard level it needs.",
    cost: { ore: 400, crystal: 200, deuterium: 100 },
    costFactor: 2,
    moon: false,
    requires: [{ kind: "facility", id: "robotics_factory", level: 2 }],
  },
  {
    id: "research_lab",
    name: "Research lab",
    blurb: "Each technology still lists the lab level it needs. Higher labs also shorten research.",
    cost: { ore: 200, crystal: 400, deuterium: 200 },
    costFactor: 2,
    moon: false,
    requires: [],
  },
  {
    id: "alliance_depot",
    name: "Alliance depot",
    blurb: "Supports a parked allied fleet with deuterium. Only useful in universes with alliance combat.",
    cost: { ore: 20000, crystal: 40000, deuterium: 0 },
    costFactor: 2,
    moon: false,
    requires: [],
  },
  {
    id: "missile_silo",
    name: "Missile silo",
    blurb: "Ten missile slots per level. Anti-ballistic missiles need silo 2. Interplanetary missiles need silo 4.",
    cost: { ore: 20000, crystal: 20000, deuterium: 1000 },
    costFactor: 2,
    moon: false,
    requires: [{ kind: "facility", id: "shipyard", level: 1 }],
  },
  {
    id: "nanite_factory",
    name: "Nanite factory",
    blurb: "Halves construction time for buildings, ships, and defences at each level.",
    cost: { ore: 1000000, crystal: 500000, deuterium: 100000 },
    costFactor: 2,
    moon: false,
    requires: [
      { kind: "facility", id: "robotics_factory", level: 10 },
      { kind: "facility", id: "shipyard", level: 1 },
      { kind: "research", id: "computer_tech", level: 10 },
    ],
  },
  {
    id: "terraformer",
    name: "Terraformer",
    blurb: "Adds 5 fields per level and uses 1 of them. Costs crystal, deuterium, and energy, not metal.",
    cost: { ore: 0, crystal: 50000, deuterium: 100000 },
    costFactor: 2,
    energy: 1000,
    moon: false,
    requires: [
      { kind: "facility", id: "nanite_factory", level: 1 },
      { kind: "research", id: "energy_tech", level: 12 },
    ],
  },
  {
    id: "lunar_base",
    name: "Lunar base",
    blurb: "Adds 3 moon fields per level. Moon only.",
    cost: { ore: 20000, crystal: 40000, deuterium: 20000 },
    costFactor: 2,
    moon: true,
    requires: [],
  },
  {
    id: "phalanx_sensor",
    name: "Sensor phalanx",
    blurb: "Scans a planet for incoming fleets. Costs 5,000 deuterium per scan. Moon only.",
    cost: { ore: 20000, crystal: 40000, deuterium: 20000 },
    costFactor: 2,
    moon: true,
    requires: [{ kind: "facility", id: "lunar_base", level: 1 }],
  },
  {
    id: "stargate",
    name: "Jump gate",
    blurb: "Sends a fleet instantly between jump gates. Moon only. Cooldown starts at one hour.",
    cost: { ore: 2000000, crystal: 4000000, deuterium: 2000000 },
    costFactor: 2,
    moon: true,
    requires: [
      { kind: "facility", id: "lunar_base", level: 1 },
      { kind: "research", id: "hyperspace_tech", level: 7 },
    ],
  },
  {
    id: "space_station",
    name: "Space dock",
    blurb: "Can recover wreckage after a large battle over this planet. Repair time is 12 hours at level 1.",
    cost: { ore: 200, crystal: 0, deuterium: 50 },
    costFactor: 5,
    moon: false,
    requires: [{ kind: "facility", id: "shipyard", level: 2 }],
    note: "The sprite is labelled space station. The wiki building is Space Dock. Cost factor is 5.",
  },
];
