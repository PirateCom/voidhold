import { describe, expect, it } from "vitest";
import { DAILY_REWARDS, DAILY_SLOTS, dailyReadyFromReports, dailyReportMatches } from "./dailies";

describe("daily missions", () => {
  it("keeps four slots and pays on every kind", () => {
    expect(DAILY_SLOTS).toEqual(["belt", "spy", "wave", "hop"]);
    for (const reward of Object.values(DAILY_REWARDS)) {
      expect(reward.ore + reward.crystal + reward.deuterium).toBeGreaterThan(0);
    }
    expect(DAILY_REWARDS.mine).toEqual({ ore: 2500, crystal: 800, deuterium: 100 });
    expect(DAILY_REWARDS.espionage).toEqual({ ore: 600, crystal: 1200, deuterium: 400 });
    expect(DAILY_REWARDS.pirate).toEqual({ ore: 800, crystal: 1500, deuterium: 600 });
    expect(DAILY_REWARDS.guns).toEqual({ ore: 1000, crystal: 400, deuterium: 0 });
    expect(DAILY_REWARDS.transport).toEqual({ ore: 1000, crystal: 1000, deuterium: 500 });
    expect(DAILY_REWARDS.expedition).toEqual({ ore: 500, crystal: 500, deuterium: 800 });
  });

  it("marks belt, spy, wave, and hop from matching reports after the daily stamp", () => {
    expect(dailyReportMatches("mine", { title: "Mining barge returned", body: "Unloaded at Hold [1:1:8]: 12 ore" })).toBe(
      true,
    );
    expect(dailyReportMatches("mine", { title: "Mining barge returned", body: "Docked at Hold [1:1:8] with empty holds." })).toBe(
      false,
    );
    expect(
      dailyReportMatches(
        "espionage",
        { title: "Espionage report", body: "Espionage report from Guns [2:40:5]" },
        { galaxy: 2, system: 40, slot: 5 },
      ),
    ).toBe(true);
    expect(
      dailyReportMatches(
        "espionage",
        { title: "Espionage report", body: "Espionage report from Guns [2:40:6]" },
        { galaxy: 2, system: 40, slot: 5 },
      ),
    ).toBe(false);
    expect(dailyReportMatches("pirate", { title: "Pirates struck. 2 small cargo lost." })).toBe(true);
    expect(dailyReportMatches("transport", { title: "Transport fleet returned" })).toBe(true);
    expect(dailyReportMatches("deploy", { title: "Fleet deployed" })).toBe(true);
    expect(dailyReportMatches("expedition", { title: "Expedition returned" })).toBe(true);

    const since = "2026-10-10T00:00:00.000Z";
    expect(
      dailyReadyFromReports("mine", since, [
        { title: "Mining barge returned", body: "Unloaded 10 ore", created_at: "2026-10-09T23:00:00.000Z" },
      ]),
    ).toBe(false);
    expect(
      dailyReadyFromReports("mine", since, [
        { title: "Mining barge returned", body: "Unloaded 10 ore", created_at: "2026-10-10T01:00:00.000Z" },
      ]),
    ).toBe(true);
  });
});
