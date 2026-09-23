import { describe, expect, it } from "vitest";
import { RAIDER_COST, STARTING_CRYSTAL, STARTING_ORE, buildingCost, defenceCost, storageCap } from "./catalog";
import {
  EMPTY_DEFENCES,
  EMPTY_FACILITIES,
  EMPTY_RESEARCH,
  catchUpWorld,
  cancelUpgrade,
  queueDefence,
  queueRaiders,
  resetEmpire,
  sendRaid,
  spawnPirates,
  startResearch,
  startUpgrade,
  fillResources,
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
      researchCompletesAt: null,
      nextPirateAt: null,
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
    expect(() => startUpgrade(world(0), "lunar_base", 0)).toThrow(/moon/i);
    const started = startUpgrade(world(0), "robotics_factory", 0);
    expect(started.planets[0].ore).toBe(STARTING_ORE - 400);
    const done = catchUpWorld(started, started.planets[0].upgradeCompletesAt!);
    expect(done.planets[0].roboticsFactory).toBe(1);
  });

  it("builds raiders and returns loot from an NPC raid", () => {
    const base = world(0);
    const ready: SimWorld = {
      ...base,
      planets: base.planets.map((planet) => (planet.id === 1 ? { ...planet, ore: 8000, crystal: 8000 } : planet)),
      empire: { ...base.empire, propulsionLevel: 2 },
    };
    const queued = queueRaiders(ready, 1, 0);
    expect(queued.planets[0].ore).toBe(8000 - RAIDER_COST.ore);
    expect(() => queueRaiders(world(0), 1, 0)).toThrow(/Combustion drive 2/);
    const built = catchUpWorld(queued, queued.empire.raiderCompletesAt!);
    expect(built.empire.raiders).toBe(1);
    const sent = sendRaid(built, 2, 1, built.empire.raiderCompletesAt!);
    expect(sent.empire.raiders).toBe(0);
    const attackAt = sent.fleets[0].arrivesAt;
    const afterAttack = catchUpWorld(sent, attackAt);
    const returning = afterAttack.fleets.find((f) => f.id === sent.fleets[0].id)!;
    expect(returning.mission).toBe("return");
    expect(returning.cargoOre).toBeGreaterThan(0);
    const home = catchUpWorld(afterAttack, returning.arrivesAt);
    expect(home.empire.raiders).toBe(1);
    expect(home.planets[0].ore).toBeGreaterThan(built.planets[0].ore);
    expect(home.reports.length).toBe(1);
  });

  it("refunds half the cost when an upgrade is cancelled at 50%", () => {
    const started = startUpgrade(world(0), "ore_mine", 0);
    const mid = started.planets[0].upgradeCompletesAt! / 2;
    const ticked = catchUpWorld(started, mid);
    const cancelled = cancelUpgrade(started, mid);
    const refundOre = Math.floor(buildingCost("ore_mine", 1).ore * 0.5);
    const refundCrystal = Math.floor(buildingCost("ore_mine", 1).crystal * 0.5);
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
    const ready: SimWorld = { ...base, empire: { ...base.empire, energyTech: 1 } };
    expect(() => startResearch(base, "combustion_drive", 0)).toThrow(/Energy technology 1/);
    const started = startResearch(ready, "combustion_drive", 0);
    const done = catchUpWorld(started, started.empire.researchCompletesAt!);
    expect(done.empire.propulsionLevel).toBe(1);
    expect(done.empire.researchCompletesAt).toBeNull();
  });

  it("builds a rocket launcher and will not raise a second small dome", () => {
    const richer: SimWorld = {
      ...world(0),
      planets: world(0).planets.map((p) => (p.id === 1 ? { ...p, ore: 5000, crystal: 5000 } : p)),
    };
    const started = queueDefence(richer, "rocket_launcher", 2, 0);
    expect(started.planets[0].ore).toBe(5000 - defenceCost("rocket_launcher").ore * 2);
    const done = catchUpWorld(started, started.planets[0].defenceCompletesAt! + 10_000);
    expect(done.planets[0].rocketLauncher).toBe(2);
    expect(done.planets[0].defencesQueued).toBe(0);
    const dome = queueDefence(done, "small_shield_dome", 1, done.planets[0].lastHarvestedAt);
    const raised = catchUpWorld(dome, dome.planets[0].defenceCompletesAt!);
    expect(raised.planets[0].smallShieldDome).toBe(1);
    expect(() => queueDefence(raised, "small_shield_dome", 1, raised.planets[0].lastHarvestedAt)).toThrow(
      /one of those domes/i,
    );
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
  });

  it("debug spawn deploys pirates immediately", () => {
    const after = spawnPirates(world(0), 1000);
    expect(after.reports.length).toBe(1);
    expect(after.reports[0].body).toMatch(/ATK/);
    expect(after.empire.nextPirateAt).toBeGreaterThan(1000);
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
});
