import { describe, expect, it } from "vitest";
import {
  AGENTS,
  MISSION_REWARDS,
  kindForAgent,
  missionReadyFromReports,
  missionReportMatches,
} from "./agents";

describe("agent missions", () => {
  it("gives mining harvest, combat pirates, and exploration a void or spy job", () => {
    expect(kindForAgent("mining", 0, true)).toBe("harvest");
    expect(kindForAgent("combat", 0, true)).toBe("pirate");
    expect(kindForAgent("exploration", 0.2, true)).toBe("espionage");
    expect(kindForAgent("exploration", 0.8, true)).toBe("expedition");
    expect(kindForAgent("exploration", 0.1, false)).toBe("expedition");
    expect(AGENTS.every((agent) => agent.kinds.length > 0)).toBe(true);
  });

  it("pays ore, crystal, and deuterium on every kind", () => {
    for (const reward of Object.values(MISSION_REWARDS)) {
      expect(reward.ore + reward.crystal + reward.deuterium).toBeGreaterThan(0);
      expect(reward.ore).toBeGreaterThan(0);
      expect(reward.crystal).toBeGreaterThan(0);
      expect(reward.deuterium).toBeGreaterThan(0);
    }
  });

  it("marks a job ready from matching reports after accept", () => {
    expect(missionReportMatches("harvest", "Harvest returned")).toBe(true);
    expect(missionReportMatches("expedition", "Expedition returned")).toBe(true);
    expect(missionReportMatches("espionage", "Espionage report")).toBe(true);
    expect(missionReportMatches("pirate", "Pirates struck. 2 small cargo lost.")).toBe(true);
    expect(missionReportMatches("harvest", "Expedition returned")).toBe(false);

    const acceptedAt = "2026-09-28T20:00:00.000Z";
    const reports = [
      { title: "Harvest returned", created_at: "2026-09-28T19:00:00.000Z" },
      { title: "Harvest returned", created_at: "2026-09-28T20:01:00.000Z" },
    ];
    expect(missionReadyFromReports("harvest", acceptedAt, reports)).toBe(true);
    expect(missionReadyFromReports("harvest", acceptedAt, [reports[0]])).toBe(false);
    expect(missionReadyFromReports("harvest", null, reports)).toBe(false);
  });
});
