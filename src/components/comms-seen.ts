"use client";

import { useSyncExternalStore } from "react";

const KEY = "voidhold:comms-seen-at";
const listeners = new Set<() => void>();

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function useCommsSeenAt(): number {
  return useSyncExternalStore(subscribe, () => Number(window.localStorage.getItem(KEY)) || 0, () => Infinity);
}

export function latestReportAt(reports?: { created_at: string }[]): number {
  return (reports ?? []).reduce((max, r) => Math.max(max, new Date(r.created_at).getTime() || 0), 0);
}

export function markCommsSeen(at: number) {
  if (at <= (Number(window.localStorage.getItem(KEY)) || 0)) return;
  window.localStorage.setItem(KEY, String(at));
  listeners.forEach((l) => l());
}
