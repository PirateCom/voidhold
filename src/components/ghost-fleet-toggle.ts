"use client";

import { useSyncExternalStore } from "react";

const KEY = "voidhold:ghost-fleet";
const listeners = new Set<() => void>();

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function useGhostFleetEnabled(): boolean {
  return useSyncExternalStore(subscribe, () => window.localStorage.getItem(KEY) === "1", () => false);
}

export function setGhostFleetEnabled(on: boolean) {
  if (on) window.localStorage.setItem(KEY, "1");
  else window.localStorage.removeItem(KEY);
  listeners.forEach((l) => l());
}
