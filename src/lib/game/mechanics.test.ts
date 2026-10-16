import { describe, expect, it } from "vitest";
import { energyNow, mineEnergyDrain, mineProductionPerHour, normalizeMinePct } from "@/lib/game/catalog";
import {
  MAX_PLANET_RELICS,
  MECHANICS_GUIDE_SECTIONS,
  RELICS,
  STELLAR_EVENTS,
  planetRelicModifiers,
  relicSpec,
  stellarEventSpec,
} from "@/lib/game/mechanics";

describe("expansion mechanics", () => {
  it("exposes stellar events and ancient relics catalogs", () => {
    expect(STELLAR_EVENTS).toHaveLength(3);
    expect(stellarEventSpec("solar_flare")?.solarMultiplier).toBe(1.5);
    expect(stellarEventSpec("ion_storm")?.fuelMultiplier).toBe(2);
    expect(stellarEventSpec("meteor_shower")?.miningSpeedMultiplier).toBe(2);

    expect(RELICS).toHaveLength(4);
    expect(relicSpec("overclock_drill")?.mineProductionMultiplier).toBe(1.15);
    expect(MECHANICS_GUIDE_SECTIONS).toHaveLength(3);
  });

  it("combines up to MAX_PLANET_RELICS modifiers on a planet", () => {
    expect(MAX_PLANET_RELICS).toBe(2);
    const mods = planetRelicModifiers(["overclock_drill", "subspace_beacon", "repair_nanites"]);
    expect(mods.mineProductionMultiplier).toBeCloseTo(1.15);
    expect(mods.mineEnergyMultiplier).toBeCloseTo(1.2);
    expect(mods.fuelMultiplier).toBeCloseTo(0.8);
    // Third relic is ignored because MAX_PLANET_RELICS = 2
    expect(mods.defenceRebuildChance).toBe(0.7);
  });

  it("scales mine energy drain and production by 10% throttle increments", () => {
    expect(normalizeMinePct(undefined)).toBe(100);
    expect(normalizeMinePct(54)).toBe(50);
    expect(normalizeMinePct(-10)).toBe(0);
    expect(normalizeMinePct(120)).toBe(100);

    const full = energyNow(5, 5, 5, "medium", 0, 0, 0, 0, 30, 30, 0, {
      ore: 100,
      crystal: 100,
      deuterium: 100,
    });
    const halfOre = energyNow(5, 5, 5, "medium", 0, 0, 0, 0, 30, 30, 0, {
      ore: 50,
      crystal: 100,
      deuterium: 100,
    });
    expect(halfOre.drain).toBe(Math.floor(mineEnergyDrain(5) * 0.5) + mineEnergyDrain(5));
    expect(halfOre.drain).toBeLessThan(full.drain);
    expect(Math.floor(mineProductionPerHour(5) * 0.5)).toBe(Math.floor(mineProductionPerHour(5) / 2));
  });
});
