import {
  BUILDINGS,
  type BuildingId,
  type DefenceCounts,
  type DefenceId,
  PIRATE_WAVE_CAP,
  FACILITIES,
  type FacilityId,
  RAIDER_CARGO,
  RAIDER_COST,
  RAIDER_BUILD_SECONDS,
  buildingCost,
  buildingTimeSeconds,
  crystalProductionPerHour,
  defenceSpec,
  defenceTimeSeconds,
  defenceUnitCount,
  energyFactor,
  energyNow,
  facilitySpec,
  fieldsUsed,
  isBuildingId,
  isFacilityId,
  flightSeconds,
  formatLostGuns,
  harvestAmount,
  isDefenceId,
  mineProductionPerHour,
  pirateCombat,
  pirateIntervalSeconds,
  pirateWaveSize,
  progressToward,
  raidHaul,
  researchSpec,
  researchTechCost,
  shipSpec,
  unmetFacility,
  unmetResearch,
  researchTimeSeconds,
  type ResearchId,
  STARTING_CRYSTAL,
  STARTING_ORE,
  STARTING_RAIDERS,
  type StarType,
  storageCap,
  cancelRefund,
} from "./catalog";

export type { BuildingId, DefenceId, ResearchId };

export type SimPlanet = {
  id: number;
  ownerId: string | null;
  galaxy?: number;
  system: number;
  slot: number;
  starType?: StarType;
  name: string;
  ore: number;
  crystal: number;
  deuterium: number;
  lastHarvestedAt: number;
  oreMine: number;
  crystalMine: number;
  deuteriumExtractor: number;
  powerPlant: number;
  fusionReactor: number;
  oreStorage: number;
  crystalStorage: number;
  deuteriumStorage: number;
  roboticsFactory: number;
  shipyard: number;
  researchLab: number;
  allianceDepot: number;
  missileSilo: number;
  naniteFactory: number;
  terraformer: number;
  lunarBase: number;
  phalanxSensor: number;
  stargate: number;
  spaceStation: number;
  maxFields?: number;
  upgradeBuilding: BuildingId | null;
  upgradeCompletesAt: number | null;
  smallShieldDome: number;
  largeShieldDome: number;
  rocketLauncher: number;
  lightLaser: number;
  heavyLaser: number;
  ionCannon: number;
  gaussCannon: number;
  plasmaTurret: number;
  antiballisticMissile: number;
  interplanetaryMissile: number;
  defenceBuilding: DefenceId | null;
  defencesQueued: number;
  defenceCompletesAt: number | null;
};

export const EMPTY_FACILITIES = {
  roboticsFactory: 0,
  shipyard: 0,
  researchLab: 0,
  allianceDepot: 0,
  missileSilo: 0,
  naniteFactory: 0,
  terraformer: 0,
  lunarBase: 0,
  phalanxSensor: 0,
  stargate: 0,
  spaceStation: 0,
};

export function facilityLevel(planet: SimPlanet, id: FacilityId): number {
  switch (id) {
    case "robotics_factory":
      return planet.roboticsFactory;
    case "shipyard":
      return planet.shipyard;
    case "research_lab":
      return planet.researchLab;
    case "alliance_depot":
      return planet.allianceDepot;
    case "missile_silo":
      return planet.missileSilo;
    case "nanite_factory":
      return planet.naniteFactory;
    case "terraformer":
      return planet.terraformer;
    case "lunar_base":
      return planet.lunarBase;
    case "phalanx_sensor":
      return planet.phalanxSensor;
    case "stargate":
      return planet.stargate;
    case "space_station":
      return planet.spaceStation;
  }
}

export function facilitiesUsed(planet: SimPlanet): number {
  return FACILITIES.filter((facility) => !facility.moon).reduce(
    (sum, facility) => sum + facilityLevel(planet, facility.id),
    0,
  );
}

export function totalFieldsUsed(planet: SimPlanet): number {
  return fieldsUsed(
    planet.oreMine,
    planet.crystalMine,
    planet.powerPlant,
    planet.oreStorage,
    planet.crystalStorage,
    facilitiesUsed(planet),
    planet.deuteriumExtractor,
    planet.deuteriumStorage,
    planet.fusionReactor,
  );
}

