import { describe, expect, it } from "vitest";
import { RAIDER_COST, STARTING_CRYSTAL, STARTING_ORE } from "./catalog";
import {
  catchUpWorld,
  queueRaiders,
  sendRaid,
  startResearch,
  startUpgrade,
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
    lastHarvestedAt: at,
    oreMine: 1,
    crystalMine: 1,
    powerPlant: 1,
    upgradeBuilding: null,
    upgradeCompletesAt: null,
  };
  const npc: SimPlanet = {
    id: 2,
    ownerId: null,
    system: 1,
    slot: 3,
    name: "Derelict Hulk",
    ore: 4000,
    crystal: 2000,
    lastHarvestedAt: at,
    oreMine: 1,
    crystalMine: 1,
    powerPlant: 1,
    upgradeBuilding: null,
    upgradeCompletesAt: null,
  };
  return {
    planets: [planet, npc],
    empire: {
      userId: "u1",
      homePlanetId: 1,
      propulsionLevel: 0,
      raiders: 0,
      raidersQueued: 0,
      raiderCompletesAt: null,
      researchCompletesAt: null,
    },
    fleets: [],
    reports: [],
  };
}

describe("time-skip simulation", () => {
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

  it("builds raiders and returns loot from an NPC raid", () => {
    const queued = queueRaiders(world(0), 1, 0);
    expect(queued.planets[0].ore).toBe(STARTING_ORE - RAIDER_COST.ore);
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

  it("completes propulsion research on a time skip", () => {
    const started = startResearch(world(0), 0);
    const done = catchUpWorld(started, started.empire.researchCompletesAt!);
    expect(done.empire.propulsionLevel).toBe(1);
    expect(done.empire.researchCompletesAt).toBeNull();
  });
});
