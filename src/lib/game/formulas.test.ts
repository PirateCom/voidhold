import { describe, expect, it } from "vitest";
import {
  buildingCost,
  buildingTimeSeconds,
  crystalProductionPerHour,
  energyAfterUpgrade,
  energyFactor,
  energyNow,
  fleetSpeedMultiplier,
  flightSeconds,
  gameClock,
  GAME_HOUR_SECONDS,
  harvestAmount,
  mineEnergyDrain,
  mineProductionPerHour,
  powerOutput,
  progressToward,
  raidHaul,
  raidLoot,
  RAIDER_CARGO,
  researchCost,
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

  it("caps storage", () => {
    expect(storageCap(1)).toBe(15000);
    expect(harvestAmount(14990, 30, GAME_HOUR_SECONDS, storageCap(1))).toBe(15000);
  });

  it("scales upgrade cost and time", () => {
    expect(buildingCost("ore_mine", 0)).toEqual({ ore: 60, crystal: 15 });
    expect(buildingCost("ore_mine", 1).ore).toBeGreaterThan(60);
    expect(buildingTimeSeconds(1)).toBeGreaterThan(buildingTimeSeconds(0));
    expect(researchCost(1).crystal).toBe(researchCost(0).crystal * 2);
  });

  it("shortens flights with propulsion and caps raid loot by cargo", () => {
    expect(fleetSpeedMultiplier(0)).toBe(1);
    expect(flightSeconds(1, 1, 1, 2, 10)).toBeLessThan(flightSeconds(1, 1, 1, 2, 0));
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