export const EMPTY_DEFENCES = {
  smallShieldDome: 0,
  largeShieldDome: 0,
  rocketLauncher: 0,
  lightLaser: 0,
  heavyLaser: 0,
  ionCannon: 0,
  gaussCannon: 0,
  plasmaTurret: 0,
  antiballisticMissile: 0,
  interplanetaryMissile: 0,
  defenceBuilding: null as DefenceId | null,
  defencesQueued: 0,
  defenceCompletesAt: null as number | null,
};

export function defenceOwned(planet: SimPlanet, id: DefenceId): number {
  switch (id) {
    case "small_shield_dome":
      return planet.smallShieldDome;
    case "large_shield_dome":
      return planet.largeShieldDome;
    case "rocket_launcher":
      return planet.rocketLauncher;
    case "light_laser":
      return planet.lightLaser;
    case "heavy_laser":
      return planet.heavyLaser;
    case "ion_cannon":
      return planet.ionCannon;
    case "gauss_cannon":
      return planet.gaussCannon;
    case "plasma_turret":
      return planet.plasmaTurret;
    case "antiballistic_missile":
      return planet.antiballisticMissile;
    case "interplanetary_missile":
      return planet.interplanetaryMissile;
  }
}

function applyDefence(planet: SimPlanet, id: DefenceId): SimPlanet {
  const next = { ...planet };
  switch (id) {
    case "small_shield_dome":
      next.smallShieldDome = 1;
      break;
    case "large_shield_dome":
      next.largeShieldDome = 1;
      break;
    case "rocket_launcher":
      next.rocketLauncher += 1;
      break;
    case "light_laser":
      next.lightLaser += 1;
      break;
    case "heavy_laser":
      next.heavyLaser += 1;
      break;
    case "ion_cannon":
      next.ionCannon += 1;
      break;
    case "gauss_cannon":
      next.gaussCannon += 1;
      break;
    case "plasma_turret":
      next.plasmaTurret += 1;
      break;
    case "antiballistic_missile":
      next.antiballisticMissile += 1;
      break;
    case "interplanetary_missile":
      next.interplanetaryMissile += 1;
      break;
  }
  return next;
}

export function defenceCountsOf(planet: SimPlanet): DefenceCounts {
  return {
    small_shield_dome: planet.smallShieldDome,
    large_shield_dome: planet.largeShieldDome,
    rocket_launcher: planet.rocketLauncher,
    light_laser: planet.lightLaser,
    heavy_laser: planet.heavyLaser,
    ion_cannon: planet.ionCannon,
    gauss_cannon: planet.gaussCannon,
    plasma_turret: planet.plasmaTurret,
    antiballistic_missile: planet.antiballisticMissile,
    interplanetary_missile: planet.interplanetaryMissile,
  };
}

export function applyDefenceCounts(planet: SimPlanet, counts: DefenceCounts): SimPlanet {
  return {
    ...planet,
    smallShieldDome: counts.small_shield_dome,
    largeShieldDome: counts.large_shield_dome,
    rocketLauncher: counts.rocket_launcher,
    lightLaser: counts.light_laser,
    heavyLaser: counts.heavy_laser,
    ionCannon: counts.ion_cannon,
    gaussCannon: counts.gauss_cannon,
    plasmaTurret: counts.plasma_turret,
    antiballisticMissile: counts.antiballistic_missile,
    interplanetaryMissile: counts.interplanetary_missile,
  };
}

export type SimEmpire = {
  userId: string;
  homePlanetId: number;
  propulsionLevel: number;
  energyTech: number;
  laserTech: number;
  ionTech: number;
  hyperspaceTech: number;
  plasmaTech: number;
  impulseDrive: number;
  hyperspaceDrive: number;
  espionageTech: number;
  computerTech: number;
  astrophysics: number;
  intergalacticResearchNetwork: number;
  gravitonTech: number;
  weaponsTech: number;
  shieldingTech: number;
  armourTech: number;
  raiders: number;
  raidersQueued: number;
  raiderCompletesAt: number | null;
  researchTech: ResearchId | null;
  researchCompletesAt: number | null;
  nextPirateAt: number | null;
};

