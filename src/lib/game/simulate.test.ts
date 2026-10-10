import { describe, expect, it } from "vitest";
import { RAIDER_COST, STARTING_CRYSTAL, STARTING_ORE, buildingCost, buildingTimeSeconds, defenceCost, GAME_HOUR_SECONDS, ipmFlightSeconds, mineProductionPerHour, MINING_BARGE_RATE_PER_HOUR, planetFieldCap, researchDurationSeconds, storageCap } from "./catalog";
import {
  EMPTY_DEFENCES,
  EMPTY_FACILITIES,
  EMPTY_RESEARCH,
  catchUpWorld,
  cancelUpgrade,
  cancelDefence,
  queueDefence,
  queueRaiders,
  queueShip,
  resetEmpire,
  sendAttack,
  sendIpm,
  sendRaid,
  sendSpy,
  sendHarvest,
  sendMine,
  sendColonize,
  sendExpedition,
  sendDeploy,
  spawnPirates,
  recallFleet,
  startResearch,
  startUpgrade,
  fillResources,
  grantDebugFleet,
  livePlanet,
  planetFieldCapOf,
  researchLevel,
  selectPlanet,
  tickPlanet,
  totalFieldsUsed,
  planetUnitSeconds,
  type SimPlanet,
  type SimWorld,
} from "./simulate";

function world(at = 0): SimWorld {
  const planet: SimPlanet = {
    id: 1,
    ownerId: "u1",
    system: 1,
    slot: 1,
    name: "Homeworld",
    ore: STARTING_ORE,
    crystal: STARTING_CRYSTAL,
    deuterium: 50000,
    lastHarvestedAt: at,
    tempMax: 30,
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
  };
  const npc: SimPlanet = {
    id: 2,
    ownerId: null,
    system: 1,
    slot: 3,
    name: "Derelict Hulk",
    ore: 4000,
    crystal: 2000,
    deuterium: 0,
    lastHarvestedAt: at,
    tempMax: 30,
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
  };
  return {
    planets: [planet, npc],
    empire: {
      userId: "u1",
      homePlanetId: 1,
      propulsionLevel: 0,
      ...EMPTY_RESEARCH,
      raiders: 0,
      raidersQueued: 0,
      raiderCompletesAt: null,
      ships: {},
      shipBuilding: null,
      researchCompletesAt: null,
      nextPirateAt: null,
      pirateRaidsEnabled: true,
    },
    fleets: [],
    reports: [],
  };
}

