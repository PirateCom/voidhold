import { describe, expect, it } from "vitest";
import {
  buildingCost,
  canPayResources,
  buildingTimeSeconds,
  crystalProductionPerHour,
  deuteriumProductionPerHour,
  fusionDeuteriumBurnPerHour,
  fleetFuelOneWay,
  fleetFuelRoundTrip,
  wikiFlightDistance,
  diameterKm,
  fieldsFromDiameter,
  HOMEWORLD_DIAMETER_KM,
  energyAfterUpgrade,
  solarSatelliteEnergy,
  upgradeWouldCauseEnergyDeficit,
  energyFactor,
  energyNow,
  fieldsUsed,
  fleetSpeedMultiplier,
  flightSeconds,
  gameClock,
  GAME_HOUR_SECONDS,
  harvestAmount,
  mineEnergyDrain,
  mineProductionPerHour,
  powerOutput,
  planetTemperature,
  progressToward,
  rollMaxFields,
  starMultiplier,
  raidHaul,
  raidLoot,
  RAIDER_CARGO,
  expeditionFleetCap,
  rollExpeditionKind,
  researchCost,
  researchTechCost,
  unmetResearch,
  unmetShipBuild,
  unmetDefenceBuild,
  SHIPS,
  DEFENCES,
  storageCap,
  cancelRefund,
  defenceCost,
  defenceSpec,
  defenceTimeSeconds,
  emptyDefenceCounts,
  pirateCombat,
  debrisFromWrecks,
  debrisVisible,
  pirateWaveSize,
  pirateWavesPerHour,
  planetFieldCap,
  terraformerEnergy,
  terraformerExtraFields,
  terraformerFreeFields,
  upgradeEnergyDelta,
  spentOnBuildingLevels,
  spentOnResearchLevels,
  resourcesToScorePoints,
  scoreResources,
  researchRankPoints,
  fleetRankPoints,
} from "./catalog";

describe("resource costs", () => {
  it("blocks robotics L2 when the tank is short of 400 deut", () => {
    const cost = buildingCost("robotics_factory", 1);
    expect(cost.deuterium).toBe(400);
    expect(canPayResources({ ore: 10_000, crystal: 10_000, deuterium: 177 }, cost)).toBe(false);
    expect(canPayResources({ ore: 10_000, crystal: 10_000, deuterium: 400 }, cost)).toBe(true);
  });
});