export const EMPTY_RESEARCH = {
  energyTech: 0,
  laserTech: 0,
  ionTech: 0,
  hyperspaceTech: 0,
  plasmaTech: 0,
  impulseDrive: 0,
  hyperspaceDrive: 0,
  espionageTech: 0,
  computerTech: 0,
  astrophysics: 0,
  intergalacticResearchNetwork: 0,
  gravitonTech: 0,
  weaponsTech: 0,
  shieldingTech: 0,
  armourTech: 0,
  researchTech: null as ResearchId | null,
};

export type SimFleet = {
  id: number;
  ownerId: string;
  originPlanetId: number;
  destPlanetId: number;
  raiders: number;
  mission: "attack" | "return";
  arrivesAt: number;
  cargoOre: number;
  cargoCrystal: number;
  status: "en_route" | "completed";
  report: string | null;
};

export type SimReport = {
  title: string;
  body: string;
  lootOre: number;
  lootCrystal: number;
  createdAt: number;
};

export type SimWorld = {
  planets: SimPlanet[];
  empire: SimEmpire;
  fleets: SimFleet[];
  reports: SimReport[];
};

export function planetLevel(planet: SimPlanet, id: BuildingId): number {
  if (id === "ore_mine") return planet.oreMine;
  if (id === "crystal_mine") return planet.crystalMine;
  if (id === "deuterium_extractor") return planet.deuteriumExtractor;
  if (id === "power_plant") return planet.powerPlant;
  if (id === "fusion_reactor") return planet.fusionReactor;
  if (id === "ore_storage") return planet.oreStorage;
  if (id === "crystal_storage") return planet.crystalStorage;
  if (id === "deuterium_storage") return planet.deuteriumStorage;
  return facilityLevel(planet, id);
}

export function tickPlanet(planet: SimPlanet, at: number): SimPlanet {
  const elapsed = Math.max(0, (at - planet.lastHarvestedAt) / 1000);
  const factor = energyFactor(
    planet.oreMine,
    planet.crystalMine,
    planet.powerPlant,
    planet.starType,
    planet.deuteriumExtractor,
    planet.fusionReactor,
  );
  return {
    ...planet,
    ore: harvestAmount(
      planet.ore,
      mineProductionPerHour(planet.oreMine) * factor,
      elapsed,
      storageCap(planet.oreStorage),
    ),
    crystal: harvestAmount(
      planet.crystal,
      crystalProductionPerHour(planet.crystalMine) * factor,
      elapsed,
      storageCap(planet.crystalStorage),
    ),
    lastHarvestedAt: at,
  };
}

function completeUpgrade(planet: SimPlanet): SimPlanet {
  if (!planet.upgradeBuilding) return { ...planet, upgradeBuilding: null, upgradeCompletesAt: null };
  const next = { ...planet, upgradeBuilding: null, upgradeCompletesAt: null };
  if (planet.upgradeBuilding === "ore_mine") next.oreMine += 1;
  if (planet.upgradeBuilding === "crystal_mine") next.crystalMine += 1;
  if (planet.upgradeBuilding === "deuterium_extractor") next.deuteriumExtractor += 1;
  if (planet.upgradeBuilding === "power_plant") next.powerPlant += 1;
  if (planet.upgradeBuilding === "fusion_reactor") next.fusionReactor += 1;
  if (planet.upgradeBuilding === "ore_storage") next.oreStorage += 1;
  if (planet.upgradeBuilding === "crystal_storage") next.crystalStorage += 1;
  if (planet.upgradeBuilding === "deuterium_storage") next.deuteriumStorage += 1;
  if (planet.upgradeBuilding === "robotics_factory") next.roboticsFactory += 1;
  if (planet.upgradeBuilding === "shipyard") next.shipyard += 1;
  if (planet.upgradeBuilding === "research_lab") next.researchLab += 1;
  if (planet.upgradeBuilding === "alliance_depot") next.allianceDepot += 1;
  if (planet.upgradeBuilding === "missile_silo") next.missileSilo += 1;
  if (planet.upgradeBuilding === "nanite_factory") next.naniteFactory += 1;
  if (planet.upgradeBuilding === "terraformer") next.terraformer += 1;
  if (planet.upgradeBuilding === "lunar_base") next.lunarBase += 1;
  if (planet.upgradeBuilding === "phalanx_sensor") next.phalanxSensor += 1;
  if (planet.upgradeBuilding === "stargate") next.stargate += 1;
  if (planet.upgradeBuilding === "space_station") next.spaceStation += 1;
  return next;
}

