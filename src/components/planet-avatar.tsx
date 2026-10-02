"use client";

import { useSyncExternalStore } from "react";

const OVERRIDE_KEY = "voidhold:planet-avatar-overrides";
const LEGACY_KEY = "voidhold:planet-avatar-override";
const listeners = new Set<() => void>();

function readMap(): Record<string, number> {
  try {
    const raw = window.localStorage.getItem(OVERRIDE_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    const out: Record<string, number> = {};
    for (const [key, value] of Object.entries(parsed)) {
      if (typeof value === "number" && Number.isInteger(value)) out[key] = value;
    }
    return out;
  } catch {
    return {};
  }
}

function readOverride(seed: string): number | null {
  const n = readMap()[seed];
  return Number.isInteger(n) ? n : null;
}

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function usePlanetAvatarOverride(seed: string): number | null {
  return useSyncExternalStore(subscribe, () => readOverride(seed), () => null);
}

export function setPlanetAvatarOverride(seed: string, index: number | null) {
  const next = readMap();
  if (index == null) delete next[seed];
  else next[seed] = index;
  window.localStorage.removeItem(LEGACY_KEY);
  if (Object.keys(next).length === 0) window.localStorage.removeItem(OVERRIDE_KEY);
  else window.localStorage.setItem(OVERRIDE_KEY, JSON.stringify(next));
  listeners.forEach((l) => l());
}

const SHEET = "/sprites/ogame_sprite.jpg";
const CELL = 30;
const COLUMNS_X = [5, 43, 81, 119, 157, 195, 233, 271, 309, 347];
const ROWS_Y = [5000, 5033, 5066, 5099, 5132, 5165, 5198];

export const PLANET_AVATAR_COUNT = COLUMNS_X.length * ROWS_Y.length;

function hash(seed: string): number {
  let h = 2166136261;
  for (let i = 0; i < seed.length; i++) {
    h ^= seed.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

export function planetAvatarIndex(seed: string): number {
  return hash(seed) % PLANET_AVATAR_COUNT;
}

export function PlanetAvatar({ seed, size = 34, own = true }: { seed: string; size?: number; own?: boolean }) {
  const override = usePlanetAvatarOverride(seed);
  const index = own && override != null ? override % PLANET_AVATAR_COUNT : planetAvatarIndex(seed);
  const x = COLUMNS_X[index % COLUMNS_X.length];
  const y = ROWS_Y[Math.floor(index / COLUMNS_X.length)];
  return (
    <div className="relative shrink-0 overflow-hidden rounded-full" style={{ width: size, height: size }} aria-hidden>
      <div
        className="absolute top-0 left-0"
        style={{
          width: CELL,
          height: CELL,
          backgroundImage: `url(${SHEET})`,
          backgroundRepeat: "no-repeat",
          backgroundPosition: `-${x}px -${y}px`,
          transform: `scale(${size / CELL})`,
          transformOrigin: "top left",
        }}
      />
    </div>
  );
}
