export type StellarEventKind = "solar_flare" | "ion_storm" | "meteor_shower";

export type StellarEventSpec = {
  id: StellarEventKind;
  name: string;
  badge: string;
  blurb: string;
  solarMultiplier: number;
  shieldMultiplier: number;
  flightTimeMultiplier: number;
  fuelMultiplier: number;
  miningSpeedMultiplier: number;
};

export const STELLAR_EVENTS: readonly StellarEventSpec[] = [
  {
    id: "solar_flare",
    name: "Solar Flare",
    badge: "+50% SOLAR · -30% SHIELDS",
    blurb:
      "Coronal mass ejection supercharges solar plants and solar satellites (+50% energy), but radiation interference weakens shields and counter-espionage by 30%.",
    solarMultiplier: 1.5,
    shieldMultiplier: 0.7,
    flightTimeMultiplier: 1,
    fuelMultiplier: 1,
    miningSpeedMultiplier: 1,
  },
  {
    id: "ion_storm",
    name: "Ion Storm",
    badge: "+50% FLIGHT TIME · 2× FUEL",
    blurb:
      "Charged nebula turbulence disrupts thrusters and navigation. Fleets flying into or out of this system take 50% longer and burn 2× deuterium fuel.",
    solarMultiplier: 1,
    shieldMultiplier: 1,
    flightTimeMultiplier: 1.5,
    fuelMultiplier: 2,
    miningSpeedMultiplier: 1,
  },
  {
    id: "meteor_shower",
    name: "Micrometeorite Shower",
    badge: "2× BELT MINING · BONUS CRYSTAL",
    blurb:
      "Dense mineral debris sweeps through the system's asteroid belts. Mining barges harvest at 2× speed and belts are seeded with bonus crystal.",
    solarMultiplier: 1,
    shieldMultiplier: 1,
    flightTimeMultiplier: 1,
    fuelMultiplier: 1,
    miningSpeedMultiplier: 2,
  },
] as const;

export function stellarEventSpec(id: string | null | undefined): StellarEventSpec | undefined {
  return STELLAR_EVENTS.find((e) => e.id === id);
}

export type StellarEventRow = {
  id: number;
  galaxy: number;
  system: number;
  kind: StellarEventKind;
  starts_at: string;
  ends_at: string;
};

export type PirateStrongholdRow = {
  id: number;
  galaxy: number;
  system: number;
  slot: number;
  name: string;
  tier: number;
  ships: Record<string, number>;
  defenses: Record<string, number>;
  vault_ore: number;
  vault_crystal: number;
  vault_deuterium: number;
  max_hull: number;
  current_hull: number;
  expires_at: string;
};

export type RelicId = "overclock_drill" | "phase_cloak" | "subspace_beacon" | "repair_nanites";

export type RelicSpec = {
  id: RelicId;
  name: string;
  badge: string;
  blurb: string;
  mineProductionMultiplier: number;
  mineEnergyMultiplier: number;
  plunderProtectedFraction: number;
  fuelMultiplier: number;
  defenceRebuildChance: number;
};

export const MAX_PLANET_RELICS = 2;

export const RELICS: readonly RelicSpec[] = [
  {
    id: "overclock_drill",
    name: "Overclocked Drill Core",
    badge: "+15% ORE & CRYSTAL · +20% MINE ENERGY",
    blurb:
      "Precursor plasma drill governor. Boosts Ore and Crystal mine output on this planet by +15%, while increasing mine energy consumption by +20%.",
    mineProductionMultiplier: 1.15,
    mineEnergyMultiplier: 1.2,
    plunderProtectedFraction: 0,
    fuelMultiplier: 1,
    defenceRebuildChance: 0.7,
  },
  {
    id: "phase_cloak",
    name: "Phase-Shift Cloak",
    badge: "25% VAULT SHIELDED",
    blurb:
      "Subspace phase emitter that conceals 25% of this planet's stockpiled Ore, Crystal, and Deuterium from enemy espionage scans and raid plunder.",
    mineProductionMultiplier: 1,
    mineEnergyMultiplier: 1,
    plunderProtectedFraction: 0.25,
    fuelMultiplier: 1,
    defenceRebuildChance: 0.7,
  },
  {
    id: "subspace_beacon",
    name: "Subspace Beacon",
    badge: "-20% FLEET FUEL",
    blurb:
      "Anchors a local warp corridor. Fleets launching from this planet burn 20% less deuterium fuel on all outbound missions.",
    mineProductionMultiplier: 1,
    mineEnergyMultiplier: 1,
    plunderProtectedFraction: 0,
    fuelMultiplier: 0.8,
    defenceRebuildChance: 0.7,
  },
  {
    id: "repair_nanites",
    name: "Automated Repair Nanites",
    badge: "85% DEFENCE REBUILD",
    blurb:
      "Self-replicating hull welders stationed under the defence grid. Raises post-battle defence reconstruction chance from 70% to 85%.",
    mineProductionMultiplier: 1,
    mineEnergyMultiplier: 1,
    plunderProtectedFraction: 0,
    fuelMultiplier: 1,
    defenceRebuildChance: 0.85,
  },
] as const;