describe("time-skip simulation", () => {
  it("raises ore storage after the timer", () => {
    const started = startUpgrade(world(0), "ore_storage", 0);
    expect(started.planets[0].ore).toBe(STARTING_ORE - buildingCost("ore_storage", 0).ore);
    const finished = catchUpWorld(started, started.planets[0].upgradeCompletesAt!);
    expect(finished.planets[0].oreStorage).toBe(1);
    expect(finished.planets[0].upgradeBuilding).toBeNull();
  });

  it("finishes a mine upgrade after the timer", () => {
    const started = startUpgrade(world(0), "ore_mine", 0);
    const home = started.planets[0];
    expect(home.upgradeBuilding).toBe("ore_mine");
    expect(home.ore).toBeLessThan(STARTING_ORE);
    const doneAt = home.upgradeCompletesAt!;
    const finished = catchUpWorld(started, doneAt);
    expect(finished.planets[0].oreMine).toBe(2);
    expect(finished.planets[0].upgradeBuilding).toBeNull();
  });

  it("builds a robotics factory and keeps the shipyard gated", () => {
    expect(() => startUpgrade(world(0), "shipyard", 0)).toThrow(/Robotics factory 2/);
    expect(() => startUpgrade(world(0), "lunar_base", 0)).toThrow(/not available/i);
    expect(() => startUpgrade(world(0), "alliance_depot", 0)).toThrow(/not available/i);
    expect(() => startUpgrade(world(0), "space_station", 0)).toThrow(/not available/i);
    const started = startUpgrade(world(0), "robotics_factory", 0);
    expect(started.planets[0].ore).toBe(STARTING_ORE - 400);
    const doneAt = started.planets[0].upgradeCompletesAt!;
    const done = catchUpWorld(started, doneAt);
    expect(done.planets[0].roboticsFactory).toBe(1);
    const next = startUpgrade(done, "ore_mine", doneAt);
    expect(next.planets[0].upgradeCompletesAt! - doneAt).toBe(buildingTimeSeconds("ore_mine", 1, 1, 0) * 1000);
  });

  it("builds raiders and returns loot from an NPC raid", () => {
    const base = world(0);
    const ready: SimWorld = {
      ...base,
      planets: base.planets.map((planet) =>
        planet.id === 1 ? { ...planet, ore: 8000, crystal: 8000, shipyard: 2 } : planet,
      ),
      empire: { ...base.empire, propulsionLevel: 2, impulseDrive: 5 },
    };
    const queued = queueRaiders(ready, 1, 0);
    expect(queued.planets[0].ore).toBe(8000 - RAIDER_COST.ore);
    expect(() => queueRaiders(world(0), 1, 0)).toThrow(/Shipyard 2/);
    expect(() =>
      queueRaiders(
        {
          ...base,
          planets: base.planets.map((planet) => (planet.id === 1 ? { ...planet, ore: 8000, crystal: 8000, shipyard: 2 } : planet)),
        },
        1,
        0,
      ),
    ).toThrow(/Combustion drive 2/);
    expect(() =>
      queueRaiders(
        {
          ...ready,
          empire: { ...ready.empire, impulseDrive: 0 },
        },
        1,
        0,
      ),
    ).toThrow(/Impulse drive 5/);
    const built = catchUpWorld(queued, queued.empire.raiderCompletesAt!);
    expect(built.empire.raiders).toBe(1);
    const parked: SimWorld = {
      ...built,
      planets: built.planets.map((planet) =>
        planet.id === 2 ? { ...planet, oreMine: 0, crystalMine: 0, lastHarvestedAt: built.empire.raiderCompletesAt! } : planet,
      ),
      empire: { ...built.empire, pirateRaidsEnabled: false, nextPirateAt: null },
    };
    const sent = sendRaid(parked, 2, 1, parked.empire.raiderCompletesAt!);
    expect(sent.empire.raiders).toBe(0);
    const attackAt = sent.fleets[0].arrivesAt;
    const afterAttack = catchUpWorld(sent, attackAt);
    const returning = afterAttack.fleets.find((f) => f.id === sent.fleets[0].id)!;
    expect(returning.mission).toBe("return");
    expect(returning.cargoOre).toBe(2000);
    expect(returning.cargoCrystal).toBe(1000);
    const home = catchUpWorld(afterAttack, returning.arrivesAt);
    expect(home.empire.raiders).toBe(1);
    expect(home.planets[0].ore).toBeGreaterThan(built.planets[0].ore);
    expect(home.reports.length).toBe(1);
  });

  it("builds a light fighter when Shipyard 1 and Combustion 1 are ready", () => {
    const base = world(0);
    const ready: SimWorld = {
      ...base,
      planets: base.planets.map((planet) =>
        planet.id === 1 ? { ...planet, ore: 8000, crystal: 8000, shipyard: 1 } : planet,
      ),
      empire: { ...base.empire, propulsionLevel: 1 },
    };
    expect(() => queueShip(world(0), "light_fighter", 1, 0)).toThrow(/Shipyard 1/);
    const queued = queueShip(ready, "light_fighter", 1, 0);
    expect(queued.planets[0].ore).toBe(8000 - 3000);
    expect(queued.empire.shipBuilding).toBe("light_fighter");
    expect(() => queueShip(queued, "solar_satellite", 1, 0)).toThrow(/occupied/i);
    const built = catchUpWorld(queued, queued.empire.raiderCompletesAt!);
    expect(built.empire.ships.light_fighter).toBe(1);
    expect(built.empire.raiders).toBe(0);
  });

  it("sends an expedition to outer space and lists it in flight", () => {
    const base = world(0);
    expect(() => sendExpedition(base, 1, 1, 1, 0)).toThrow(/Astronomy 1/);
    const ready: SimWorld = {
      ...base,
      empire: { ...base.empire, astrophysics: 1, raiders: 3 },
    };
    const sent = sendExpedition(ready, 1, 1, 2, 0);
    expect(sent.empire.raiders).toBe(1);
    expect(sent.fleets[0].mission).toBe("expedition");
    expect(sent.fleets[0].destSlot).toBe(16);
    expect(() => sendExpedition(sent, 1, 1, 1, 0)).toThrow(/expedition slots/);
    const holding = catchUpWorld(sent, sent.fleets[0].arrivesAt!);
    expect(holding.fleets[0].mission).toBe("expedition_hold");
  });

  it("refunds half the cost when an upgrade is cancelled at 50%", () => {
    const started = startUpgrade(world(0), "ore_mine", 0);
    const mid = started.planets[0].upgradeCompletesAt! / 2;
    const ticked = catchUpWorld(started, mid);
    const cancelled = cancelUpgrade(started, mid);
    const refundOre = Math.floor(buildingCost("ore_mine", 1).ore * 0.5 * 0.75);
    const refundCrystal = Math.floor(buildingCost("ore_mine", 1).crystal * 0.5 * 0.75);
    expect(cancelled.planets[0].upgradeBuilding).toBeNull();
    expect(cancelled.planets[0].oreMine).toBe(1);
    expect(cancelled.planets[0].ore).toBe(ticked.planets[0].ore + refundOre);
    expect(cancelled.planets[0].crystal).toBe(ticked.planets[0].crystal + refundCrystal);
  });

  it("resets the homeworld without touching NPC worlds", () => {
    const upgraded = catchUpWorld(startUpgrade(world(0), "ore_mine", 0), 60_000);
    const wiped = resetEmpire(upgraded, 90_000);
    expect(wiped.planets[0].oreMine).toBe(1);
    expect(wiped.planets[0].powerPlant).toBe(1);
    expect(wiped.planets[0].oreStorage).toBe(0);
    expect(wiped.planets[0].ore).toBe(STARTING_ORE);
    expect(wiped.planets[1].ore).toBe(4000);
    expect(wiped.empire.propulsionLevel).toBe(0);
    expect(wiped.fleets).toEqual([]);
  });

  it("completes propulsion research on a time skip", () => {
    const base = world(0);
    const withLab: SimWorld = {
      ...base,
      planets: base.planets.map((planet) => (planet.id === 1 ? { ...planet, researchLab: 1 } : planet)),
    };
    const ready: SimWorld = { ...withLab, empire: { ...withLab.empire, energyTech: 1 } };
    expect(() => startResearch(base, "energy_tech", 0)).toThrow(/Research lab 1/);
    expect(() => startResearch(withLab, "weapons_tech", 0)).toThrow(/Research lab 4/);
    expect(() => startResearch(withLab, "combustion_drive", 0)).toThrow(/Energy technology 1/);
    const started = startResearch(ready, "combustion_drive", 0);
    const done = catchUpWorld(started, started.empire.researchCompletesAt!);
    expect(done.empire.propulsionLevel).toBe(1);
    expect(done.empire.researchCompletesAt).toBeNull();

    const mining = startUpgrade(ready, "ore_mine", 0);
    const both = startResearch(mining, "combustion_drive", 0);
    expect(both.planets[0].upgradeBuilding).toBe("ore_mine");
    expect(both.empire.researchTech).toBe("combustion_drive");
    const researching = startResearch(ready, "combustion_drive", 0);
    expect(() => startUpgrade(researching, "research_lab", 0)).toThrow(/Research lab is in use/);
    const labReady: SimWorld = {
      ...ready,
      planets: ready.planets.map((planet) =>
        planet.id === 1 ? { ...planet, ore: 8000, crystal: 8000, deuterium: 8000, crystalStorage: 3, deuteriumStorage: 3 } : planet,
      ),
    };
    const labWork = startUpgrade(labReady, "research_lab", 0);
    expect(() => startResearch(labWork, "combustion_drive", 0)).toThrow(/being upgraded/);
  });

  it("joins extra labs through IRN for research time", () => {
    const base = world(0);
    const colony: SimPlanet = {
      ...base.planets[0],
      id: 3,
      slot: 8,
      name: "Colony",
      researchLab: 8,
      ore: 50000,
      crystal: 50000,
      deuterium: 50000,
    };
    const networked: SimWorld = {
      ...base,
      planets: [
        { ...base.planets[0], researchLab: 10, ore: 50000, crystal: 50000, deuterium: 50000 },
        base.planets[1],
        colony,
      ],
      empire: { ...base.empire, energyTech: 3, intergalacticResearchNetwork: 2 },
    };
    const solo: SimWorld = {
      ...networked,
      planets: networked.planets.filter((planet) => planet.id !== 3),
      empire: { ...networked.empire, intergalacticResearchNetwork: 0 },
    };
    const withIrn = startResearch(networked, "shielding_tech", 0);
    const without = startResearch(solo, "shielding_tech", 0);
    expect(withIrn.empire.researchCompletesAt).toBe(researchDurationSeconds(0, 18, 10) * 1000);
    expect(without.empire.researchCompletesAt).toBe(researchDurationSeconds(0, 10, 10) * 1000);
    expect(withIrn.empire.researchCompletesAt).toBeLessThan(without.empire.researchCompletesAt!);

    const fromColony = startResearch({ ...networked, empire: { ...networked.empire, homePlanetId: 3 } }, "shielding_tech", 0);
    expect(fromColony.empire.researchCompletesAt).toBe(researchDurationSeconds(0, 18, 8) * 1000);
  });

  it("builds a rocket launcher and will not raise a second small dome", () => {
    const richer: SimWorld = {
      ...world(0),
      planets: world(0).planets.map((p) =>
        p.id === 1
          ? { ...p, ore: 40000, crystal: 40000, deuterium: 40000, oreStorage: 4, crystalStorage: 4, deuteriumStorage: 4, shipyard: 1 }
          : p,
      ),
    };
    expect(() => queueDefence(world(0), "rocket_launcher", 1, 0)).toThrow(/Shipyard 1/);
    const started = queueDefence(richer, "rocket_launcher", 2, 0);
    expect(started.planets[0].ore).toBe(40000 - defenceCost("rocket_launcher").ore * 2);
    const done = catchUpWorld(
      started,
      started.planets[0].defenceCompletesAt! + planetUnitSeconds(started.planets[0], "rocket_launcher") * 1000,
    );
    expect(done.planets[0].rocketLauncher).toBe(2);
    expect(done.planets[0].defencesQueued).toBe(0);
    expect(() => queueDefence(done, "small_shield_dome", 1, done.planets[0].lastHarvestedAt)).toThrow(
      /Shielding technology 2/,
    );
    const readyDome: SimWorld = { ...done, empire: { ...done.empire, shieldingTech: 2 } };
    const dome = queueDefence(readyDome, "small_shield_dome", 1, done.planets[0].lastHarvestedAt);
    const raised = catchUpWorld(dome, dome.planets[0].defenceCompletesAt!);
    expect(raised.planets[0].smallShieldDome).toBe(1);
    expect(() => queueDefence(raised, "small_shield_dome", 1, raised.planets[0].lastHarvestedAt)).toThrow(
      /one of those domes/i,
    );
    expect(() => queueDefence(richer, "rocket_launcher", 1000, 0)).toThrow(/at most 999/);
    const stacked = queueDefence(richer, "rocket_launcher", 2, 0);
    const cancelled = cancelDefence(stacked, 0);
    expect(cancelled.planets[0].defencesQueued).toBe(0);
    expect(cancelled.planets[0].defenceBuilding).toBeNull();
    expect(cancelled.planets[0].ore).toBe(40000);
    expect(cancelled.planets[0].crystal).toBe(40000);
  });

  it("resolves a due pirate wave and writes a report", () => {
    const base = world(0);
    const armed: SimWorld = {
      ...base,
      planets: base.planets.map((p) =>
        p.id === 1 ? { ...p, rocketLauncher: 2, ore: 2000, crystal: 800 } : p,
      ),
      empire: { ...base.empire, nextPirateAt: 0 },
    };
    const after = catchUpWorld(armed, 0);
    expect(after.reports.length).toBe(1);
    expect(after.reports[0].title).toMatch(/Pirate raid/);
    expect(after.empire.nextPirateAt).toBeGreaterThan(0);
    expect(after.planets[0].ore).toBeLessThanOrEqual(2000);
    expect((after.planets[0].debrisOre ?? 0) + (after.planets[0].debrisCrystal ?? 0)).toBeGreaterThan(0);
    expect(after.reports[0].body).toMatch(/Debris/);
  });

  it("adds wiki solar satellite energy to the grid", () => {
    const base = world(0).planets[0];
    const strained = {
      ...base,
      oreMine: 3,
      crystalMine: 1,
      powerPlant: 1,
      tempMin: 20,
      tempMax: 20,
      solarSatellites: 0,
    };
    expect(livePlanet(strained, 0).energy.output).toBe(22);
    const powered = livePlanet({ ...strained, solarSatellites: 1 }, 0);
    expect(powered.energy.output).toBe(52);
    expect(powered.energy.factor).toBe(1);
  });

  it("applies working crawler mine bonus when energy leftover covers them", () => {
    const base = world(0).planets[0];
    const powered = {
      ...base,
      ore: 0,
      oreMine: 1,
      crystalMine: 1,
      deuteriumExtractor: 0,
      powerPlant: 20,
      crawlers: 10,
      lastHarvestedAt: 0,
    };
    const live = livePlanet(powered, 0);
    expect(live.orePerHour).toBe(mineProductionPerHour(1) * 1.002);
    const after = tickPlanet(powered, GAME_HOUR_SECONDS * 100 * 1000);
    expect(after.ore).toBe(Math.floor(mineProductionPerHour(1) * 1.002 * 100));
  });

  it("skips automatic pirate waves when raids are off", () => {
    const base = world(0);
    const armed: SimWorld = {
      ...base,
      planets: base.planets.map((p) =>
        p.id === 1 ? { ...p, rocketLauncher: 2, ore: 2000, crystal: 800 } : p,
      ),
      empire: { ...base.empire, nextPirateAt: 0, pirateRaidsEnabled: false },
    };
    const after = catchUpWorld(armed, 0);
    expect(after.reports.length).toBe(0);
    expect(after.empire.nextPirateAt).toBeNull();
    expect(after.planets[0].ore).toBe(2000);
  });

  it("debug spawn queues pirates for a 10 minute inbound strike", () => {
    const after = spawnPirates(world(0), 1000);
    expect(after.reports.length).toBe(0);
    expect(after.fleets[0].ownerId).toBeNull();
    expect(after.fleets[0].arrivesAt).toBe(1000 + 600_000);
    const impact = catchUpWorld(after, after.fleets[0].arrivesAt);
    expect(impact.reports[0].body).toMatch(/ATK/);
    expect(impact.planets[0].debrisCrystal).toBeGreaterThan(0);
  });

  it("attacks another commander and a defended world", () => {
    const base = world(0);
    const player: SimPlanet = {
      ...base.planets[1],
      id: 3,
      ownerId: "u2",
      slot: 4,
      name: "Rival Hold",
      ore: 8000,
      crystal: 4000,
      deuterium: 2000,
      oreMine: 0,
      crystalMine: 0,
      deuteriumExtractor: 0,
    };
    const defended: SimPlanet = {
      ...player,
      id: 4,
      slot: 5,
      name: "Fortress",
      plasmaTurret: 1,
    };
    const ready: SimWorld = {
      ...base,
      planets: [...base.planets, player, defended],
      empire: { ...base.empire, raiders: 2, ships: { small_cargo: 2 }, pirateRaidsEnabled: false, nextPirateAt: null },
    };
    const sent = sendAttack(ready, 3, { small_cargo: 1 }, 0, 100);
    expect(sent.empire.raiders).toBe(1);
    const hit = catchUpWorld(sent, sent.fleets[0].arrivesAt);
    const returning = hit.fleets[0];
    expect(returning.mission).toBe("return");
    expect(returning.cargoOre).toBe(2000);
    expect(returning.cargoCrystal).toBe(2000);
    expect(returning.cargoDeuterium).toBe(1000);
    expect(() => sendAttack(ready, 1, { small_cargo: 1 }, 0)).toThrow(/own planet/);
    const assault = sendAttack(ready, 4, { small_cargo: 1 }, 0, 100);
    const after = catchUpWorld(assault, assault.fleets[0].arrivesAt);
    expect(after.fleets[0].status).toBe("completed");
    expect(after.fleets[0].raiders).toBe(0);
    expect(after.reports[0].body).toMatch(/Defender holds/);
    expect(after.planets.find((planet) => planet.id === 4)?.ore).toBe(8000);
    let wave: SimWorld = { ...ready, empire: { ...ready.empire, raiders: 8 } };
    for (let i = 0; i < 6; i += 1) wave = sendAttack(wave, 3, { small_cargo: 1 }, 0, 100);
    expect(() => sendAttack(wave, 3, { small_cargo: 1 }, 0, 100)).toThrow(/Bash protection/);
  });

  it("fires interplanetary missiles and lets ABMs intercept them", () => {
    const base = world(0);
    const target: SimPlanet = {
      ...base.planets[1],
      id: 5,
      ownerId: "u2",
      slot: 8,
      name: "Guns",
      rocketLauncher: 12,
      antiballisticMissile: 2,
    };
    const ready: SimWorld = {
      ...base,
      planets: [
        { ...base.planets[0], interplanetaryMissile: 5, impulseDrive: 5 },
        base.planets[1],
        target,
      ],
      empire: { ...base.empire, impulseDrive: 5, weaponsTech: 0, pirateRaidsEnabled: false },
    };
    expect(() => sendIpm(ready, 1, 1, 0)).toThrow(/own planet/);
    const launched = sendIpm(ready, 5, 3, 0);
    expect(launched.planets[0].interplanetaryMissile).toBe(2);
    expect(launched.fleets[0].mission).toBe("missile");
    expect(launched.fleets[0].arrivesAt).toBe(ipmFlightSeconds(1, 1, 1) * 1000);
    const hit = catchUpWorld(launched, launched.fleets[0].arrivesAt);
    const guns = hit.planets.find((planet) => planet.id === 5)!;
    expect(guns.antiballisticMissile).toBe(0);
    expect(guns.rocketLauncher).toBe(6);
    expect(hit.fleets[0].status).toBe("completed");
    expect(hit.reports[0].body).toMatch(/anti-ballistic/i);
  });

  it("recalls an outbound raid before it hits", () => {
    const base = world(0);
    const ready: SimWorld = {
      ...base,
      planets: base.planets.map((planet) =>
        planet.id === 1 ? { ...planet, ore: 8000, crystal: 8000, shipyard: 2 } : planet,
      ),
      empire: { ...base.empire, propulsionLevel: 2, raiders: 2 },
    };
    const sent = sendRaid(ready, 2, 1, 0);
    const mid = sent.fleets[0].launchedAt! + (sent.fleets[0].arrivesAt - sent.fleets[0].launchedAt!) / 2;
    const recalled = recallFleet(sent, sent.fleets[0].id, mid);
    expect(recalled.fleets[0].mission).toBe("return");
    expect(recalled.fleets[0].destPlanetId).toBe(1);
  });

  it("fills ore, crystal, and deuterium to the storage caps", () => {
    const base = world(0);
    const tanks: SimWorld = {
      ...base,
      planets: base.planets.map((planet) =>
        planet.id === 1 ? { ...planet, oreStorage: 1, crystalStorage: 1, deuteriumStorage: 1 } : planet,
      ),
    };
    const filled = fillResources(tanks, 0);
    expect(filled.planets[0].ore).toBe(storageCap(1));
    expect(filled.planets[0].crystal).toBe(storageCap(1));
    expect(filled.planets[0].deuterium).toBe(storageCap(1));
  });

  it("grants flyable hulls and the research floors to spy, harvest, and colonize", () => {
    const granted = grantDebugFleet(world(0), 0);
    expect(granted.empire.ships.espionage_probe).toBe(50);
    expect(granted.empire.ships.recycler).toBe(20);
    expect(granted.empire.ships.mining_barge).toBe(20);
    expect(granted.empire.ships.colony_ship).toBe(10);
    expect(granted.empire.ships.light_fighter).toBe(20);
    expect(granted.empire.raiders).toBe(20);
    expect(granted.empire.espionageTech).toBeGreaterThanOrEqual(2);
    expect(granted.empire.astrophysics).toBeGreaterThanOrEqual(1);
    expect(granted.empire.impulseDrive).toBeGreaterThanOrEqual(5);
  });

  it("produces deuterium into the tank and spends it on research and fuel", () => {
    const base = world(0);
    const synth: SimWorld = {
      ...base,
      planets: base.planets.map((planet) =>
        planet.id === 1 ? { ...planet, deuterium: 0, deuteriumExtractor: 1, deuteriumStorage: 0 } : planet,
      ),
    };
    const grown = catchUpWorld(synth, GAME_HOUR_SECONDS * 1000);
    expect(grown.planets[0].deuterium).toBeGreaterThan(0);
    expect(grown.planets[0].deuterium).toBeLessThanOrEqual(storageCap(0));
    const dry: SimWorld = {
      ...base,
      planets: base.planets.map((planet) =>
        planet.id === 1 ? { ...planet, deuterium: 0, researchLab: 1 } : planet,
      ),
    };
    expect(() => startResearch({ ...dry, empire: { ...dry.empire, energyTech: 0 } }, "energy_tech", 0)).toThrow(
      /Not enough resources/,
    );
    const ready: SimWorld = {
      ...base,
      planets: base.planets.map((planet) =>
        planet.id === 1
          ? { ...planet, ore: 8000, crystal: 8000, deuterium: 0, shipyard: 2 }
          : planet,
      ),
      empire: { ...base.empire, propulsionLevel: 2, raiders: 1 },
    };
    expect(() => sendRaid(ready, 2, 1, 0)).toThrow(/Not enough resources/);
  });

  it("charges wiki terraformer costs and adds floor(5.5 × level) fields", () => {
    const base = world(0);
    const late: SimWorld = {
      ...base,
      planets: base.planets.map((planet) =>
        planet.id === 1
          ? {
              ...planet,
              ore: 0,
              crystal: 200000,
              deuterium: 400000,
              powerPlant: 20,
              crystalStorage: 8,
              deuteriumStorage: 8,
              naniteFactory: 1,
              researchLab: 1,
              maxFields: 173,
            }
          : planet,
      ),
      empire: { ...base.empire, energyTech: 12 },
    };
    expect(() => startUpgrade({ ...late, empire: { ...late.empire, energyTech: 11 } }, "terraformer", 0)).toThrow(
      /Energy technology 12/,
    );
    const dim: SimWorld = {
      ...late,
      planets: late.planets.map((planet) => (planet.id === 1 ? { ...planet, powerPlant: 1 } : planet)),
    };
    expect(() => startUpgrade(dim, "terraformer", 0)).toThrow(/Need more energy/);
    const packed: SimWorld = {
      ...late,
      planets: late.planets.map((planet) =>
        planet.id === 1 ? { ...planet, oreMine: 134, crystalMine: 1, powerPlant: 20 } : planet,
      ),
    };
    expect(totalFieldsUsed(packed.planets[0])).toBe(173);
    expect(() => startUpgrade(packed, "terraformer", 0)).toThrow(/No free fields/);
    const started = startUpgrade(late, "terraformer", 0);
    expect(started.planets[0].crystal).toBe(150000);
    expect(started.planets[0].deuterium).toBe(300000);
    const done = catchUpWorld(started, started.planets[0].upgradeCompletesAt!);
    expect(done.planets[0].terraformer).toBe(1);
    expect(done.planets[0].maxFields).toBe(173);
    expect(planetFieldCapOf(done.planets[0])).toBe(planetFieldCap(173, 1));
    expect(planetFieldCapOf(done.planets[0])).toBe(178);
  });

  it("sends probes, lists them as espionage, and files a report", () => {
    const base = world(0);
    const ready: SimWorld = {
      ...base,
      empire: {
        ...base.empire,
        espionageTech: 2,
        ships: { espionage_probe: 2 },
      },
    };
    const sent = sendSpy(ready, 2, 1, 0);
    expect(sent.empire.ships.espionage_probe).toBe(1);
    expect(sent.fleets[0].mission).toBe("espionage");
    const arrived = catchUpWorld(sent, sent.fleets[0].arrivesAt);
    const spy = arrived.fleets.find((f) => f.id === sent.fleets[0].id)!;
    expect(spy.mission === "espionage_return" || spy.status === "completed").toBe(true);
    expect(arrived.reports.some((r) => r.title === "Espionage report")).toBe(true);
    expect(arrived.reports.find((r) => r.title === "Espionage report")?.body).toMatch(/Resources/);
  });

  it("sends recyclers to harvest a debris field and returns the cargo", () => {
    const base = world(0);
    const ready: SimWorld = {
      ...base,
      planets: base.planets.map((planet) =>
        planet.id === 2 ? { ...planet, debrisOre: 30000, debrisCrystal: 10000 } : planet,
      ),
      empire: {
        ...base.empire,
        ships: { recycler: 1 },
      },
    };
    const sent = sendHarvest(ready, 1, 1, 3, 1, 0);
    expect(sent.empire.ships.recycler).toBe(0);
    expect(sent.fleets[0].mission).toBe("harvest");
    expect(() => sendHarvest(sent, 1, 1, 3, 1, 0)).toThrow(/recyclers/i);
    const arrived = catchUpWorld(sent, sent.fleets[0].arrivesAt);
    const harvesting = arrived.fleets.find((f) => f.id === sent.fleets[0].id)!;
    expect(harvesting.mission).toBe("harvest_return");
    expect(harvesting.cargoOre).toBe(15000);
    expect(harvesting.cargoCrystal).toBe(5000);
    const field = arrived.planets.find((p) => p.id === 2)!;
    expect(field.debrisOre).toBe(15000);
    expect(field.debrisCrystal).toBe(5000);
    const home = catchUpWorld(arrived, harvesting.arrivesAt);
    expect(home.empire.ships.recycler).toBe(1);
    expect(home.planets[0].ore).toBeGreaterThan(ready.planets[0].ore);
    expect(home.reports.some((r) => r.title === "Harvest returned")).toBe(true);
  });

  it("mines a shared asteroid belt until the barge hold is full then returns", () => {
    const base = world(0);
    const belt = {
      galaxy: 1,
      system: 1,
      beltSlot: 17 as const,
      afterSlot: 4,
      ore: 80000,
      crystal: 20000,
      capOre: 80000,
      capCrystal: 20000,
      emptiedAt: null,
      lastMinedAt: 0,
    };
    const ready: SimWorld = {
      ...base,
      belts: [belt],
      planets: base.planets.map((planet) =>
        planet.id === 1 ? { ...planet, deuterium: 5000 } : planet,
      ),
      empire: { ...base.empire, ships: { mining_barge: 2 }, propulsionLevel: 3 },
    };
    const sent = sendMine(ready, 1, 1, 17, 1, 0);
    expect(sent.empire.ships.mining_barge).toBe(1);
    expect(sent.fleets[0].mission).toBe("mine");
    const landAt = sent.fleets[0].arrivesAt;
    const arrived = catchUpWorld(sent, landAt);
    const sitting = arrived.fleets.find((f) => f.id === sent.fleets[0].id)!;
    expect(sitting.mission).toBe("mine_hold");
    const hourLater = catchUpWorld(arrived, landAt + GAME_HOUR_SECONDS * 1000);
    const mining = hourLater.fleets.find((f) => f.id === sent.fleets[0].id)!;
    expect(mining.mission).toBe("mine_hold");
    expect(mining.cargoOre + mining.cargoCrystal).toBe(MINING_BARGE_RATE_PER_HOUR);
    const remaining = hourLater.belts!.find((row) => row.beltSlot === 17)!;
    expect(remaining.ore + remaining.crystal).toBe(100000 - MINING_BARGE_RATE_PER_HOUR);

    const secondAt = landAt + GAME_HOUR_SECONDS * 1000;
    const second = sendMine(
      { ...hourLater, empire: { ...hourLater.empire, ships: { mining_barge: 1 } } },
      1,
      1,
      17,
      1,
      secondAt,
    );
    const bothOnSite = catchUpWorld(second, second.fleets[1].arrivesAt + GAME_HOUR_SECONDS * 1000);
    const a = bothOnSite.fleets.find((f) => f.id === sent.fleets[0].id)!;
    const b = bothOnSite.fleets.find((f) => f.id === second.fleets[1].id)!;
    expect(a.mission === "mine_hold" || a.mission === "mine_return").toBe(true);
    expect(b.mission === "mine_hold" || b.mission === "mine_return").toBe(true);
    const taken =
      100000 -
      (bothOnSite.belts!.find((row) => row.beltSlot === 17)!.ore +
        bothOnSite.belts!.find((row) => row.beltSlot === 17)!.crystal);
    expect(taken).toBeGreaterThan(MINING_BARGE_RATE_PER_HOUR);

    const recalled = recallFleet(arrived, sent.fleets[0].id, landAt + 1000);
    expect(recalled.fleets[0].mission).toBe("mine_return");

    const spyOnBelt = {
      ...arrived,
      empire: {
        ...arrived.empire,
        espionageTech: 2,
        ships: { ...arrived.empire.ships, espionage_probe: 0 },
      },
      fleets: [
        ...arrived.fleets,
        {
          id: 99,
          ownerId: arrived.empire.userId,
          originPlanetId: 1,
          destPlanetId: null,
          destGalaxy: 1,
          destSystem: 1,
          destSlot: 17,
          raiders: 1,
          composition: { espionage_probe: 1 },
          mission: "espionage" as const,
          arrivesAt: landAt + 1000,
          cargoOre: 0,
          cargoCrystal: 0,
          launchedAt: landAt,
          status: "en_route" as const,
          report: null,
        },
      ],
    };
    const spied = catchUpWorld(spyOnBelt, landAt + 1000);
    const report = spied.reports.find((row) => row.title === "Espionage report");
    expect(report?.body).toMatch(/Resources at probe arrival/);
    expect(report?.body).toMatch(/Ore:/);
    expect(report?.body).toMatch(/Crystal:/);
    expect(report?.body).toMatch(/Miners/);
    expect(report?.body).toMatch(/barge/);
  });

  it("sends a colony ship to an empty slot and founds a planet", () => {
    const base = world(0);
    const ready: SimWorld = {
      ...base,
      empire: {
        ...base.empire,
        astrophysics: 1,
        impulseDrive: 3,
        ships: { colony_ship: 1 },
      },
    };
    expect(() => sendColonize(base, 1, 1, 8, 1, 0)).toThrow(/Astronomy 1/);
    expect(() => sendColonize(ready, 1, 1, 4, 1, 0)).toThrow(/slots 7–9/);
    expect(() => sendColonize({ ...ready, empire: { ...ready.empire, astrophysics: 10 } }, 1, 1, 3, 1, 0)).toThrow(
      /occupied/,
    );
    const sent = sendColonize(ready, 1, 1, 8, 1, 0);
    expect(sent.empire.ships.colony_ship).toBe(0);
    expect(sent.fleets[0].mission).toBe("colonize");
    const arrived = catchUpWorld(sent, sent.fleets[0].arrivesAt);
    const colony = arrived.planets.find((p) => p.slot === 8 && p.ownerId === "u1");
    expect(colony).toBeTruthy();
    expect(colony?.oreMine).toBe(0);
    expect(arrived.empire.ships.colony_ship ?? 0).toBe(0);
    expect(arrived.reports.some((r) => r.title === "Colony founded")).toBe(true);
    expect(() => sendColonize({ ...arrived, empire: { ...arrived.empire, ships: { colony_ship: 1 } } }, 1, 1, 7, 1, arrived.fleets[0]?.arrivesAt ?? 0)).toThrow(
      /colony slots/i,
    );
  });

  it("runs mine and shipyard queues per planet and shares empire research", () => {
    const base = world(0);
    const home: SimPlanet = {
      ...base.planets[0],
      ore: 40000,
      crystal: 40000,
      deuterium: 40000,
      shipyard: 2,
      researchLab: 4,
    };
    const colony: SimPlanet = {
      ...base.planets[0],
      id: 3,
      slot: 8,
      name: "Colony",
      ore: 40000,
      crystal: 40000,
      deuterium: 40000,
      shipyard: 2,
      researchLab: 1,
    };
    const two: SimWorld = {
      ...base,
      planets: [home, base.planets[1], colony],
      empire: { ...base.empire, propulsionLevel: 5, impulseDrive: 5, energyTech: 1 },
    };

    const miningHome = startUpgrade(two, "ore_mine", 0);
    const onColony = selectPlanet(miningHome, 3);
    const miningBoth = startUpgrade(onColony, "crystal_mine", 0);
    expect(miningBoth.planets.find((p) => p.id === 1)?.upgradeBuilding).toBe("ore_mine");
    expect(miningBoth.planets.find((p) => p.id === 3)?.upgradeBuilding).toBe("crystal_mine");

    const yardColony = queueShip(miningBoth, "small_cargo", 1, 0);
    expect(yardColony.planets.find((p) => p.id === 3)?.shipsQueued).toBe(1);
    const onHome = selectPlanet(yardColony, 1);
    const yardHome = queueShip(onHome, "light_fighter", 1, 0);
    expect(yardHome.planets.find((p) => p.id === 1)?.shipBuilding).toBe("light_fighter");
    expect(yardHome.planets.find((p) => p.id === 3)?.shipBuilding).toBe("small_cargo");
    expect(researchLevel(yardHome.empire, "combustion_drive")).toBe(5);

    const backColony = selectPlanet(yardHome, 3);
    expect(() => startResearch(backColony, "weapons_tech", 0)).toThrow(/Research lab 4/);
    const researching = startResearch(backColony, "energy_tech", 0);
    expect(researching.empire.researchTech).toBe("energy_tech");
    expect(researching.planets.find((p) => p.id === 3)?.upgradeBuilding).toBe("crystal_mine");
  });

  it("deploys ships to another owned planet and leaves them there", () => {
    const base = world(0);
    const colony: SimPlanet = {
      ...base.planets[0],
      id: 3,
      slot: 8,
      name: "Colony",
      ships: {},
    };
    const two: SimWorld = {
      ...base,
      planets: [base.planets[0], base.planets[1], colony],
      empire: {
        ...base.empire,
        ships: { light_fighter: 2, small_cargo: 1 },
        raiders: 1,
        pirateRaidsEnabled: false,
      },
    };
    expect(() => sendDeploy(two, 1, 1, 3, { light_fighter: 1 }, { ore: 0, crystal: 0, deuterium: 0 }, 100, 0)).toThrow(
      /own planets/i,
    );
    const sent = sendDeploy(two, 1, 1, 8, { light_fighter: 2 }, { ore: 0, crystal: 0, deuterium: 0 }, 100, 0);
    expect(sent.empire.ships.light_fighter ?? 0).toBe(0);
    expect(sent.fleets[0].mission).toBe("deploy");
    const arrived = catchUpWorld(sent, sent.fleets[0].arrivesAt);
    expect(arrived.fleets.find((f) => f.id === sent.fleets[0].id)?.status).toBe("completed");
    expect(arrived.planets.find((p) => p.id === 3)?.ships?.light_fighter).toBe(2);
    expect(arrived.empire.ships.light_fighter ?? 0).toBe(0);
    const onColony = selectPlanet(arrived, 3);
    expect(onColony.empire.ships.light_fighter).toBe(2);
  });

  it("triples mine output and shortens construction at ×3 economy speed", () => {
    const base = world(0);
    const fast: SimWorld = { ...base, empire: { ...base.empire, economySpeed: 3 } };
    const grown = catchUpWorld(fast, GAME_HOUR_SECONDS * 1000);
    const slow = catchUpWorld(base, GAME_HOUR_SECONDS * 1000);
    expect(grown.planets[0].ore - STARTING_ORE).toBe((slow.planets[0].ore - STARTING_ORE) * 3);
    const building = startUpgrade(fast, "ore_mine", 0);
    expect(building.planets[0].upgradeCompletesAt).toBe(buildingTimeSeconds("ore_mine", 1, 0, 0, 3) * 1000);
  });

  it("credits eight hours of L11 ore at the live hourly rate when tanks have room", () => {
    const hours = 8;
    const later = hours * GAME_HOUR_SECONDS * 1000;
    const hold: SimPlanet = {
      ...world(0).planets[0],
      ore: 0,
      crystal: 0,
      oreMine: 11,
      crystalMine: 1,
      deuteriumExtractor: 0,
      powerPlant: 20,
      oreStorage: 12,
      crystalStorage: 12,
      lastHarvestedAt: 0,
      economySpeed: 1,
    };
    const live = livePlanet(hold, 0);
    expect(Math.floor(live.orePerHour)).toBe(mineProductionPerHour(11));
    expect(live.energy.factor).toBe(1);
    const after = tickPlanet(hold, later);
    expect(after.ore).toBe(Math.floor(live.orePerHour * hours));
    expect(after.ore).toBe(941 * 8);
  });

  it("credits eight hours of L11 ore at ×3 economy speed", () => {
    const hours = 8;
    const later = hours * GAME_HOUR_SECONDS * 1000;
    const hold: SimPlanet = {
      ...world(0).planets[0],
      ore: 0,
      oreMine: 11,
      crystalMine: 1,
      deuteriumExtractor: 0,
      powerPlant: 20,
      oreStorage: 12,
      lastHarvestedAt: 0,
      economySpeed: 3,
    };
    const live = livePlanet(hold, 0);
    expect(Math.floor(live.orePerHour)).toBe(mineProductionPerHour(11) * 3);
    const after = tickPlanet(hold, later);
    expect(after.ore).toBe(Math.floor(live.orePerHour * hours));
    expect(after.ore).toBe(941 * 3 * 8);
  });

  it("stops overnight ore at the tank instead of the live hourly rate times eight hours", () => {
    const hours = 8;
    const later = hours * GAME_HOUR_SECONDS * 1000;
    const hold: SimPlanet = {
      ...world(0).planets[0],
      ore: 0,
      oreMine: 35,
      crystalMine: 1,
      deuteriumExtractor: 0,
      powerPlant: 40,
      oreStorage: 2,
      lastHarvestedAt: 0,
      economySpeed: 1,
    };
    const live = livePlanet(hold, 0);
    expect(Math.floor(live.orePerHour)).toBe(29507);
    expect(live.orePerHour * hours).toBeGreaterThan(200_000);
    const after = tickPlanet(hold, later);
    expect(after.ore).toBe(storageCap(2));
    expect(after.ore).toBe(40_000);
  });
});
