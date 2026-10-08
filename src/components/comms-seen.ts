"use client";

import { useSyncExternalStore } from "react";

export type CommsTab = "fleets" | "news" | "admin";

const KEY = "voidhold:comms-seen";
const LEGACY_KEY = "voidhold:comms-seen-at";
const listeners = new Set<() => void>();

const EMPTY: Record<CommsTab, number> = { fleets: 0, news: 0, admin: 0 };
const SERVER_SEEN: Record<CommsTab, number> = { fleets: Infinity, news: Infinity, admin: Infinity };
let snapshot: Record<CommsTab, number> = EMPTY;

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function sameSeen(a: Record<CommsTab, number>, b: Record<CommsTab, number>) {
  return a.fleets === b.fleets && a.news === b.news && a.admin === b.admin;
}

function readSeen(): Record<CommsTab, number> {
  let next = EMPTY;
  if (typeof window !== "undefined") {
    try {
      const raw = window.localStorage.getItem(KEY);
      if (raw) {
        const parsed = JSON.parse(raw) as Partial<Record<CommsTab, number>>;
        next = {
          fleets: Number(parsed.fleets) || 0,
          news: Number(parsed.news) || 0,
          admin: Number(parsed.admin) || 0,
        };
      } else {
        const legacy = Number(window.localStorage.getItem(LEGACY_KEY)) || 0;
        next = { ...EMPTY, fleets: legacy };
      }
    } catch {
      next = EMPTY;
    }
  }
  if (!sameSeen(snapshot, next)) snapshot = next;
  return snapshot;
}

function writeSeen(next: Record<CommsTab, number>) {
  window.localStorage.setItem(KEY, JSON.stringify(next));
  listeners.forEach((l) => l());
}

export function useCommsSeen(): Record<CommsTab, number> {
  return useSyncExternalStore(subscribe, readSeen, () => SERVER_SEEN);
}

/** @deprecated use useCommsSeen().fleets */
export function useCommsSeenAt(): number {
  return useCommsSeen().fleets;
}

export function latestReportAt(reports?: { created_at: string }[]): number {
  return (reports ?? []).reduce((max, r) => Math.max(max, new Date(r.created_at).getTime() || 0), 0);
}

export function latestNoticeAt(
  notices: { channel: string; created_at: string }[] | undefined,
  channel: Exclude<CommsTab, "fleets">,
): number {
  return (notices ?? [])
    .filter((n) => n.channel === channel)
    .reduce((max, n) => Math.max(max, new Date(n.created_at).getTime() || 0), 0);
}

export function markCommsTabSeen(tab: CommsTab, at: number) {
  if (at <= 0) return;
  const current = readSeen();
  if (at <= current[tab]) return;
  writeSeen({ ...current, [tab]: at });
}

export function markCommsSeen(at: number) {
  markCommsTabSeen("fleets", at);
}

export function commsHasUnread(
  reports: { created_at: string }[] | undefined,
  notices: { channel: string; created_at: string }[] | undefined,
  seen: Record<CommsTab, number>,
): boolean {
  return (
    latestReportAt(reports) > seen.fleets ||
    latestNoticeAt(notices, "news") > seen.news ||
    latestNoticeAt(notices, "admin") > seen.admin
  );
}