export function relicSpec(id: string | null | undefined): RelicSpec | undefined {
  return RELICS.find((r) => r.id === id);
}

export type EmpireMechanicsState = {
  stellar_events: StellarEventRow[];
  strongholds: PirateStrongholdRow[];
  relic_inventory: Record<RelicId, number>;
  planet_relics: Record<string, RelicId[]>;
};

export function planetRelicModifiers(equipped: readonly string[] | undefined): {
  mineProductionMultiplier: number;
  mineEnergyMultiplier: number;
  plunderProtectedFraction: number;
  fuelMultiplier: number;
  defenceRebuildChance: number;
} {
  let mineProductionMultiplier = 1;
  let mineEnergyMultiplier = 1;
  let plunderProtectedFraction = 0;
  let fuelMultiplier = 1;
  let defenceRebuildChance = 0.7;

  for (const id of (equipped ?? []).slice(0, MAX_PLANET_RELICS)) {
    const spec = relicSpec(id);
    if (!spec) continue;
    mineProductionMultiplier *= spec.mineProductionMultiplier;
    mineEnergyMultiplier *= spec.mineEnergyMultiplier;
    plunderProtectedFraction = Math.min(0.75, plunderProtectedFraction + spec.plunderProtectedFraction);
    fuelMultiplier *= spec.fuelMultiplier;
    defenceRebuildChance = Math.max(defenceRebuildChance, spec.defenceRebuildChance);
  }

  return {
    mineProductionMultiplier,
    mineEnergyMultiplier,
    plunderProtectedFraction,
    fuelMultiplier,
    defenceRebuildChance,
  };
}

export const MECHANICS_GUIDE_SECTIONS = [
  {
    id: "stellar_events",
    title: "1. System-Wide Stellar Events (Dynamic Star Weather)",
    summary:
      "Temporary cosmic weather phenomena that sweep through solar systems for 3 hours, altering solar output, fleet logistics, combat shields, and asteroid belt yields.",
    details: [
      "Solar Flare (+50% Solar Energy, -30% Shields): Solar plants and solar satellites in the system generate 1.5× energy, making it easier to run high-level mines or Overclocked Drill Cores. However, radiation interference reduces shield strength by 30% during combat in that system.",
      "Ion Storm (+50% Flight Time, 2× Deuterium Fuel): Charged nebula turbulence slows fleet travel into or out of the system by 50% and doubles deuterium fuel consumption.",
      "Micrometeorite Shower (2× Belt Mining Speed & Crystal Top-Up): Asteroid belts (slots 17 and 18) in the system yield 2× mining barge harvest speed and receive a fresh injection of crystal when the shower begins.",
      "Gameplay Impact: Encourages commanders to check the Galaxy map and Comms daily, time offensive strikes during shield-weakening Solar Flares, and relocate mining barges to systems experiencing Micrometeorite Showers.",
    ],
  },
  {
    id: "pirate_strongholds",
    title: "2. Pirate Strongholds & Bounty Hunts (Co-op / Competitive PvE)",
    summary:
      "Heavily fortified Pirate Strongholds spawn on empty galaxy slots for 24 hours with a persistent garrison and resource vault that any commander can attack.",
    details: [
      "Persistent Garrison: Each stronghold has a multi-hull pirate fleet (Light Fighters, Heavy Fighters, Cruisers, Battleships) and planetary defence battery, plus a vault of Ore, Crystal, and Deuterium.",
      "Shared Damage & Instant Bounties: Damage dealt to a stronghold's ships and defences persists across attacks from any commander. Every strike earns an immediate Bounty Payout proportional to the pirate hull value destroyed.",
      "Final Blow Jackpot & Relic Drop: The commander who wipes out the remaining garrison claims the stronghold's resource vault and recovers a guaranteed Ancient Relic.",
      "Gameplay Impact: Gives fleet builders an active PvE combat target on the galaxy map even when other commanders are offline or under bash protection, creating a race to claim the finishing jackpot.",
    ],
  },
  {
    id: "ancient_relics",
    title: "3. Ancient Relics & Planetary Command Core Modules",
    summary:
      "Collectible precursor modules recovered from Expeditions (slot 16), Pirate Strongholds, and raids. Up to 2 relics can be socketed into each planet's Command Core.",
    details: [
      "Overclocked Drill Core: +15% Ore and Crystal mine production on the socketed planet, at the cost of +20% mine energy consumption.",
      "Phase-Shift Cloak: Shields 25% of the planet's stockpiled Ore, Crystal, and Deuterium from enemy espionage scans and raid plunder.",
      "Subspace Beacon: Reduces deuterium fuel consumption by 20% for all fleets launching from the socketed planet.",
      "Automated Repair Nanites: Raises post-battle defence rebuild chance from 70% to 85% on that world.",
      "Gameplay Impact: Makes every Expedition and stronghold raid exciting beyond raw resources and lets commanders specialize individual colonies (e.g., a fortified mining world vs. a low-fuel fleet staging base).",
    ],
  },
] as const;
