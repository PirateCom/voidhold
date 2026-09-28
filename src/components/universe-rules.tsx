"use client";

import { GAME_HOUR_SECONDS, mineProductionPerHour, normalizeEconomySpeed } from "@/lib/game/catalog";
import { useEmpire } from "@/components/empire-provider";

export function UniverseRules() {
  const { state } = useEmpire();
  const speed = normalizeEconomySpeed(state?.empire.economy_speed);
  const metalL1 = mineProductionPerHour(1);
  const realSeconds = GAME_HOUR_SECONDS / speed;
  const gameHour = realSeconds === 3600 ? "1 real hour" : `${Math.round(realSeconds / 60)} real minutes`;
  return (
    <dl className="sci-card mb-4 px-4">
      <div className="flex items-baseline justify-between gap-4 border-b border-[var(--border)] py-3">
        <dt className="text-sm text-[var(--muted-fg)]">Economy speed</dt>
        <dd className="text-right text-sm font-semibold">×{speed}</dd>
      </div>
      <div className="flex items-baseline justify-between gap-4 border-b border-[var(--border)] py-3">
        <dt className="text-sm text-[var(--muted-fg)]">Game hour</dt>
        <dd className="text-right text-sm font-semibold">{gameHour}</dd>
      </div>
      <div className="py-3">
        <dt className="text-sm text-[var(--muted-fg)]">Mines and buildings</dt>
        <dd className="mt-1 text-xs leading-relaxed text-[var(--muted-fg)]">
          Metal mine is floor(30 × L × 1.1^L) per hour (L1 = {metalL1}/h), then ×{speed}. Construction is (metal +
          crystal) / 2500 hours, then robotics, nanites, and economy speed. Research, the yard, and flights stay on
          the short session clocks.
        </dd>
      </div>
    </dl>
  );
}
