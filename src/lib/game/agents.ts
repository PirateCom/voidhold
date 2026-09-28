export type AgentId = "mining" | "exploration" | "combat";

export type MissionKind = "harvest" | "expedition" | "espionage" | "pirate";

export type AgentMissionStatus = "offered" | "active" | "ready" | "claimed";

export type AgentSpec = {
  id: AgentId;
  name: string;
  role: string;
  blurb: string;
  kinds: MissionKind[];
};

export const AGENTS: AgentSpec[] = [
  {
    id: "mining",
    name: "Foreman Vesk",
    role: "Mining agent",
    blurb: "Salvage contracts. Recyclers on debris and asteroid fields.",
    kinds: ["harvest"],
  },
  {
    id: "exploration",
    name: "Pathfinder Nyx",
    role: "Exploration agent",
    blurb: "Void surveys at position 16, or silent recon with probes.",
    kinds: ["expedition", "espionage"],
  },
  {
    id: "combat",
    name: "Marshal Cinder",
    role: "Fighting agent",
    blurb: "Pirates on a clock. Hold the line when the wave arrives.",
    kinds: ["pirate"],
  },
];

export const MISSION_REWARDS: Record<MissionKind, { ore: number; crystal: number; deuterium: number }> = {
  harvest: { ore: 800, crystal: 200, deuterium: 50 },
  expedition: { ore: 400, crystal: 400, deuterium: 200 },
  espionage: { ore: 200, crystal: 300, deuterium: 150 },
  pirate: { ore: 300, crystal: 500, deuterium: 250 },
};

export function agentById(id: AgentId): AgentSpec {
  const agent = AGENTS.find((row) => row.id === id);
  if (!agent) throw new Error("Unknown agent.");
  return agent;
}

export function kindForAgent(agentId: AgentId, roll: number, hasSpyTarget: boolean): MissionKind {
  if (agentId === "mining") return "harvest";
  if (agentId === "combat") return "pirate";
  if (hasSpyTarget && roll < 0.5) return "espionage";
  return "expedition";
}

export function missionReportMatches(kind: MissionKind, title: string): boolean {
  if (kind === "harvest") return title === "Harvest returned";
  if (kind === "expedition") return title === "Expedition returned";
  if (kind === "espionage") return title === "Espionage report";
  return title.startsWith("Pirates struck");
}

export function missionReadyFromReports(
  kind: MissionKind,
  acceptedAt: string | null,
  reports: { title: string; created_at: string }[],
): boolean {
  if (!acceptedAt) return false;
  const since = new Date(acceptedAt).getTime();
  return reports.some(
    (row) => new Date(row.created_at).getTime() >= since && missionReportMatches(kind, row.title),
  );
}

export function formatMissionReward(reward: { ore: number; crystal: number; deuterium: number }): string {
  const parts: string[] = [];
  if (reward.ore) parts.push(`${reward.ore.toLocaleString()} ore`);
  if (reward.crystal) parts.push(`${reward.crystal.toLocaleString()} crystal`);
  if (reward.deuterium) parts.push(`${reward.deuterium.toLocaleString()} deuterium`);
  return parts.join(" · ") || "Nothing";
}
