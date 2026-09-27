import { describe, expect, it } from "vitest";
import { emptyDefenceCounts } from "./catalog";
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
});
