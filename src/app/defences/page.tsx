"use client";

import { useState } from "react";
import { AppShell } from "@/components/app-shell";
import { Countdown } from "@/components/countdown";
import { useEmpire } from "@/components/empire-provider";
import { SpriteThumb } from "@/components/sprite-thumb";
import { StripedProgress, TimedStripedProgress } from "@/components/striped-progress";
import {
  DEFENCE_GROUPS,
  DEFENCES,
  PIRATE_ATTACK,
  PIRATE_DEFENCE,
  canPayResources,
  defenceUnitCount,
  formatDuration,
  planetAttack,
  planetDefence,
  researchSpec,
  unmetDefenceBuild,
  type DefenceId,
  type ResearchId,
} from "@/lib/game/catalog";
import { defenceCountsOf, defenceOwned, type SimPlanet } from "@/lib/game/simulate";
import type { EmpireRow } from "@/lib/game/types";

function countOf(id: DefenceId, planet: SimPlanet): number {
  return defenceOwned(planet, id);
}

function levelOf(id: ResearchId, empire: EmpireRow): number {
  if (id === "combustion_drive") return empire.propulsion_level ?? 0;
  return empire[id] ?? 0;
}

export default function DefencesPage() {
  const { error, state, live, pending, buildDefence, now } = useEmpire();
  const [queues, setQueues] = useState<Partial<Record<DefenceId, number>>>({});

  if (!state || !live) {
    return (
      <AppShell title="Defence">
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
    <AppShell title="Defence">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      <article className="sci-card mb-3 p-4">
        <h2 className="font-semibold">Hold strength</h2>
        <p className="mt-2 font-mono text-sm">
          Planet ATK {atk} · DEF {def} · {units} gun{units === 1 ? "" : "s"}
        </p>
        <p className="mt-1 text-xs text-[var(--muted-fg)]">
          NPC pirates ATK {PIRATE_ATTACK} · DEF {PIRATE_DEFENCE} each. More guns draw more hulls, 1–2 waves
          per hour.
        </p>
        {state.empire.pirate_raids_enabled === false ? (
          <p className="mt-2 text-sm text-[var(--muted-fg)]">Pirate raids off.</p>
        ) : state.empire.next_pirate_at ? (
          <p className="mt-2 text-sm">
            Next pirate scan <Countdown until={state.empire.next_pirate_at} now={now} />
          </p>
        ) : (
          <p className="mt-2 text-sm text-[var(--muted-fg)]">Pirate scan not scheduled yet.</p>
        )}
      </article>
      <div className="flex flex-col gap-3">
        {DEFENCE_GROUPS.map((group) => (
          <section key={group.id} className="flex flex-col gap-3">
            <h2 className="px-1 pt-2 text-xs font-semibold tracking-wide text-[var(--muted-fg)] uppercase">
              {group.title}
            </h2>
            {DEFENCES.filter((d) => d.group === group.id).map((d) => {
          const owned = countOf(d.id, live);
          const thisBusy = busyId === d.id && queued > 0;
          const yardBusy = queued > 0 && Boolean(busyId);
          const count = d.unique ? 1 : Math.max(1, queues[d.id] ?? 1);
          const online = d.unique && owned >= 1;
          const badge = d.unique ? (online ? "Online" : "—") : `×${owned}`;
          const poor = !canPayResources(live, d.cost, count);
          const missing = unmetDefenceBuild(
            d,
            state.planet.shipyard ?? 0,
            state.planet.missile_silo ?? 0,
            (id) => levelOf(id, state.empire),
          );
          const yardReady = (state.planet.shipyard ?? 0) >= d.shipyard;
          const siloReady = d.silo === 0 || (state.planet.missile_silo ?? 0) >= d.silo;
          const lockLabel =
            missing[0]?.name === "Shipyard"
              ? "Shipyard locked"
              : missing[0]?.name === "Missile silo"
                ? "Silo locked"
                : "Research locked";
          return (
            <article key={d.id} className="sci-card p-4">
              <div className="flex items-start gap-3">
                <SpriteThumb id={d.id} />
                <div className="min-w-0 flex-1">
                  <div className="flex items-start justify-between gap-3">
                    <h2 className="font-semibold">{d.name}</h2>
                    <span className="sci-badge">{badge}</span>
                  </div>
                  <p className="mt-1 text-xs text-[var(--muted-fg)]">{d.blurb}</p>
                  <p className="mt-1 font-mono text-xs">
                    ATK {d.attack} · DEF {d.defence}
                    {owned > 1 ? ` · battery ATK ${d.attack * owned} DEF ${d.defence * owned}` : ""}
                  </p>
                </div>
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
              <ul className="mt-1 space-y-0.5 text-xs">
                <li className={yardReady ? "text-emerald-300" : "text-amber-200"}>
                  {yardReady ? "Ready" : "Needs"} Shipyard {d.shipyard}
                </li>
                {d.silo > 0 ? (
                  <li className={siloReady ? "text-emerald-300" : "text-amber-200"}>
                    {siloReady ? "Ready" : "Needs"} Missile silo {d.silo}
                  </li>
                ) : null}
                {d.research.map((req) => {
                  const met = levelOf(req.id, state.empire) >= req.level;
                  return (
                    <li key={`${req.id}-${req.level}`} className={met ? "text-emerald-300" : "text-amber-200"}>
                      {met ? "Ready" : "Needs"} {researchSpec(req.id).name} {req.level}
                    </li>
                  );
                })}
              </ul>
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
                    className="sci-input mt-1 h-11 w-full px-3"
                  />
                </label>
              )}
              <button
                type="button"
                disabled={pending || online || missing.length > 0 || poor || (yardBusy && !thisBusy)}
                onClick={() => void buildDefence(d.id, d.unique ? 1 : count)}
                className="sci-btn mt-3 h-11 w-full"
              >
                {online
                  ? "Online"
                  : missing.length > 0
                    ? lockLabel
                    : yardBusy && !thisBusy
                      ? "Yard occupied"
                      : poor
                        ? "Need resources"
                        : d.group === "dome"
                          ? "Raise dome"
                          : d.group === "missile"
                            ? "Load"
                            : "Build"}
              </button>
            </article>
          );
        })}
          </section>
        ))}
      </div>
    </AppShell>
  );
}
