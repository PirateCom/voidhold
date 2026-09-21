"use client";

import { useState } from "react";
import { AppShell } from "@/components/app-shell";
import { Countdown } from "@/components/countdown";
import { useEmpire } from "@/components/empire-provider";
import { StripedProgress, TimedStripedProgress } from "@/components/striped-progress";
import {
  DEFENCES,
  PIRATE_ATTACK,
  PIRATE_DEFENCE,
  defenceUnitCount,
  formatDuration,
  planetAttack,
  planetDefence,
  type DefenceId,
} from "@/lib/game/catalog";
import { defenceCountsOf, defenceOwned, type SimPlanet } from "@/lib/game/simulate";

function countOf(id: DefenceId, planet: SimPlanet): number {
  return defenceOwned(planet, id);
}

export default function DefencesPage() {
  const { error, state, live, pending, buildDefence, now } = useEmpire();
  const [queues, setQueues] = useState<Partial<Record<DefenceId, number>>>({});

  if (!state || !live) {
    return (
      <AppShell title="Defences">
        {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
        <p className="text-sm text-[var(--muted-fg)]">{state ? "Establishing a hold…" : "No empire loaded."}</p>
      </AppShell>
    );
  }

  const busyId = state.planet.defence_building;
  const queued = state.planet.defences_queued ?? 0;
  const counts = defenceCountsOf(live);
  const units = defenceUnitCount(counts);
  const atk = planetAttack(counts);
  const def = planetDefence(counts);

  return (
    <AppShell title="Defences">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      <article className="mb-3 rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4">
        <h2 className="font-semibold">Hold strength</h2>
        <p className="mt-2 font-mono text-sm">
          Planet ATK {atk} · DEF {def} · {units} gun{units === 1 ? "" : "s"}
        </p>
        <p className="mt-1 text-xs text-[var(--muted-fg)]">
          NPC pirates ATK {PIRATE_ATTACK} · DEF {PIRATE_DEFENCE} each. More guns draw more hulls, 1–2 waves
          per hour.
        </p>
        {state.empire.next_pirate_at ? (
          <p className="mt-2 text-sm">
            Next pirate scan <Countdown until={state.empire.next_pirate_at} now={now} />
          </p>
        ) : (
          <p className="mt-2 text-sm text-[var(--muted-fg)]">Pirate scan not scheduled yet.</p>
        )}
      </article>
      <div className="flex flex-col gap-3">
        {DEFENCES.map((d) => {
          const owned = countOf(d.id, live);
          const thisBusy = busyId === d.id && queued > 0;
          const yardBusy = queued > 0 && Boolean(busyId);
          const count = d.unique ? 1 : Math.max(1, queues[d.id] ?? 1);
          const online = d.unique && owned >= 1;
          const badge = d.unique ? (online ? "Online" : "—") : `×${owned}`;
          return (
            <article key={d.id} className="rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <h2 className="font-semibold">{d.name}</h2>
                  <p className="mt-1 text-xs text-[var(--muted-fg)]">{d.blurb}</p>
                  <p className="mt-1 font-mono text-xs">
                    ATK {d.attack} · DEF {d.defence}
                    {owned > 1 ? ` · battery ATK ${d.attack * owned} DEF ${d.defence * owned}` : ""}
                  </p>
                </div>
                <span className="rounded-full bg-[var(--muted)] px-2 py-1 font-mono text-xs">{badge}</span>
              </div>
              {thisBusy ? (
                <TimedStripedProgress
                  className="mt-3"
                  until={state.planet.defence_completes_at}
                  durationMs={d.buildSeconds * 1000}
                  now={now}
                  label={d.name}
                />
              ) : (
                <StripedProgress className="mt-3" value={0} disabled animated={false} label={d.name} />
              )}
              <p className="mt-3 text-xs text-[var(--muted-fg)]">
                Next: {d.cost.ore.toLocaleString()} ore · {d.cost.crystal.toLocaleString()} crystal ·{" "}
                {formatDuration(d.buildSeconds)}
                {thisBusy ? ` · in yard ${queued}` : ""}
              </p>
              {thisBusy ? (
                <p className="mt-3 text-sm">
                  Building… <Countdown until={state.planet.defence_completes_at} now={now} />
                </p>
              ) : null}
              {d.unique ? null : (
                <label className="mt-3 block text-xs text-[var(--muted-fg)]">
                  Queue
                  <input
                    type="number"
                    min={1}
                    max={50}
                    value={count}
                    onChange={(e) =>
                      setQueues((prev) => ({ ...prev, [d.id]: Math.max(1, Number(e.target.value) || 1) }))
                    }
                    className="mt-1 h-11 w-full rounded-2xl border border-[var(--border)] bg-[var(--background)] px-3"
                  />
                </label>
              )}
              <button
                type="button"
                disabled={pending || online || (yardBusy && !thisBusy)}
                onClick={() => void buildDefence(d.id, d.unique ? 1 : count)}
                className="mt-3 h-11 w-full rounded-2xl bg-[var(--accent)] text-sm font-semibold text-[var(--accent-fg)] disabled:opacity-50"
              >
                {online ? "Online" : yardBusy && !thisBusy ? "Yard occupied" : d.unique ? "Raise dome" : "Build"}
              </button>
            </article>
          );
        })}
      </div>
    </AppShell>
  );
}
