export type DailySlot = "belt" | "spy" | "wave" | "hop";

export type DailyKind = "mine" | "espionage" | "pirate" | "guns" | "transport" | "deploy" | "expedition";

export type DailyStatus = "active" | "ready" | "claimed";

export type DailyMissionRow = {
  id: number;
  day: string;
  slot: DailySlot;
  kind: DailyKind;
  status: DailyStatus;
  dest_galaxy: number | null;
  dest_system: number | null;
  dest_slot: number | null;
  title: string;
  blurb: string;
  reward_ore: number;
  reward_crystal: number;
  reward_deuterium: number;
  sort_order: number;
};

export const DAILY_REWARDS = {
  mine: { ore: 2500, crystal: 800, deuterium: 100 },
  espionage: { ore: 600, crystal: 1200, deuterium: 400 },
  pirate: { ore: 800, crystal: 1500, deuterium: 600 },
  guns: { ore: 1000, crystal: 400, deuterium: 0 },
  transport: { ore: 1000, crystal: 1000, deuterium: 500 },
  deploy: { ore: 1000, crystal: 1000, deuterium: 500 },
  expedition: { ore: 500, crystal: 500, deuterium: 800 },
} as const;

export const DAILY_SLOTS: DailySlot[] = ["belt", "spy", "wave", "hop"];

export function dailyReportMatches(
  kind: DailyKind,
  report: { title: string; body?: string },
  dest?: { galaxy: number | null; system: number | null; slot: number | null },
): boolean {
  const title = report.title;
  const body = report.body ?? "";
  if (kind === "mine") {
    return title === "Mining barge returned" && !/empty holds/i.test(body);
  }
  if (kind === "espionage") {
    if (title !== "Espionage report") return false;
    if (dest?.galaxy == null || dest.system == null || dest.slot == null) return true;
    return body.includes(`[${dest.galaxy}:${dest.system}:${dest.slot}]`);
  }
  if (kind === "pirate") return title.startsWith("Pirates struck");
  if (kind === "transport") return title === "Transport fleet returned" || title === "Transport received";
  if (kind === "deploy") return title === "Fleet deployed";
  if (kind === "expedition") return title === "Expedition returned";
  return false;
}

export function dailyReadyFromReports(
  kind: DailyKind,
  since: string,
  reports: { title: string; body?: string; created_at: string }[],
  dest?: { galaxy: number | null; system: number | null; slot: number | null },
): boolean {
  const start = new Date(since).getTime();
  return reports.some(
    (row) => new Date(row.created_at).getTime() >= start && dailyReportMatches(kind, row, dest),
  );
}

export function dailyActionHref(kind: DailyKind): string {
  if (kind === "guns") return "/defences";
  if (kind === "pirate") return "/fleets";
  return "/galaxy";
}

export function dailyActionLabel(kind: DailyKind): string {
  if (kind === "guns") return "Open defence";
  if (kind === "pirate") return "Open fleets";
  return "Open galaxy";
}
