import { describe, expect, it } from "vitest";
import { energyNow } from "./catalog";
import {
  DIRECTIVES,
  activeDirective,
  directiveComplete,
  directiveProgress,
  directiveUnlocked,
  formatDirectiveReward,
  previousDirectiveId,
} from "./directives";

const starter = {
  ore_mine: 1,
  crystal_mine: 1,
  deuterium_extractor: 0,
  power_plant: 1,
  fusion_reactor: 0,
  ore_storage: 0,
  crystal_storage: 0,
  deuterium_storage: 0,
  starType: "medium" as const,
};

describe("beginner directives", () => {
  it("starts with ore L1 collectable and energy waiting on surplus", () => {
    const ore = DIRECTIVES.find((d) => d.id === "ore_l1")!;
    const energy = DIRECTIVES.find((d) => d.id === "energy")!;
    expect(directiveComplete(ore, starter)).toBe(true);
    expect(directiveComplete(energy, starter)).toBe(false);
    const { output, drain } = energyNow(1, 1, 1, "medium");
    expect(output).toBe(drain);
    expect(directiveComplete(energy, { ...starter, power_plant: 2 })).toBe(true);
  });

  it("unlocks the next directive only after the previous reward is claimed", () => {
    expect(previousDirectiveId("ore_l1")).toBeNull();
    expect(previousDirectiveId("energy")).toBe("ore_l1");
    expect(directiveUnlocked([], "energy")).toBe(false);
    expect(directiveUnlocked(["ore_l1"], "energy")).toBe(true);
    expect(activeDirective([])?.id).toBe("ore_l1");
    expect(activeDirective(["ore_l1"])?.id).toBe("energy");
  });

  it("skips mine-output sliders and uses Voidhold building names", () => {
    const labels = DIRECTIVES.flatMap((d) => d.objectives.map((o) => o.label)).join(" ");
    expect(labels).not.toMatch(/90%/);
    expect(labels).not.toMatch(/100%/);
    expect(labels).toMatch(/Ore mine/);
    expect(labels).toMatch(/Deuterium extractor/);
    expect(DIRECTIVES.at(-1)?.id).toBe("storage");
    expect(directiveProgress(DIRECTIVES.find((d) => d.id === "ore_solar_mid")!, { ...starter, ore_mine: 3, power_plant: 3 })).toEqual({
      done: 2,
      total: 3,
    });
    expect(formatDirectiveReward({ ore: 50, crystal: 30, deuterium: 0 })).toBe("50 ore · 30 crystal");
  });
});