export function catchUpPlanet(planet: SimPlanet, at: number): SimPlanet {
  let next = planet;
  if (next.upgradeCompletesAt != null && next.upgradeCompletesAt <= at) {
    const due = next.upgradeCompletesAt;
    next = completeUpgrade(tickPlanet(next, due));
  }
  while (next.defencesQueued > 0 && next.defenceBuilding && next.defenceCompletesAt != null && next.defenceCompletesAt <= at) {
    const building = next.defenceBuilding;
    const due = next.defenceCompletesAt;
    next = applyDefence(next, building);
    const remaining = next.defencesQueued - 1;
    if (remaining > 0) {
      next = {
        ...next,
        defencesQueued: remaining,
        defenceCompletesAt: due + defenceTimeSeconds(building) * 1000,
      };
    } else {
      next = { ...next, defenceBuilding: null, defenceCompletesAt: null, defencesQueued: 0 };
    }
  }
  return tickPlanet(next, at);
}

export function researchLevel(empire: SimEmpire, id: ResearchId): number {
  switch (id) {
    case "combustion_drive":
      return empire.propulsionLevel;
    case "energy_tech":
      return empire.energyTech;
    case "laser_tech":
      return empire.laserTech;
    case "ion_tech":
      return empire.ionTech;
    case "hyperspace_tech":
      return empire.hyperspaceTech;
    case "plasma_tech":
      return empire.plasmaTech;
    case "impulse_drive":
      return empire.impulseDrive;
    case "hyperspace_drive":
      return empire.hyperspaceDrive;
    case "espionage_tech":
      return empire.espionageTech;
    case "computer_tech":
      return empire.computerTech;
    case "astrophysics":
      return empire.astrophysics;
    case "intergalactic_research_network":
      return empire.intergalacticResearchNetwork;
    case "graviton_tech":
      return empire.gravitonTech;
    case "weapons_tech":
      return empire.weaponsTech;
    case "shielding_tech":
      return empire.shieldingTech;
    case "armour_tech":
      return empire.armourTech;
  }
}

function completeResearch(empire: SimEmpire): SimEmpire {
  const id = empire.researchTech ?? "combustion_drive";
  const next = { ...empire, researchTech: null, researchCompletesAt: null };
  switch (id) {
    case "combustion_drive":
      next.propulsionLevel += 1;
      break;
    case "energy_tech":
      next.energyTech += 1;
      break;
    case "laser_tech":
      next.laserTech += 1;
      break;
    case "ion_tech":
      next.ionTech += 1;
      break;
    case "hyperspace_tech":
      next.hyperspaceTech += 1;
      break;
    case "plasma_tech":
      next.plasmaTech += 1;
      break;
    case "impulse_drive":
      next.impulseDrive += 1;
      break;
    case "hyperspace_drive":
      next.hyperspaceDrive += 1;
      break;
    case "espionage_tech":
      next.espionageTech += 1;
      break;
    case "computer_tech":
      next.computerTech += 1;
      break;
    case "astrophysics":
      next.astrophysics += 1;
      break;
    case "intergalactic_research_network":
      next.intergalacticResearchNetwork += 1;
      break;
    case "graviton_tech":
      next.gravitonTech += 1;
      break;
    case "weapons_tech":
      next.weaponsTech += 1;
      break;
    case "shielding_tech":
      next.shieldingTech += 1;
      break;
    case "armour_tech":
      next.armourTech += 1;
      break;
  }
  return next;
}

export function catchUpEmpire(empire: SimEmpire, at: number): SimEmpire {
  let next = { ...empire };
  if (next.researchCompletesAt != null && next.researchCompletesAt <= at) {
    next = completeResearch(next);
  }
  while (next.raidersQueued > 0 && next.raiderCompletesAt != null && next.raiderCompletesAt <= at) {
    next.raiders += 1;
    next.raidersQueued -= 1;
    next.raiderCompletesAt =
      next.raidersQueued > 0 ? next.raiderCompletesAt + RAIDER_BUILD_SECONDS * 1000 : null;
  }
  return next;
}