describe("production formulas", () => {
  it("scales solar output by the system star", () => {
    expect(starMultiplier("medium")).toBe(1);
    expect(starMultiplier("young_hot")).toBe(1.5);
    expect(starMultiplier("old_cold")).toBe(0.75);
    expect(starMultiplier("pulsar")).toBe(3);
    expect(powerOutput(1, "pulsar")).toBe(66);
    expect(powerOutput(1)).toBe(22);
    expect(energyFactor(1, 1, 1, "old_cold")).toBeLessThan(1);
  });

  it("keeps a slot temperature span and shifts both ends together", () => {
    expect(planetTemperature(10, 0)).toEqual({ min: -10, max: 30 });
    expect(planetTemperature(10, -3)).toEqual({ min: -13, max: 27 });
    expect(planetTemperature(1, 4).max - planetTemperature(1, 4).min).toBe(60);
    expect(planetTemperature(15, -10).max - planetTemperature(15, -10).min).toBe(70);
  });

  it("rolls most planets inside the slot field band", () => {
    expect(rollMaxFields(2, 0.1, 0)).toBe(40);
    expect(rollMaxFields(2, 0.1, 1)).toBe(70);
    expect(rollMaxFields(8, 0.95, 0)).toBe(256);
    expect(rollMaxFields(8, 0.85, 0)).toBe(20);
    expect(diameterKm(173)).toBe(13153);
    expect(fieldsFromDiameter(HOMEWORLD_DIAMETER_KM, 0)).toBe(163);
    expect(fieldsFromDiameter(HOMEWORLD_DIAMETER_KM)).toBe(173);
    expect(fieldsUsed(1, 1, 1)).toBe(3);
    expect(fieldsUsed(1, 1, 1, 2, 1)).toBe(6);
    expect(fieldsUsed(1, 1, 1, 0, 0, 4)).toBe(7);
    expect(buildingCost("robotics_factory", 0)).toEqual({ ore: 400, crystal: 120, deuterium: 200 });
    expect(buildingCost("shipyard", 0)).toEqual({ ore: 400, crystal: 200, deuterium: 100 });
    expect(buildingCost("space_station", 1)).toEqual({ ore: 1000, crystal: 0, deuterium: 250 });
  });

  it("gives L1 mines a balanced energy grid", () => {
    expect(powerOutput(1)).toBe(22);
    expect(mineEnergyDrain(1)).toBe(11);
    expect(energyFactor(1, 1, 1)).toBe(1);
    expect(energyNow(2, 2, 1).factor).toBeLessThan(1);
  });

  it("shows ore mine L3 draining more than a L1 plant produces", () => {
    expect(mineEnergyDrain(3)).toBe(39);
    expect(energyNow(3, 1, 1)).toEqual({ output: 22, drain: 50, factor: 22 / 50 });
  });

  it("lists extra energy on the next upgrade", () => {
    expect(upgradeEnergyDelta("crystal_mine", 3)).toBe(mineEnergyDrain(4) - mineEnergyDrain(3));
    expect(upgradeEnergyDelta("power_plant", 1)).toBe(powerOutput(2) - powerOutput(1));
    expect(energyAfterUpgrade("crystal_mine", 3, 1, 1).drain).toBe(mineEnergyDrain(3) + mineEnergyDrain(2));
    expect(upgradeWouldCauseEnergyDeficit("ore_mine", 1, 1, 1)).toBe(true);
    expect(upgradeWouldCauseEnergyDeficit("ore_mine", 1, 1, 8)).toBe(false);
    expect(solarSatelliteEnergy(20, 20)).toBe(30);
    expect(solarSatelliteEnergy(204, 264)).toBe(65);
    expect(solarSatelliteEnergy(204, 264, "pulsar", 1)).toBe(195);
    expect(energyNow(3, 1, 1, "medium", 0, 0, 0, 1, 20, 20).output).toBe(52);
  });

  it("produces 30 ore per game-hour at ore mine L1", () => {
    expect(mineProductionPerHour(1)).toBe(33);
    expect(crystalProductionPerHour(1)).toBe(22);
    expect(harvestAmount(0, 30, GAME_HOUR_SECONDS, 10000)).toBe(30);
    expect(harvestAmount(0, 30, GAME_HOUR_SECONDS * 2, 10000)).toBe(60);
  });

  it("makes deuterium from the synthesizer, burns fusion, and charges wiki fleet fuel", () => {
    expect(deuteriumProductionPerHour(1, 30)).toBe(17);
    expect(fusionDeuteriumBurnPerHour(1)).toBe(11);
    expect(wikiFlightDistance(1, 1, 1, 1, 2, 1)).toBe(2795);
    expect(fleetFuelOneWay(1, 10, 2795)).toBe(3);
    expect(fleetFuelRoundTrip(1, 1, 1, 1, 1, 2, 1)).toBe(6);
  });

  it("caps storage with the exponential hold", () => {
    expect(storageCap(0)).toBe(10000);
    expect(storageCap(1)).toBe(20000);
    expect(storageCap(2)).toBe(40000);
    expect(storageCap(12)).toBe(18005000);
    expect(harvestAmount(9990, 30, GAME_HOUR_SECONDS, storageCap(0))).toBe(10000);
  });

  it("scales upgrade cost and time", () => {
    expect(buildingCost("deuterium_extractor", 0)).toEqual({ ore: 225, crystal: 75, deuterium: 0 });
    expect(buildingCost("deuterium_storage", 0)).toEqual({ ore: 1000, crystal: 1000, deuterium: 0 });
    expect(buildingCost("fusion_reactor", 0)).toEqual({ ore: 900, crystal: 360, deuterium: 180 });
    expect(buildingCost("ore_mine", 1).ore).toBeGreaterThan(60);
    expect(buildingCost("ore_storage", 0)).toEqual({ ore: 1000, crystal: 0, deuterium: 0 });
    expect(buildingCost("crystal_storage", 0)).toEqual({ ore: 1000, crystal: 500, deuterium: 0 });
    expect(buildingCost("ore_storage", 1)).toEqual({ ore: 2000, crystal: 0, deuterium: 0 });
    expect(buildingCost("terraformer", 0)).toEqual({ ore: 0, crystal: 50000, deuterium: 100000 });
    expect(buildingCost("terraformer", 1)).toEqual({ ore: 0, crystal: 100000, deuterium: 200000 });
    expect(buildingCost("terraformer", 9)).toEqual({ ore: 0, crystal: 25600000, deuterium: 51200000 });
    expect(terraformerEnergy(0)).toBe(1000);
    expect(terraformerEnergy(1)).toBe(2000);
    expect(terraformerEnergy(9)).toBe(512000);
    expect(terraformerExtraFields(1)).toBe(5);
    expect(terraformerExtraFields(2)).toBe(11);
    expect(terraformerExtraFields(10)).toBe(55);
    expect(terraformerFreeFields(1)).toBe(4);
    expect(terraformerFreeFields(2)).toBe(9);
    expect(terraformerFreeFields(10)).toBe(45);
    expect(planetFieldCap(173, 1)).toBe(178);
    expect(buildingTimeSeconds(1)).toBeGreaterThan(buildingTimeSeconds(0));
    expect(buildingTimeSeconds(0)).toBe(20);
    expect(buildingTimeSeconds(0, 1)).toBe(10);
    expect(buildingTimeSeconds(0, 2)).toBe(6);
    expect(buildingTimeSeconds(1, 1)).toBe(15);
    expect(buildingTimeSeconds(0, 0, 1)).toBe(10);
    expect(buildingTimeSeconds(0, 1, 1)).toBe(5);
    expect(researchCost(1).crystal).toBe(researchCost(0).crystal * 2);
    expect(researchTechCost("energy_tech", 0)).toEqual({ ore: 0, crystal: 800, deuterium: 400 });
    expect(researchTechCost("armour_tech", 1)).toEqual({ ore: 2000, crystal: 0, deuterium: 0 });
    expect(researchTechCost("combustion_drive", 0)).toEqual({ ore: 400, crystal: 0, deuterium: 600 });
    expect(researchTechCost("astrophysics", 1).ore).toBe(Math.floor(4000 * 1.75));
    expect(unmetResearch("energy_tech", () => 0, 0).map((need) => need.name)).toEqual(["Research lab"]);
    expect(unmetResearch("weapons_tech", () => 0, 3)[0]).toMatchObject({ name: "Research lab", level: 4 });
    expect(unmetResearch("shielding_tech", () => 0, 6).map((need) => `${need.name} ${need.level}`)).toEqual([
      "Energy technology 3",
    ]);
    expect(unmetResearch("graviton_tech", () => 0, 12)).toEqual([]);
    expect(unmetShipBuild(SHIPS.find((ship) => ship.id === "small_cargo")!, 0, () => 2).map((need) => need.name)).toEqual([
      "Shipyard",
    ]);
    expect(unmetShipBuild(SHIPS.find((ship) => ship.id === "light_fighter")!, 1, (id) => (id === "combustion_drive" ? 1 : 0))).toEqual(
      [],
    );
    expect(unmetShipBuild(SHIPS.find((ship) => ship.id === "light_fighter")!, 0, () => 1)[0]).toMatchObject({
      name: "Shipyard",
      level: 1,
    });
    expect(unmetShipBuild(SHIPS.find((ship) => ship.id === "deathstar")!, 12, () => 0)[0]).toMatchObject({
      name: "Hyperspace drive",
      level: 7,
    });
    expect(SHIPS.find((ship) => ship.id === "reaper")?.research.map((req) => req.id)).toEqual([
      "hyperspace_drive",
      "hyperspace_tech",
      "shielding_tech",
    ]);
    expect(SHIPS.find((ship) => ship.id === "pathfinder")?.research.map((req) => req.id)).toEqual(["hyperspace_drive"]);
    expect(unmetDefenceBuild(DEFENCES.find((d) => d.id === "rocket_launcher")!, 0, 0, () => 0)[0]).toMatchObject({
      name: "Shipyard",
      level: 1,
    });
    expect(unmetDefenceBuild(DEFENCES.find((d) => d.id === "light_laser")!, 2, 0, () => 0).map((n) => n.name)).toEqual([
      "Energy technology",
      "Laser technology",
    ]);
    expect(unmetDefenceBuild(DEFENCES.find((d) => d.id === "antiballistic_missile")!, 1, 0, () => 0)[0]).toMatchObject({
      name: "Missile silo",
      level: 2,
    });
    expect(
      unmetDefenceBuild(DEFENCES.find((d) => d.id === "plasma_turret")!, 8, 0, (id) => (id === "plasma_tech" ? 7 : 0)),
    ).toEqual([]);
  });

  it("shortens flights with propulsion and caps raid loot by cargo", () => {
    expect(fleetSpeedMultiplier(0)).toBe(1);
    expect(flightSeconds(1, 1, 1, 2, 10)).toBeLessThan(flightSeconds(1, 1, 1, 2, 0));
    expect(flightSeconds(1, 1, 1, 2, 0, 1, 2)).toBeGreaterThan(flightSeconds(1, 1, 1, 2, 0, 1, 1));
    expect(raidLoot(1000, 200, 1)).toBe(200);
    expect(raidLoot(1000, 10_000, 0)).toBe(250);
    expect(raidLoot(1000, 10_000, 1)).toBe(750);
    expect(raidHaul(1000, 1000, 100, 1, 1)).toEqual({ ore: 50, crystal: 50 });
    expect(RAIDER_CARGO).toBe(5000);
    expect(expeditionFleetCap(0)).toBe(0);
    expect(expeditionFleetCap(1)).toBe(1);
    expect(expeditionFleetCap(4)).toBe(2);
    expect(expeditionFleetCap(9)).toBe(3);
    expect(rollExpeditionKind(0)).toBe("nothing");
    expect(rollExpeditionKind(0.4)).toBe("resources");
    expect(rollExpeditionKind(0.75)).toBe("aliens");
    expect(rollExpeditionKind(0.78)).toBe("lost");
  });

  it("keeps the game clock aligned with the wall clock after a fetch", () => {
    expect(gameClock(1000, 5000, 5000)).toBe(1000);
    expect(gameClock(1000, 5000, 5500)).toBe(1500);
    expect(gameClock(1000, 0, 9000)).toBe(9000);
  });

  it("maps a timed job onto a 0–1 progress bar", () => {
    expect(progressToward(1000, 1000, 0)).toBe(0);
    expect(progressToward(1000, 1000, 500)).toBe(0.5);
    expect(progressToward(1000, 1000, 1000)).toBe(1);
    expect(progressToward(null, 1000, 500)).toBe(0);
  });

  it("refunds the remaining share of an upgrade cost", () => {
    expect(cancelRefund({ ore: 90, crystal: 22 }, 0)).toEqual({ ore: 90, crystal: 22, deuterium: 0 });
    expect(cancelRefund({ ore: 90, crystal: 22 }, 0.5)).toEqual({ ore: 45, crystal: 11, deuterium: 0 });
    expect(cancelRefund({ ore: 90, crystal: 22 }, 1)).toEqual({ ore: 0, crystal: 0, deuterium: 0 });
    expect(cancelRefund({ ore: 400, crystal: 120, deuterium: 200 }, 0.5)).toEqual({
      ore: 200,
      crystal: 60,
      deuterium: 100,
    });
  });

  it("prices defences from the wiki tables", () => {
    expect(defenceCost("rocket_launcher")).toEqual({ ore: 2000, crystal: 0, deuterium: 0 });
    expect(defenceCost("light_laser")).toEqual({ ore: 1500, crystal: 500, deuterium: 0 });
    expect(defenceCost("heavy_laser")).toEqual({ ore: 6000, crystal: 2000, deuterium: 0 });
    expect(defenceCost("ion_cannon")).toEqual({ ore: 5000, crystal: 3000, deuterium: 0 });
    expect(defenceCost("gauss_cannon")).toEqual({ ore: 20000, crystal: 15000, deuterium: 2000 });
    expect(defenceCost("plasma_turret")).toEqual({ ore: 50000, crystal: 50000, deuterium: 30000 });
    expect(defenceCost("small_shield_dome")).toEqual({ ore: 10000, crystal: 10000, deuterium: 0 });
    expect(defenceCost("large_shield_dome")).toEqual({ ore: 50000, crystal: 50000, deuterium: 0 });
    expect(defenceCost("antiballistic_missile")).toEqual({ ore: 8000, crystal: 0, deuterium: 2000 });
    expect(defenceCost("interplanetary_missile")).toEqual({ ore: 12500, crystal: 2500, deuterium: 10000 });
    expect(defenceSpec("small_shield_dome").unique).toBe(true);
    expect(defenceTimeSeconds("gauss_cannon")).toBeGreaterThan(defenceTimeSeconds("rocket_launcher"));
    expect(defenceSpec("rocket_launcher")).toMatchObject({ hull: 2000, shield: 20, attack: 80 });
    expect(defenceSpec("light_laser")).toMatchObject({ hull: 2000, shield: 25, attack: 100 });
    expect(defenceSpec("heavy_laser")).toMatchObject({ hull: 8000, shield: 100, attack: 250 });
    expect(defenceSpec("ion_cannon")).toMatchObject({ hull: 8000, shield: 500, attack: 150 });
    expect(defenceSpec("gauss_cannon")).toMatchObject({ hull: 35000, shield: 200, attack: 1100 });
    expect(defenceSpec("plasma_turret")).toMatchObject({ hull: 100000, shield: 300, attack: 3000 });
    expect(defenceSpec("small_shield_dome")).toMatchObject({ hull: 20000, shield: 2000, attack: 1 });
    expect(defenceSpec("large_shield_dome")).toMatchObject({ hull: 100000, shield: 10000, attack: 1 });
    expect(defenceSpec("antiballistic_missile")).toMatchObject({ hull: 8000, shield: 1, attack: 1 });
    expect(defenceSpec("interplanetary_missile")).toMatchObject({ hull: 15000, shield: 1, attack: 12000 });
  });

  it("scales pirate waves with guns and resolves simultaneous fire", () => {
    expect(pirateWavesPerHour(0)).toBe(1);
    expect(pirateWavesPerHour(8)).toBe(2);
    expect(pirateWaveSize(3, 0)).toBe(3);
    expect(pirateWaveSize(3, 1)).toBe(4);
    const counts = { ...emptyDefenceCounts(), rocket_launcher: 5 };
    const fight = pirateCombat(counts, 3, 1000, 1000, 0, 0);
    expect(fight.planetAtk).toBe(400);
    expect(fight.piratesLost).toBe(3);
    expect(fight.piratesLeft).toBe(0);
    expect(fight.counts.rocket_launcher).toBe(4);
    expect(fight.loot).toEqual({ ore: 0, crystal: 0 });
  });

  it("turns 30% of wrecked hull metal and crystal into debris", () => {
    expect(debrisFromWrecks(1, 3000, 1000)).toEqual({ ore: 900, crystal: 300 });
    expect(debrisFromWrecks(0, 3000, 1000)).toEqual({ ore: 0, crystal: 300 });
    expect(debrisVisible(0, 300)).toBe(false);
    expect(debrisVisible(900, 300)).toBe(true);
  });
});

