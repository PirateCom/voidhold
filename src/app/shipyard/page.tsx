"use client";

import { AppShell } from "@/components/app-shell";
import { Countdown } from "@/components/countdown";
import { useEmpire } from "@/components/empire-provider";
import { SpriteThumb } from "@/components/sprite-thumb";
import { StripedProgress, TimedStripedProgress } from "@/components/striped-progress";
import { RAIDER_BUILD_SECONDS, SHIPS, canPayResources, researchSpec, solarSatelliteEnergy, unmetShipBuild, type ResearchId, type ShipStat } from "@/lib/game/catalog";
import type { EmpireRow } from "@/lib/game/types";
import { useState } from "react";

function levelOf(id: ResearchId, empire: EmpireRow): number {
  if (id === "combustion_drive") return empire.propulsion_level ?? 0;
  return empire[id] ?? 0;
}

function dockedCount(shipId: string, empire: EmpireRow): number {
  if (shipId === "small_cargo") return empire.raiders;
  return empire.ships?.[shipId] ?? 0;
}

function rapidFire(pairs: ShipStat["rapidFireAgainst"]): string {
  if (pairs.length === 0) return "—";
  return pairs.map(([name, factor]) => `${name} ×${factor.toLocaleString()}`).join(", ");
}

function ShipStats({
  ship,
  empire,
  shipyardLevel,
  satEnergy,
}: {
  ship: ShipStat;
  empire: EmpireRow;
  shipyardLevel: number;
  satEnergy?: { each: number; docked: number; count: number };
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
      {satEnergy ? (
        <p className="text-emerald-300">
          Energy {satEnergy.each.toLocaleString()} each
          {satEnergy.count > 0
            ? ` · ${satEnergy.docked.toLocaleString()} from ${satEnergy.count.toLocaleString()} in orbit`
            : ""}
        </p>
      ) : null}
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
  const { state, live, pending, error, buildShip, now } = useEmpire();
  const [queues, setQueues] = useState<Record<string, number>>({});

  if (!state) {
    return (
      <AppShell title="Shipyard">
        <p className="text-sm text-[var(--muted-fg)]">No empire loaded.</p>
      </AppShell>
    );
  }

  const busyId = state.empire.ship_building || (state.empire.raiders_queued > 0 ? "small_cargo" : null);
  const queued = state.empire.raiders_queued ?? 0;
  const yardBusy = queued > 0 && Boolean(busyId);

  return (
    <AppShell title="Shipyard">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      <div className="flex flex-col gap-3">
        {SHIPS.map((ship) => {
          const missing = unmetShipBuild(ship, state.planet.shipyard ?? 0, (id) => levelOf(id, state.empire));
          const ready = missing.length === 0;
          const thisBusy = busyId === ship.id && queued > 0;
          const count = Math.max(1, queues[ship.id] ?? 1);
          const poor = live ? !canPayResources(live, ship.cost, count) : true;
          const lockLabel = missing[0]?.name === "Shipyard" ? "Shipyard locked" : "Research locked";
          return (
            <article key={ship.id} className="sci-card p-4">
              <div className="flex items-start gap-3">
                <SpriteThumb id={ship.id} />
                <div className="min-w-0 flex-1">
                  <h2 className="font-semibold">{ship.name}</h2>
                  <p className="mt-1 text-xs text-[var(--muted-fg)]">
                    Docked: {dockedCount(ship.id, state.empire)}.
                    {thisBusy ? ` In yard: ${queued}.` : ""}
                  </p>
                  <ShipStats
                    ship={ship}
                    empire={state.empire}
                    shipyardLevel={state.planet.shipyard ?? 0}
                    satEnergy={
                      ship.id === "solar_satellite"
                        ? {
                            each: solarSatelliteEnergy(
                              state.planet.temp_min,
                              state.planet.temp_max,
                              state.star?.type,
                              1,
                            ),
                            docked: solarSatelliteEnergy(
                              state.planet.temp_min,
                              state.planet.temp_max,
                              state.star?.type,
                              dockedCount("solar_satellite", state.empire),
                            ),
                            count: dockedCount("solar_satellite", state.empire),
                          }
                        : undefined
                    }
                  />
                </div>
              </div>
              {thisBusy ? (
                <TimedStripedProgress
                  className="mt-3"
                  until={state.empire.raider_completes_at}
                  durationMs={RAIDER_BUILD_SECONDS * 1000}
                  now={now}
                  tone="var(--ore)"
                  label={ship.name}
                />
              ) : (
                <StripedProgress className="mt-3" value={0} tone="var(--ore)" animated={false} disabled label={ship.name} />
              )}
              {thisBusy ? (
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
                  onChange={(e) => setQueues((prev) => ({ ...prev, [ship.id]: Math.max(1, Number(e.target.value) || 1) }))}
                  className="sci-input mt-1 h-11 w-full px-3"
                />
              </label>
              <button
                type="button"
                disabled={pending || !ready || poor || (yardBusy && !thisBusy)}
                onClick={() => void buildShip(ship.id, count)}
                className="sci-btn mt-3 h-11 w-full"
              >
                {!ready ? lockLabel : yardBusy && !thisBusy ? "Yard occupied" : poor ? "Need resources" : "Build"}
              </button>
            </article>
          );
        })}
      </div>
    </AppShell>
  );
}