function planetById(world: SimWorld, id: number): SimPlanet {
  const planet = world.planets.find((p) => p.id === id);
  if (!planet) throw new Error("Planet not found");
  return planet;
}

function replacePlanet(world: SimWorld, planet: SimPlanet): SimWorld {
  return { ...world, planets: world.planets.map((p) => (p.id === planet.id ? planet : p)) };
}

function resolveFleet(world: SimWorld, fleet: SimFleet, at: number): SimWorld {
  if (fleet.status !== "en_route" || fleet.arrivesAt > at) return world;

  const origin = planetById(world, fleet.originPlanetId);
  const dest = planetById(world, fleet.destPlanetId);

  if (fleet.mission === "attack") {
    const tickedDest = catchUpPlanet(dest, fleet.arrivesAt);
    const haul = raidHaul(tickedDest.ore, tickedDest.crystal, fleet.raiders * RAIDER_CARGO);
    const lootOre = haul.ore;
    const lootCrystal = haul.crystal;
    const looted: SimPlanet = {
      ...tickedDest,
      ore: tickedDest.ore - lootOre,
      crystal: tickedDest.crystal - lootCrystal,
    };
    const duration = flightSeconds(
      origin.system,
      origin.slot,
      dest.system,
      dest.slot,
      world.empire.propulsionLevel,
      origin.galaxy ?? 0,
      dest.galaxy ?? 0,
    );
    const returning: SimFleet = {
      ...fleet,
      mission: "return",
      cargoOre: lootOre,
      cargoCrystal: lootCrystal,
      arrivesAt: fleet.arrivesAt + duration * 1000,
      report: `Raid on ${dest.name}: +${lootOre} ore, +${lootCrystal} crystal.`,
    };
    const withPlanet = replacePlanet(world, looted);
    return {
      ...withPlanet,
      fleets: withPlanet.fleets.map((f) => (f.id === fleet.id ? returning : f)),
    };
  }

  const home = catchUpPlanet(origin, fleet.arrivesAt);
  const cappedHome: SimPlanet = {
    ...home,
    ore: Math.min(storageCap(home.oreStorage), home.ore + fleet.cargoOre),
    crystal: Math.min(storageCap(home.crystalStorage), home.crystal + fleet.cargoCrystal),
  };
  const completed: SimFleet = { ...fleet, status: "completed" };
  return {
    ...replacePlanet(world, cappedHome),
    empire: { ...world.empire, raiders: world.empire.raiders + fleet.raiders },
    fleets: world.fleets.map((f) => (f.id === fleet.id ? completed : f)),
    reports: [
      {
        title: `Fleet returned from ${dest.name}`,
        body: fleet.report ?? "The small cargo dumped their holds.",
        lootOre: fleet.cargoOre,
        lootCrystal: fleet.cargoCrystal,
        createdAt: fleet.arrivesAt,
      },
      ...world.reports,
    ],
  };
}

export function catchUpWorld(world: SimWorld, at: number): SimWorld {
  let next: SimWorld = {
    ...world,
    empire: catchUpEmpire(world.empire, at),
    planets: world.planets.map((p) =>
      p.id === world.empire.homePlanetId || p.ownerId === world.empire.userId ? catchUpPlanet(p, at) : p,
    ),
  };

  let guard = 0;
  while (guard < 50) {
    const due = next.fleets
      .filter((f) => f.status === "en_route" && f.arrivesAt <= at)
      .sort((a, b) => a.arrivesAt - b.arrivesAt)[0];
    if (!due) break;
    next = resolveFleet(next, due, at);
    guard += 1;
  }

  return resolveDuePirates(next, at);
}