describe("wiki rank scores", () => {
  it("awards 1 score point per 1000 resources spent on finished assets", () => {
    expect(spentOnBuildingLevels("ore_mine", 1) + spentOnBuildingLevels("crystal_mine", 1) + spentOnBuildingLevels("power_plant", 1)).toBe(252);
    expect(resourcesToScorePoints(252)).toBe(0);
    expect(resourcesToScorePoints(2000)).toBe(2);
    expect(
      scoreResources({
        buildings: {},
        research: {},
        defences: { rocket_launcher: 10 },
        ships: {},
      }),
    ).toBe(20_000);
    expect(resourcesToScorePoints(20_000)).toBe(20);
  });

  it("counts deuterium on research and ships still in flight", () => {
    expect(spentOnResearchLevels("energy_tech", 1)).toBe(1200);
    expect(researchRankPoints({ energy_tech: 2, laser_tech: 1 })).toBe(3);
    expect(
      scoreResources({
        buildings: {},
        research: {},
        defences: {},
        ships: { small_cargo: 1 },
        fleets: [{ composition: { small_cargo: 2 } }],
      }),
    ).toBe(3 * (2000 + 2000));
    expect(fleetRankPoints({ solar_satellite: 4 }, [{ raiders: 3 }])).toBe(7);
  });
});
