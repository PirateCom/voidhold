import { describe, expect, it } from "vitest";
import {
  buildingCost,
  buildingTimeSeconds,
  crystalProductionPerHour,
  diameterKm,
  fieldsFromDiameter,
  HOMEWORLD_DIAMETER_KM,
  energyAfterUpgrade,
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
  researchCost,
  researchTechCost,
  storageCap,
  cancelRefund,
  defenceCost,
  defenceSpec,
  defenceTimeSeconds,
  emptyDefenceCounts,
  pirateCombat,
  pirateWaveSize,
  pirateWavesPerHour,
  upgradeEnergyDelta,
} from "./catalog";

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
  });

  it("produces 30 ore per game-hour at ore mine L1", () => {
    expect(mineProductionPerHour(1)).toBe(33);
    expect(crystalProductionPerHour(1)).toBe(22);
    expect(harvestAmount(0, 30, GAME_HOUR_SECONDS, 10000)).toBe(30);
    expect(harvestAmount(0, 30, GAME_HOUR_SECONDS * 2, 10000)).toBe(60);
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
    expect(buildingTimeSeconds(1)).toBeGreaterThan(buildingTimeSeconds(0));
    expect(researchCost(1).crystal).toBe(researchCost(0).crystal * 2);
    expect(researchTechCost("energy_tech", 0)).toEqual({ ore: 0, crystal: 800, deuterium: 400 });
    expect(researchTechCost("armour_tech", 1)).toEqual({ ore: 2000, crystal: 0, deuterium: 0 });
    expect(researchTechCost("combustion_drive", 0)).toEqual({ ore: 400, crystal: 0, deuterium: 600 });
    expect(researchTechCost("astrophysics", 1).ore).toBe(Math.floor(4000 * 1.75));
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
    expect(cancelRefund({ ore: 90, crystal: 22 }, 0)).toEqual({ ore: 90, crystal: 22 });
    expect(cancelRefund({ ore: 90, crystal: 22 }, 0.5)).toEqual({ ore: 45, crystal: 11 });
    expect(cancelRefund({ ore: 90, crystal: 22 }, 1)).toEqual({ ore: 0, crystal: 0 });
  });

  it("prices defences from cheap rockets up to the gaussian turret", () => {
    expect(defenceCost("rocket_launcher").ore).toBeLessThan(defenceCost("light_laser").ore);
    expect(defenceCost("gauss_cannon").ore).toBeGreaterThan(defenceCost("heavy_laser").ore);
    expect(defenceCost("plasma_turret").ore).toBeGreaterThan(defenceCost("gauss_cannon").ore);
    expect(defenceCost("antiballistic_missile")).toEqual({ ore: 400, crystal: 0 });
    expect(defenceCost("interplanetary_missile").crystal).toBe(400);
    expect(defenceSpec("small_shield_dome").unique).toBe(true);
    expect(defenceTimeSeconds("gauss_cannon")).toBeGreaterThan(defenceTimeSeconds("rocket_launcher"));
    expect(defenceSpec("rocket_launcher").attack).toBe(8);
    expect(defenceSpec("rocket_launcher").defence).toBe(20);
    expect(defenceSpec("small_shield_dome").attack).toBe(0);
    expect(defenceSpec("large_shield_dome").defence).toBe(1000);
  });

  it("scales pirate waves with guns and resolves simultaneous fire", () => {
    expect(pirateWavesPerHour(0)).toBe(1);
    expect(pirateWavesPerHour(8)).toBe(2);
    expect(pirateWaveSize(3, 0)).toBe(3);
    expect(pirateWaveSize(3, 1)).toBe(4);
    const counts = { ...emptyDefenceCounts(), rocket_launcher: 5 };
    const fight = pirateCombat(counts, 3, 1000, 1000, 0, 0);
    expect(fight.planetAtk).toBe(40);
    expect(fight.piratesLost).toBe(2);
    expect(fight.piratesLeft).toBe(1);
    expect(fight.counts.rocket_launcher).toBe(4);
    expect(fight.loot).toEqual({ ore: 250, crystal: 250 });
  });
});
