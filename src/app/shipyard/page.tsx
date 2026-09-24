"use client";

import { AppShell } from "@/components/app-shell";
import { Countdown } from "@/components/countdown";
import { useEmpire } from "@/components/empire-provider";
import { SpriteThumb } from "@/components/sprite-thumb";
import { StripedProgress, TimedStripedProgress } from "@/components/striped-progress";
import { RAIDER_BUILD_SECONDS, SHIPS, researchSpec, unmetShipBuild, type ResearchId, type ShipStat } from "@/lib/game/catalog";
import type { EmpireRow } from "@/lib/game/types";
import { useState } from "react";

function levelOf(id: ResearchId, empire: EmpireRow): number {
  if (id === "combustion_drive") return empire.propulsion_level ?? 0;
  return empire[id] ?? 0;
}

function rapidFire(pairs: ShipStat["rapidFireAgainst"]): string {
  if (pairs.length === 0) return "—";
  return pairs.map(([name, factor]) => `${name} ×${factor.toLocaleString()}`).join(", ");
}

function ShipStats({
  ship,
  empire,
  shipyardLevel,
}: {
  ship: ShipStat;
  empire: EmpireRow;
  shipyardLevel: number;
}) {
  const speed =
    ship.speedUpgraded != null ? `${ship.speed.toLocaleString()} (${ship.speedUpgraded.toLocaleString()})` : ship.speed.toLocaleString();
  const fuel =
    ship.fuelUpgraded != null ? `${ship.fuel.toLocaleString()} (${ship.fuelUpgraded.toLocaleString()})` : ship.fuel.toLocaleString();
  const yardReady = shipyardLevel >= ship.shipyard;
  return (
    <div className="mt-2 space-y-1 text-xs text-[var(--muted-fg)]">
      <p>
        Cost {ship.cost.ore.toLocaleString()} ore · {ship.cost.crystal.toLocaleString()} crystal
        {ship.cost.deuterium > 0 ? ` · ${ship.cost.deuterium.toLocaleString()} deut` : ""}
      </p>
      <p>
        Hull {ship.hull.toLocaleString()} · Shield {ship.shield.toLocaleString()} · Attack {ship.attack.toLocaleString()}
      </p>
      <p>
        Cargo {ship.cargo.toLocaleString()} · Speed {speed} · Fuel {fuel}
      </p>
      <ul className="space-y-0.5">
        <li className={yardReady ? "text-emerald-300" : "text-amber-200"}>
          {yardReady ? "Ready" : "Needs"} Shipyard {ship.shipyard}
        </li>
        {ship.research.map((req) => {
          const met = levelOf(req.id, empire) >= req.level;
          const label = `${researchSpec(req.id).name} ${req.level}${req.upgrade ? " (drive upgrade)" : ""}`;
          return (
            <li key={`${req.id}-${req.level}`} className={met ? "text-emerald-300" : "text-amber-200"}>
              {met ? "Ready" : "Needs"} {label}
            </li>
          );
        })}
      </ul>
      <p>Rapid fire: {rapidFire(ship.rapidFireAgainst)}</p>
      <p>Shot by: {rapidFire(ship.rapidFireFrom)}</p>
      {ship.note ? <p>{ship.note}</p> : null}
    </div>
  );
}

export default function ShipyardPage() {
  const { state, pending, error, build, now } = useEmpire();
  const [count, setCount] = useState(1);

  if (!state) {
    return (
      <AppShell title="Shipyard">
        <p className="text-sm text-[var(--muted-fg)]">No empire loaded.</p>
      </AppShell>
    );
  }

  const cargo = SHIPS.find((ship) => ship.id === "small_cargo")!;
  const cargoMissing = unmetShipBuild(cargo, state.planet.shipyard ?? 0, (id) => levelOf(id, state.empire));
  const cargoReady = cargoMissing.length === 0;

  return (
    <AppShell title="Shipyard">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      <div className="flex flex-col gap-3">
        {SHIPS.map((ship) =>
          ship.buildable ? (
            <article key={ship.id} className="sci-card p-4">
              <div className="flex items-start gap-3">
                <SpriteThumb id={ship.id} />
                <div className="min-w-0 flex-1">
                  <h2 className="font-semibold">{ship.name}</h2>
                  <p className="mt-1 text-xs text-[var(--muted-fg)]">
                    Docked: {state.empire.raiders}. In yard: {state.empire.raiders_queued}.
                  </p>
                  <ShipStats ship={ship} empire={state.empire} shipyardLevel={state.planet.shipyard ?? 0} />
                </div>
              </div>
              {state.empire.raiders_queued > 0 ? (
                <TimedStripedProgress
                  className="mt-3"
                  until={state.empire.raider_completes_at}
                  durationMs={RAIDER_BUILD_SECONDS * 1000}
                  now={now}
                  tone="var(--ore)"
                  label="Small cargo"
                />
              ) : (
                <StripedProgress className="mt-3" value={0} tone="var(--ore)" animated={false} disabled label="Small cargo" />
              )}
              {state.empire.raiders_queued > 0 ? (
                <p className="mt-3 text-sm">
                  Next hull <Countdown until={state.empire.raider_completes_at} now={now} />
                </p>
              ) : null}
              <label className="mt-3 block text-xs text-[var(--muted-fg)]">
                Queue
                <input
                  type="number"
                  min={1}
                  max={20}
                  value={count}
                  onChange={(e) => setCount(Number(e.target.value))}
                  className="sci-input mt-1 h-11 w-full px-3"
                />
              </label>
              <button
                type="button"
                disabled={pending || !cargoReady}
                onClick={() => void build(count)}
                className="sci-btn mt-3 h-11 w-full"
              >
                {cargoReady ? "Build" : cargoMissing[0]?.name === "Shipyard" ? "Shipyard locked" : "Research locked"}
              </button>
            </article>
          ) : (
            <article key={ship.id} className="sci-card p-4">
              <div className="flex items-start gap-3">
                <SpriteThumb id={ship.id} />
                <div className="min-w-0 flex-1">
                  <h2 className="font-semibold">{ship.name}</h2>
                  <ShipStats ship={ship} empire={state.empire} shipyardLevel={state.planet.shipyard ?? 0} />
                </div>
              </div>
              <button type="button" disabled className="sci-btn mt-3 h-11 w-full">
                Build
              </button>
            </article>
          ),
        )}
      </div>
    </AppShell>
  );
}
