import {
  BUILDINGS,
  type BuildingId,
  RAIDER_CARGO,
  RAIDER_COST,
  RAIDER_BUILD_SECONDS,
  buildingCost,
  buildingTimeSeconds,
  crystalProductionPerHour,
  energyFactor,
  energyNow,
  flightSeconds,
  harvestAmount,
  mineProductionPerHour,
  raidLoot,
  researchCost,
  researchTimeSeconds,
  storageCap,
} from "./catalog";

export type { BuildingId };

export type SimPlanet = {
  id: number;
  ownerId: string | null;
  system: number;
  slot: number;
  name: string;
  ore: number;
  crystal: number;
  lastHarvestedAt: number;
  oreMine: number;
  crystalMine: number;
  powerPlant: number;
  upgradeBuilding: BuildingId | null;
  upgradeCompletesAt: number | null;
};

export type SimEmpire = {
  userId: string;
  homePlanetId: number;
  propulsionLevel: number;
  raiders: number;
  raidersQueued: number;
  raiderCompletesAt: number | null;
  researchCompletesAt: number | null;
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
  return planet.powerPlant;
}

export function tickPlanet(planet: SimPlanet, at: number): SimPlanet {
  const elapsed = Math.max(0, (at - planet.lastHarvestedAt) / 1000);
  const factor = energyFactor(planet.oreMine, planet.crystalMine, planet.powerPlant);
  return {
    ...planet,
    ore: harvestAmount(
      planet.ore,
      mineProductionPerHour(planet.oreMine) * factor,
      elapsed,
      storageCap(planet.oreMine),
    ),
    crystal: harvestAmount(
      planet.crystal,
      crystalProductionPerHour(planet.crystalMine) * factor,
      elapsed,
      storageCap(planet.crystalMine),
    ),
    lastHarvestedAt: at,
  };
}

function completeUpgrade(planet: SimPlanet): SimPlanet {
  if (!planet.upgradeBuilding) return { ...planet, upgradeBuilding: null, upgradeCompletesAt: null };
  const next = { ...planet, upgradeBuilding: null, upgradeCompletesAt: null };
  if (planet.upgradeBuilding === "ore_mine") next.oreMine += 1;
  if (planet.upgradeBuilding === "crystal_mine") next.crystalMine += 1;
  if (planet.upgradeBuilding === "power_plant") next.powerPlant += 1;
  return next;
}

export function catchUpPlanet(planet: SimPlanet, at: number): SimPlanet {
  if (planet.upgradeCompletesAt != null && planet.upgradeCompletesAt <= at) {
    const due = planet.upgradeCompletesAt;
    return tickPlanet(completeUpgrade(tickPlanet(planet, due)), at);
  }
  return tickPlanet(planet, at);
}

export function catchUpEmpire(empire: SimEmpire, at: number): SimEmpire {
  const next = { ...empire };
  if (next.researchCompletesAt != null && next.researchCompletesAt <= at) {
    next.propulsionLevel += 1;
    next.researchCompletesAt = null;
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
    let cargoLeft = fleet.raiders * RAIDER_CARGO;
    const lootOre = raidLoot(tickedDest.ore, cargoLeft);
    cargoLeft -= lootOre;
    const lootCrystal = raidLoot(tickedDest.crystal, cargoLeft);
    const looted: SimPlanet = {
      ...tickedDest,
      ore: tickedDest.ore - lootOre,
      crystal: tickedDest.crystal - lootCrystal,
    };
    const duration = flightSeconds(origin.system, origin.slot, dest.system, dest.slot, world.empire.propulsionLevel);
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
    ore: Math.min(storageCap(home.oreMine), home.ore + fleet.cargoOre),
    crystal: Math.min(storageCap(home.crystalMine), home.crystal + fleet.cargoCrystal),
  };
  const completed: SimFleet = { ...fleet, status: "completed" };
  return {
    ...replacePlanet(world, cappedHome),
    empire: { ...world.empire, raiders: world.empire.raiders + fleet.raiders },
    fleets: world.fleets.map((f) => (f.id === fleet.id ? completed : f)),
    reports: [
      {
        title: `Fleet returned from ${dest.name}`,
        body: fleet.report ?? "The raiders dumped their holds.",
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
  return next;
}

export function startUpgrade(world: SimWorld, building: BuildingId, at: number): SimWorld {
  const caught = catchUpWorld(world, at);
  const planet = planetById(caught, caught.empire.homePlanetId);
  if (planet.upgradeBuilding) throw new Error("An upgrade is already running.");
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

export function startResearch(world: SimWorld, at: number): SimWorld {
  const caught = catchUpWorld(world, at);
  if (caught.empire.researchCompletesAt) throw new Error("Research already running.");
  const planet = planetById(caught, caught.empire.homePlanetId);
  const cost = researchCost(caught.empire.propulsionLevel);
  if (planet.ore < cost.ore || planet.crystal < cost.crystal) throw new Error("Not enough resources.");
  return {
    ...replacePlanet(caught, {
      ...planet,
      ore: planet.ore - cost.ore,
      crystal: planet.crystal - cost.crystal,
    }),
    empire: {
      ...caught.empire,
      researchCompletesAt: at + researchTimeSeconds(caught.empire.propulsionLevel) * 1000,
    },
  };
}

export function queueRaiders(world: SimWorld, count: number, at: number): SimWorld {
  if (count < 1) throw new Error("Build at least one raider.");
  const caught = catchUpWorld(world, at);
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
  if (ships < 1) throw new Error("Send at least one raider.");
  const caught = catchUpWorld(world, at);
  if (caught.empire.raiders < ships) throw new Error("Not enough raiders.");
  const origin = planetById(caught, caught.empire.homePlanetId);
  const dest = planetById(caught, destPlanetId);
  if (dest.id === origin.id) throw new Error("Cannot raid your own planet.");
  if (dest.ownerId && dest.ownerId !== caught.empire.userId) {
    throw new Error("Commander worlds are protected in this version.");
  }
  if (dest.ownerId === caught.empire.userId) throw new Error("Cannot raid your own planet.");
  const duration = flightSeconds(origin.system, origin.slot, dest.system, dest.slot, caught.empire.propulsionLevel);
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
  const energy = energyNow(preview.oreMine, preview.crystalMine, preview.powerPlant);
  const factor = energy.factor;
  return {
    ...preview,
    energy,
    orePerHour: mineProductionPerHour(preview.oreMine) * factor,
    crystalPerHour: crystalProductionPerHour(preview.crystalMine) * factor,
    oreCap: storageCap(preview.oreMine),
    crystalCap: storageCap(preview.crystalMine),
  };
}

export { BUILDINGS };
