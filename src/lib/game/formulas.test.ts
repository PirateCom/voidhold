import { describe, expect, it } from "vitest";
import {
  buildingCost,
  buildingTimeSeconds,
  crystalProductionPerHour,
  energyFactor,
  energyNow,
  fleetSpeedMultiplier,
  flightSeconds,
  GAME_HOUR_SECONDS,
  harvestAmount,
  mineEnergyDrain,
  mineProductionPerHour,
  powerOutput,
  raidLoot,
  RAIDER_CARGO,
  researchCost,
  storageCap,
} from "./catalog";

describe("production formulas", () => {
  it("gives L1 mines a balanced energy grid", () => {
    expect(powerOutput(1)).toBe(22);
    expect(mineEnergyDrain(1)).toBe(11);
    expect(energyFactor(1, 1, 1)).toBe(1);
    expect(energyNow(2, 2, 1).factor).toBeLessThan(1);
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
    expect(raidLoot(1000, 200)).toBe(200);
    expect(raidLoot(1000, 10_000)).toBe(500);
    expect(RAIDER_CARGO).toBe(5000);
  });
});
