"use client";

import { useEmpire } from "@/components/empire-provider";
import { Countdown } from "@/components/countdown";
import { BUILDINGS, buildingCost, buildingTimeSeconds, formatDuration, type BuildingId } from "@/lib/game/catalog";

function levelOf(id: BuildingId, live: { oreMine: number; crystalMine: number; powerPlant: number }) {
  if (id === "ore_mine") return live.oreMine;
  if (id === "crystal_mine") return live.crystalMine;
  return live.powerPlant;
}

export function BuildingList() {
  const { live, state, pending, upgrade, now } = useEmpire();
  if (!live || !state) return null;

  return (
    <div className="flex flex-col gap-3">
      {BUILDINGS.map((b) => {
        const level = levelOf(b.id, live);
        const cost = buildingCost(b.id, level);
        const busy = Boolean(state.planet.upgrade_building);
        const thisBusy = state.planet.upgrade_building === b.id;
        return (
          <article key={b.id} className="rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4">
            <div className="flex items-start justify-between gap-3">
              <div>
                <h2 className="font-semibold">{b.name}</h2>
                <p className="mt-1 text-xs text-[var(--muted-fg)]">{b.blurb}</p>
              </div>
              <span className="rounded-full bg-[var(--muted)] px-2 py-1 font-mono text-xs">L{level}</span>
            </div>
            <p className="mt-3 text-xs text-[var(--muted-fg)]">
              Next: {cost.ore.toLocaleString()} ore · {cost.crystal.toLocaleString()} crystal ·{" "}
              {formatDuration(buildingTimeSeconds(level))}
            </p>
            {thisBusy ? (
              <p className="mt-3 text-sm">
                Building… <Countdown until={state.planet.upgrade_completes_at} now={now} />
              </p>
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
