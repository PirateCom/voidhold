"use client";

import { useEmpire } from "@/components/empire-provider";
import { Countdown } from "@/components/countdown";
import { StripedProgress, TimedStripedProgress } from "@/components/striped-progress";
import {
  BUILDINGS,
  buildingCost,
  buildingTimeSeconds,
  cancelRefund,
  formatDuration,
  progressToward,
  upgradeEnergyDelta,
  type BuildingId,
} from "@/lib/game/catalog";

function levelOf(id: BuildingId, live: { oreMine: number; crystalMine: number; powerPlant: number }) {
  if (id === "ore_mine") return live.oreMine;
  if (id === "crystal_mine") return live.crystalMine;
  return live.powerPlant;
}

export function BuildingList() {
  const { live, state, pending, upgrade, cancelUpgrade, now } = useEmpire();
  if (!live || !state) return null;

  return (
    <div className="flex flex-col gap-3">
      {BUILDINGS.map((b) => {
        const level = levelOf(b.id, live);
        const cost = buildingCost(b.id, level);
        const energyDelta = upgradeEnergyDelta(b.id, level);
        const isPlant = b.id === "power_plant";
        const energyLabel = `${isPlant ? "+" : "-"}${energyDelta} energy`;
        const energyClass = isPlant ? "text-emerald-400" : "text-red-400";
        const busy = Boolean(state.planet.upgrade_building);
        const thisBusy = state.planet.upgrade_building === b.id;
        const durationMs = buildingTimeSeconds(level) * 1000;
        const refund = thisBusy
          ? cancelRefund(cost, progressToward(state.planet.upgrade_completes_at, durationMs, now))
          : null;
        return (
          <article key={b.id} className="rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4">
            <div className="flex items-start justify-between gap-3">
              <div>
                <h2 className="font-semibold">{b.name}</h2>
                <p className="mt-1 text-xs text-[var(--muted-fg)]">{b.blurb}</p>
              </div>
              <span className="rounded-full bg-[var(--muted)] px-2 py-1 font-mono text-xs">L{level}</span>
            </div>
            {thisBusy ? (
              <TimedStripedProgress
                className="mt-3"
                until={state.planet.upgrade_completes_at}
                durationMs={durationMs}
                now={now}
                tone="var(--accent)"
                label={`${b.name} upgrade`}
              />
            ) : (
              <StripedProgress className="mt-3" value={0} disabled label={b.name} animated={false} />
            )}
            <p className="mt-3 text-xs text-[var(--muted-fg)]">
              Next: {cost.ore.toLocaleString()} ore · {cost.crystal.toLocaleString()} crystal ·{" "}
              <span className={energyClass}>{energyLabel}</span>
              {" · "}
              {formatDuration(buildingTimeSeconds(level))}
            </p>
            {thisBusy ? (
              <>
                <p className="mt-3 text-sm">
                  Building… <Countdown until={state.planet.upgrade_completes_at} now={now} />
                </p>
                <p className="mt-1 text-xs text-[var(--muted-fg)]">
                  Cancel now for {refund?.ore.toLocaleString()} ore · {refund?.crystal.toLocaleString()} crystal
                </p>
                <button
                  type="button"
                  disabled={pending}
                  onClick={() => void cancelUpgrade()}
                  className="mt-3 h-11 w-full rounded-2xl border border-[var(--border)] bg-[var(--muted)] text-sm font-semibold disabled:opacity-50"
                >
                  Cancel upgrade
                </button>
              </>
            ) : (
              <button
                type="button"
                disabled={pending || busy}
                onClick={() => void upgrade(b.id)}
                className="mt-3 h-11 w-full rounded-2xl bg-[var(--accent)] text-sm font-semibold text-[var(--accent-fg)] disabled:opacity-50"
              >
                {busy ? "Yard occupied" : "Upgrade"}
              </button>
            )}
          </article>
        );
      })}
    </div>
  );
}