function applyPirateWave(world: SimWorld, at: number): SimWorld {
  const planet = planetById(world, world.empire.homePlanetId);
  const counts = defenceCountsOf(planet);
  const ships = pirateWaveSize(defenceUnitCount(counts));
  const result = pirateCombat(counts, ships, planet.ore, planet.crystal);
  const looted = applyDefenceCounts(planet, result.counts);
  const nextPlanet: SimPlanet = {
    ...looted,
    ore: planet.ore - result.loot.ore,
    crystal: planet.crystal - result.loot.crystal,
  };
  const held = result.piratesLeft <= 0;
  const body = [
    `${ships} pirate hull${ships === 1 ? "" : "s"} ATK ${result.pirateAtk} DEF ${result.pirateDef}.`,
    `Planet ATK ${result.planetAtk} DEF ${result.planetDef}.`,
    `Destroyed ${result.piratesLost} pirate${result.piratesLost === 1 ? "" : "s"}.`,
    `Guns lost: ${formatLostGuns(result.lost)}.`,
    held
      ? "The hold held."
      : `Looted ${result.loot.ore.toLocaleString()} ore, ${result.loot.crystal.toLocaleString()} crystal.`,
  ].join(" ");
  const remainingUnits = defenceUnitCount(result.counts);
  return {
    ...replacePlanet(world, nextPlanet),
    empire: {
      ...world.empire,
      nextPirateAt: at + pirateIntervalSeconds(remainingUnits) * 1000,
    },
    reports: [
      {
        title: held ? "Pirate raid repelled" : "Pirate raid",
        body,
        lootOre: result.loot.ore,
        lootCrystal: result.loot.crystal,
        createdAt: at,
      },
      ...world.reports,
    ],
  };
}

function resolveDuePirates(world: SimWorld, at: number): SimWorld {
  let next = world;
  const home = planetById(next, next.empire.homePlanetId);
  if (next.empire.nextPirateAt == null) {
    const units = defenceUnitCount(defenceCountsOf(home));
    return {
      ...next,
      empire: {
        ...next.empire,
        nextPirateAt: at + pirateIntervalSeconds(units) * 1000,
      },
    };
  }

  let waves = 0;
  while (next.empire.nextPirateAt != null && next.empire.nextPirateAt <= at && waves < PIRATE_WAVE_CAP) {
    next = applyPirateWave(next, next.empire.nextPirateAt);
    waves += 1;
  }
  if (next.empire.nextPirateAt != null && next.empire.nextPirateAt <= at) {
    const units = defenceUnitCount(defenceCountsOf(planetById(next, next.empire.homePlanetId)));
    next = {
      ...next,
      empire: {
        ...next.empire,
        nextPirateAt: at + pirateIntervalSeconds(units) * 1000,
      },
    };
  }
  return next;
}

export function spawnPirates(world: SimWorld, at: number): SimWorld {
  const caught = catchUpWorld(world, at);
  return applyPirateWave(caught, at);
}

export function startUpgrade(world: SimWorld, building: BuildingId, at: number): SimWorld {
  if (!isBuildingId(building)) throw new Error("Unknown structure.");
  const caught = catchUpWorld(world, at);
  const planet = planetById(caught, caught.empire.homePlanetId);
  if (planet.upgradeBuilding) throw new Error("An upgrade is already running.");
  if (isFacilityId(building)) {
    const spec = facilitySpec(building);
    if (spec.moon) throw new Error("Moon facilities wait for a moon.");
    const missing = unmetFacility(
      building,
      (id) => facilityLevel(planet, id),
      (id) => researchLevel(caught.empire, id),
    );
    if (missing.length > 0) throw new Error(`Needs ${missing[0].name} ${missing[0].level}.`);
  }
  if (building === "fusion_reactor") {
    if (researchLevel(caught.empire, "energy_tech") < 3) throw new Error("Needs Energy technology 3.");
    if (planet.deuteriumExtractor < 5) throw new Error("Needs Deuterium extractor 5.");
  }
  if (planet.maxFields != null && totalFieldsUsed(planet) >= planet.maxFields) {
    throw new Error("No free fields.");
  }
  const level = planetLevel(planet, building);
  const cost = buildingCost(building, level);
  if (planet.ore < cost.ore || planet.crystal < cost.crystal) throw new Error("Not enough resources.");
  const upgraded: SimPlanet = {
    ...planet,
    ore: planet.ore - cost.ore,
    crystal: planet.crystal - cost.crystal,
    upgradeBuilding: building,
    upgradeCompletesAt: at + buildingTimeSeconds(level) * 1000,
  };
  return replacePlanet(caught, upgraded);
}

