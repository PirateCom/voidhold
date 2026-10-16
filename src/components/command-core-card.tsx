"use client";

import { useCallback, useEffect, useState } from "react";
import { Countdown } from "@/components/countdown";
import { useEmpire } from "@/components/empire-provider";
import { loadMechanicsState, togglePlanetRelic } from "@/lib/game/actions";
import {
  MAX_PLANET_RELICS,
  RELICS,
  stellarEventSpec,
  type EmpireMechanicsState,
  type RelicId,
} from "@/lib/game/mechanics";

export function CommandCoreCard() {
  const { state, configured, now, refresh } = useEmpire();
  const [mechanics, setMechanics] = useState<EmpireMechanicsState | null>(null);
  const [busyRelic, setBusyRelic] = useState<RelicId | null>(null);
  const [err, setErr] = useState<string | null>(null);

  const reload = useCallback(async () => {
    const next = await loadMechanicsState();
    setMechanics(next);
  }, []);

  useEffect(() => {
    if (!configured || !state) return;
    void reload();
  }, [configured, state?.planet.id, state?.server_now, reload]);

  if (!state || !mechanics) return null;

  const planetId = state.planet.id;
  const equipped = mechanics.planet_relics[String(planetId)] ?? [];
  const systemEvent = mechanics.stellar_events.find(
    (ev) => ev.galaxy === state.planet.galaxy && ev.system === state.planet.system,
  );
  const eventSpec = stellarEventSpec(systemEvent?.kind);

  const usedAcrossEmpire = (id: RelicId) =>
    Object.values(mechanics.planet_relics).reduce(
      (sum, list) => sum + (list.includes(id) ? 1 : 0),
      0,
    );

  async function onToggle(id: RelicId) {
    setBusyRelic(id);
    setErr(null);
    try {
      const next = await togglePlanetRelic(planetId, id);
      setMechanics(next);
      await refresh();
    } catch (e) {
      setErr(e instanceof Error ? e.message : "Could not update Command Core.");
    } finally {
      setBusyRelic(null);
    }
  }

  return (
    <div className="mb-3 flex flex-col gap-3">
      {systemEvent && eventSpec ? (
        <article className="sci-card sci-card-fleet-amber p-3.5">
          <div className="flex items-start justify-between gap-2">
            <div>
              <p className="text-[10px] font-semibold tracking-wider text-amber-300 uppercase">
                Active Stellar Event · [{systemEvent.galaxy}:{systemEvent.system}]
              </p>
              <h2 className="mt-0.5 font-[family-name:var(--font-display)] text-sm font-bold text-amber-100 uppercase">
                {eventSpec.name}
              </h2>
            </div>
            <span className="sci-badge shrink-0">{eventSpec.badge}</span>
          </div>
          <p className="mt-1.5 text-xs text-[var(--muted-fg)]">{eventSpec.blurb}</p>
          <p className="mt-2 font-mono text-xs text-amber-200">
            Ends in <Countdown until={systemEvent.ends_at} now={now} />
          </p>
        </article>
      ) : null}

      <article className="sci-card p-4">
        <div className="flex items-center justify-between gap-2">
          <div>
            <p className="text-[10px] uppercase tracking-[0.2em] text-cyan-300">Command Core</p>
            <h2 className="font-semibold">
              Ancient Relics · {state.planet.name} ({equipped.length}/{MAX_PLANET_RELICS} slots)
            </h2>
          </div>
          <span className="sci-badge">
            {equipped.length}/{MAX_PLANET_RELICS} ACTIVE
          </span>
        </div>
        <p className="mt-1 text-xs text-[var(--muted-fg)]">
          Recover relics from Expeditions (slot 16), Pirate Strongholds, and raids. Socket up to{" "}
          {MAX_PLANET_RELICS} modules on this planet.
        </p>
        {err ? <p className="mt-2 text-xs text-red-300">{err}</p> : null}
        <div className="mt-3 grid grid-cols-1 gap-2 sm:grid-cols-2">
          {RELICS.map((relic) => {
            const isSocketed = equipped.includes(relic.id);
            const totalOwned = mechanics.relic_inventory[relic.id] ?? 0;
            const inUse = usedAcrossEmpire(relic.id);
            const spare = Math.max(0, totalOwned - inUse);
            const canSocket = isSocketed || (spare > 0 && equipped.length < MAX_PLANET_RELICS);
            return (
              <div
                key={relic.id}
                className={`flex flex-col justify-between rounded border p-2.5 ${
                  isSocketed
                    ? "border-cyan-400/60 bg-cyan-950/35"
                    : "border-slate-800 bg-slate-950/60"
                }`}
              >
                <div>
                  <div className="flex items-start justify-between gap-2">
                    <p className="text-xs font-semibold text-slate-100">{relic.name}</p>
                    <span className="font-mono text-[10px] text-cyan-300">
                      {spare} free / {totalOwned} owned
                    </span>
                  </div>
                  <p className="mt-0.5 font-mono text-[10px] text-amber-300">{relic.badge}</p>
                  <p className="mt-1 text-[11px] leading-snug text-[var(--muted-fg)]">{relic.blurb}</p>
                </div>
                <button
                  type="button"
                  disabled={busyRelic === relic.id || !canSocket}
                  onClick={() => void onToggle(relic.id)}
                  className={`sci-btn mt-2.5 h-9 w-full ${isSocketed ? "sci-btn-warn" : "sci-btn-muted"}`}
                >
                  {busyRelic === relic.id
                    ? "Working…"
                    : isSocketed
                      ? "Unsocket module"
                      : totalOwned === 0
                        ? "Not discovered"
                        : spare === 0
                          ? "In use on colony"
                          : equipped.length >= MAX_PLANET_RELICS
                            ? "Core slots full"
                            : "Socket module"}
                </button>
              </div>
            );
          })}
        </div>
      </article>
    </div>
  );
}
