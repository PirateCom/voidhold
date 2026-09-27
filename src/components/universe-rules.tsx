import { ECONOMY_SPEED, GAME_HOUR_SECONDS, mineProductionPerHour } from "@/lib/game/catalog";

export function UniverseRules() {
  const metalL1 = mineProductionPerHour(1);
  return (
    <dl className="sci-card mb-4 px-4">
      <div className="flex items-baseline justify-between gap-4 border-b border-[var(--border)] py-3">
        <dt className="text-sm text-[var(--muted-fg)]">Economy speed</dt>
        <dd className="text-right text-sm font-semibold">×{ECONOMY_SPEED}</dd>
      </div>
      <div className="flex items-baseline justify-between gap-4 border-b border-[var(--border)] py-3">
        <dt className="text-sm text-[var(--muted-fg)]">Game hour</dt>
        <dd className="text-right text-sm font-semibold">
          {GAME_HOUR_SECONDS === 3600 ? "1 real hour" : `${GAME_HOUR_SECONDS}s`}
        </dd>
      </div>
      <div className="py-3">
        <dt className="text-sm text-[var(--muted-fg)]">Mines and buildings</dt>
        <dd className="mt-1 text-xs leading-relaxed text-[var(--muted-fg)]">
          Metal mine is floor(30 × L × 1.1^L) per hour (L1 = {metalL1}/h). Construction is (metal + crystal) /
          2500 hours, then robotics and nanites. Research, the yard, and flights stay on the short session
          clocks.
        </dd>
      </div>
    </dl>
  );
}