export function cancelUpgrade(world: SimWorld, at: number): SimWorld {
  const caught = catchUpWorld(world, at);
  const planet = planetById(caught, caught.empire.homePlanetId);
  if (!planet.upgradeBuilding) throw new Error("Nothing is being built.");
  const level = planetLevel(planet, planet.upgradeBuilding);
  const cost = buildingCost(planet.upgradeBuilding, level);
  const refund = cancelRefund(
    cost,
    progressToward(planet.upgradeCompletesAt, buildingTimeSeconds(level) * 1000, at),
  );
  return replacePlanet(caught, {
    ...planet,
    ore: Math.min(storageCap(planet.oreStorage), planet.ore + refund.ore),
    crystal: Math.min(storageCap(planet.crystalStorage), planet.crystal + refund.crystal),
    upgradeBuilding: null,
    upgradeCompletesAt: null,
  });
}

export function resetEmpire(world: SimWorld, at: number): SimWorld {
  const home = planetById(world, world.empire.homePlanetId);
  return {
    planets: world.planets.map((planet) =>
      planet.id === home.id
        ? {
            ...planet,
            ore: STARTING_ORE,
            crystal: STARTING_CRYSTAL,
            deuterium: 0,
            lastHarvestedAt: at,
            oreMine: 1,
            crystalMine: 1,
            deuteriumExtractor: 0,
            powerPlant: 1,
            fusionReactor: 0,
            oreStorage: 0,
            crystalStorage: 0,
            deuteriumStorage: 0,
            ...EMPTY_FACILITIES,
            upgradeBuilding: null,
            upgradeCompletesAt: null,
            ...EMPTY_DEFENCES,
          }
        : planet,
    ),
    empire: {
      ...world.empire,
      propulsionLevel: 0,
      ...EMPTY_RESEARCH,
      raiders: STARTING_RAIDERS,
      raidersQueued: 0,
      raiderCompletesAt: null,
      researchCompletesAt: null,
      nextPirateAt: null,
    },
    fleets: world.fleets.filter((fleet) => fleet.ownerId !== world.empire.userId),
    reports: [],
  };
}

export function startResearch(world: SimWorld, id: ResearchId, at: number): SimWorld {
  const caught = catchUpWorld(world, at);
  if (caught.empire.researchCompletesAt) throw new Error("Research already running.");
  const planet = planetById(caught, caught.empire.homePlanetId);
  const level = researchLevel(caught.empire, id);
  const missing = unmetResearch(id, (research) => researchLevel(caught.empire, research));
  if (missing.length > 0) throw new Error(`Needs ${missing[0].name} ${missing[0].level}.`);
  const cost = researchTechCost(id, level);
  if (planet.ore < cost.ore || planet.crystal < cost.crystal) throw new Error("Not enough resources.");
  return {
    ...replacePlanet(caught, {
      ...planet,
      ore: planet.ore - cost.ore,
      crystal: planet.crystal - cost.crystal,
    }),
    empire: {
      ...caught.empire,
      researchTech: id,
      researchCompletesAt: at + researchTimeSeconds(level) * 1000,
    },
  };
}

export function queueDefence(world: SimWorld, id: DefenceId, count: number, at: number): SimWorld {
  if (!isDefenceId(id)) throw new Error("Unknown defence.");
  if (count < 1) throw new Error("Build at least one.");
  const spec = defenceSpec(id);
  const caught = catchUpWorld(world, at);
  const planet = planetById(caught, caught.empire.homePlanetId);
  if (planet.defencesQueued > 0 && planet.defenceBuilding && planet.defenceBuilding !== id) {
    throw new Error("Defence yard occupied.");
  }
  const pendingSame = planet.defenceBuilding === id ? planet.defencesQueued : 0;
  if (spec.unique && defenceOwned(planet, id) + pendingSame + count > 1) {
    throw new Error("Only one of those domes fits on this world.");
  }
  const ore = spec.cost.ore * count;
  const crystal = spec.cost.crystal * count;
  if (planet.ore < ore || planet.crystal < crystal) throw new Error("Not enough resources.");
  const startsNow = planet.defencesQueued === 0;
  return replacePlanet(caught, {
    ...planet,
    ore: planet.ore - ore,
    crystal: planet.crystal - crystal,
    defenceBuilding: id,
    defencesQueued: planet.defencesQueued + count,
    defenceCompletesAt: startsNow ? at + spec.buildSeconds * 1000 : planet.defenceCompletesAt,
  });
}

