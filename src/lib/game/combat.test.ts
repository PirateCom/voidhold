import { describe, expect, it } from "vitest";
import { emptyDefenceCounts, hullDrive, hullFuelUse, hullSpeed } from "./catalog";
import { plunder, resolveCombat, settleAttack, makeRng } from "./combat";

const zero = { weapons: 0, shielding: 0, armour: 0 };

describe("plunder", () => {
  it("takes half of each resource when cargo is large enough", () => {
    expect(plunder(5000, 4000, 2000, 0)).toEqual({ ore: 2000, crystal: 1000, deuterium: 0 });
  });

  it("fills leftover cargo with metal when crystal and deuterium are short", () => {
    expect(plunder(1000, 10000, 0, 0)).toEqual({ ore: 1000, crystal: 0, deuterium: 0 });
  });

  it("splits a tight hold across metal, crystal, and deuterium", () => {
    const haul = plunder(3000, 20000, 20000, 20000);
    expect(haul.ore + haul.crystal + haul.deuterium).toBe(3000);
    expect(haul.ore).toBeGreaterThan(0);
    expect(haul.crystal).toBeGreaterThan(0);
    expect(haul.deuterium).toBeGreaterThan(0);
  });
});

describe("combat", () => {
  it("lets an empty hold fall without a shot", () => {
    const fought = resolveCombat({ small_cargo: 1 }, {}, zero, zero, makeRng(1));
    expect(fought.outcome).toBe("attacker");
    expect(fought.rounds).toBe(0);
    expect(fought.attackers.small_cargo).toBe(1);
  });

  it("draws when one cargo cannot break a rocket launcher in six rounds", () => {
    const fought = resolveCombat({ small_cargo: 1 }, { rocket_launcher: 1 }, zero, zero, makeRng(1));
    expect(fought.outcome).toBe("draw");
    expect(fought.rounds).toBe(6);
    expect(fought.attackers.small_cargo).toBe(1);
    expect(fought.defenders.rocket_launcher).toBe(1);
  });

  it("wins when light fighters erase the only rocket", () => {
    const fought = resolveCombat({ light_fighter: 100 }, { rocket_launcher: 1 }, zero, zero, makeRng(1));
    expect(fought.outcome).toBe("attacker");
    expect(fought.rounds).toBe(1);
    expect(fought.defenders.rocket_launcher).toBeUndefined();
  });

  it("plunders half the abandoned stockpile and nothing on a draw", () => {
    const open = settleAttack({
      attackers: { small_cargo: 1 },
      defenderShips: {},
      defenderDefenses: emptyDefenceCounts(),
      attackerTech: zero,
      defenderTech: zero,
      ore: 4000,
      crystal: 2000,
      deuterium: 0,
      seed: 1,
    });
    expect(open.outcome).toBe("attacker");
    expect(open.plunder).toEqual({ ore: 2000, crystal: 1000, deuterium: 0 });

    const held = settleAttack({
      attackers: { small_cargo: 1 },
      defenderShips: {},
      defenderDefenses: { ...emptyDefenceCounts(), rocket_launcher: 1 },
      attackerTech: zero,
      defenderTech: zero,
      ore: 4000,
      crystal: 2000,
      deuterium: 800,
      seed: 1,
    });
    expect(held.outcome).toBe("draw");
    expect(held.plunder).toEqual({ ore: 0, crystal: 0, deuterium: 0 });
  });

  it("upgrades recycler drive at Impulse 17 and Hyperspace 15 and skims 25% debris with Reapers", () => {
    expect(hullDrive("recycler", 0, 0)).toBe("combustion");
    expect(hullSpeed("recycler", 0, 0, 6)).toBe(3200);
    expect(hullFuelUse("recycler", 0, 0)).toBe(300);

    expect(hullDrive("recycler", 17, 0)).toBe("impulse");
    expect(hullSpeed("recycler", 17, 0, 6)).toBe(Math.floor(4000 * (1 + 17 * 0.2)));
    expect(hullFuelUse("recycler", 17, 0)).toBe(600);

    expect(hullDrive("recycler", 17, 15)).toBe("hyperspace");
    expect(hullSpeed("recycler", 17, 15, 6)).toBe(Math.floor(6000 * (1 + 15 * 0.3)));
    expect(hullFuelUse("recycler", 17, 15)).toBe(900);

    const reaperFight = settleAttack({
      attackers: { reaper: 5 },
      defenderShips: { light_fighter: 10 },
      defenderDefenses: emptyDefenceCounts(),
      attackerTech: zero,
      defenderTech: zero,
      ore: 0,
      crystal: 0,
      deuterium: 0,
      seed: 1,
    });
    // 10 light fighters = 30,000 ore + 10,000 crystal -> 30% debris = 9,000 ore + 3,000 crystal
    // Reapers skim 25% of debris = 2,250 ore + 750 crystal
    expect(reaperFight.plunder).toEqual({ ore: 2250, crystal: 750, deuterium: 0 });
    expect(reaperFight.debris).toEqual({ ore: 6750, crystal: 2250 });
  });
});