export function queueRaiders(world: SimWorld, count: number, at: number): SimWorld {
  if (count < 1) throw new Error("Build at least one small cargo.");
  const caught = catchUpWorld(world, at);
  const hull = shipSpec("small_cargo");
  const blocked = hull?.research.find(
    (req) => !req.upgrade && researchLevel(caught.empire, req.id) < req.level,
  );
  if (blocked) throw new Error(`Needs ${researchSpec(blocked.id).name} ${blocked.level}.`);
  const planet = planetById(caught, caught.empire.homePlanetId);
  const ore = RAIDER_COST.ore * count;
  const crystal = RAIDER_COST.crystal * count;
  if (planet.ore < ore || planet.crystal < crystal) throw new Error("Not enough resources.");
  const startsNow = caught.empire.raidersQueued === 0;
  return {
    ...replacePlanet(caught, { ...planet, ore: planet.ore - ore, crystal: planet.crystal - crystal }),
    empire: {
      ...caught.empire,
      raidersQueued: caught.empire.raidersQueued + count,
      raiderCompletesAt: startsNow ? at + RAIDER_BUILD_SECONDS * 1000 : caught.empire.raiderCompletesAt,
    },
  };
}

export function sendRaid(world: SimWorld, destPlanetId: number, ships: number, at: number): SimWorld {
  if (ships < 1) throw new Error("Send at least one small cargo.");
  const caught = catchUpWorld(world, at);
  if (caught.empire.raiders < ships) throw new Error("Not enough small cargo.");
  const origin = planetById(caught, caught.empire.homePlanetId);
  const dest = planetById(caught, destPlanetId);
  if (dest.id === origin.id) throw new Error("Cannot raid your own planet.");
  if (dest.ownerId && dest.ownerId !== caught.empire.userId) {
    throw new Error("Commander worlds are protected in this version.");
  }
  if (dest.ownerId === caught.empire.userId) throw new Error("Cannot raid your own planet.");
  const duration = flightSeconds(
    origin.system,
    origin.slot,
    dest.system,
    dest.slot,
    caught.empire.propulsionLevel,
    origin.galaxy ?? 0,
    dest.galaxy ?? 0,
  );
  const fleet: SimFleet = {
    id: Math.max(0, ...caught.fleets.map((f) => f.id)) + 1,
    ownerId: caught.empire.userId,
    originPlanetId: origin.id,
    destPlanetId: dest.id,
    raiders: ships,
    mission: "attack",
    arrivesAt: at + duration * 1000,
    cargoOre: 0,
    cargoCrystal: 0,
    status: "en_route",
    report: null,
  };
  return {
    ...caught,
    empire: { ...caught.empire, raiders: caught.empire.raiders - ships },
    fleets: [...caught.fleets, fleet],
  };
}

export function livePlanet(planet: SimPlanet, at: number) {
  const preview = catchUpPlanet(planet, at);
  const energy = energyNow(
    preview.oreMine,
    preview.crystalMine,
    preview.powerPlant,
    preview.starType,
    preview.deuteriumExtractor,
    preview.fusionReactor,
  );
  const factor = energy.factor;
  return {
    ...preview,
    energy,
    orePerHour: mineProductionPerHour(preview.oreMine) * factor,
    crystalPerHour: crystalProductionPerHour(preview.crystalMine) * factor,
    oreCap: storageCap(preview.oreStorage),
    crystalCap: storageCap(preview.crystalStorage),
    deuteriumCap: storageCap(preview.deuteriumStorage),
  };
}

export function fillResources(world: SimWorld, at: number): SimWorld {
  const caught = catchUpWorld(world, at);
  const planet = planetById(caught, caught.empire.homePlanetId);
  return replacePlanet(caught, {
    ...planet,
    ore: storageCap(planet.oreStorage),
    crystal: storageCap(planet.crystalStorage),
    deuterium: storageCap(planet.deuteriumStorage),
    lastHarvestedAt: at,
  });
}

export { BUILDINGS };
