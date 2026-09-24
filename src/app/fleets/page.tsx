"use client";

import { AppShell } from "@/components/app-shell";
import { FleetEventStrip } from "@/components/fleet-event";
import { useEmpire } from "@/components/empire-provider";
import {
  expeditionFlightSeconds,
  EXPEDITION_HOLD_SECONDS,
  flightSeconds,
  isInboundFleet,
  PIRATE_FLIGHT_SECONDS,
} from "@/lib/game/catalog";
import type { FleetRow, PlanetRow } from "@/lib/game/types";

function durationMs(fleet: FleetRow, planet: PlanetRow, propulsion: number, inbound: boolean): number {
  if (inbound) return PIRATE_FLIGHT_SECONDS * 1000;
  if (fleet.created_at) {
    const start = new Date(fleet.created_at).getTime();
    const end = new Date(fleet.arrives_at).getTime();
    if (Number.isFinite(start) && end > start) return end - start;
  }
  if (fleet.mission === "expedition_hold") return EXPEDITION_HOLD_SECONDS * 1000;
  if (fleet.dest_system == null || fleet.dest_slot == null) return PIRATE_FLIGHT_SECONDS * 1000;
  const fn = fleet.mission === "expedition" || fleet.mission === "expedition_return" ? expeditionFlightSeconds : flightSeconds;
  return (
    fn(
      planet.system,
      planet.slot,
      fleet.dest_system,
      fleet.dest_slot,
      propulsion,
      planet.galaxy,
      fleet.dest_galaxy ?? planet.galaxy,
    ) * 1000
  );
}

export default function FleetsPage() {
  const { state, error, now, pending, recallFleet } = useEmpire();
  const incoming = state
    ? state.fleets.filter((fleet) => isInboundFleet(fleet, state.empire.user_id, state.planet.id))
    : [];
  const outbound = state
    ? state.fleets.filter((fleet) => !isInboundFleet(fleet, state.empire.user_id, state.planet.id))
    : [];

  return (
    <AppShell title="Fleet">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      {!state ? (
        <p className="text-sm text-[var(--muted-fg)]">No empire loaded.</p>
      ) : (
        <>
          <h2 className="font-[family-name:var(--font-display)] text-xs font-semibold tracking-wide text-red-300 uppercase">
            Incoming
          </h2>
          {incoming.length === 0 ? (
            <p className="mt-2 text-sm text-[var(--muted-fg)]">No inbound strikes.</p>
          ) : (
            <ul className="mt-2 flex flex-col gap-2">
              {incoming.map((fleet) => (
                <FleetEventStrip
                  key={fleet.id}
                  fleet={fleet}
                  now={now}
                  durationMs={durationMs(fleet, state.planet, state.empire.propulsion_level, true)}
                  originName={fleet.attacker_name || "Pirates"}
                  destName={state.planet.name}
                  inbound
                />
              ))}
            </ul>
          )}

          <h2 className="mt-6 font-[family-name:var(--font-display)] text-xs font-semibold tracking-wide text-cyan-300 uppercase">
            Fleets
          </h2>
          {outbound.length === 0 ? (
            <p className="mt-2 text-sm text-[var(--muted-fg)]">No hulls away from dock.</p>
          ) : (
            <ul className="mt-2 flex flex-col gap-2">
              {outbound.map((fleet) => {
                const canReturn = fleet.mission === "attack" || fleet.mission === "expedition";
                return (
                  <FleetEventStrip
                    key={fleet.id}
                    fleet={fleet}
                    now={now}
                    durationMs={durationMs(fleet, state.planet, state.empire.propulsion_level, false)}
                    originName={fleet.origin_name || state.planet.name}
                    destName={fleet.dest_name || "Unknown"}
                    canReturn={canReturn}
                    pending={pending}
                    onReturn={() => void recallFleet(fleet.id)}
                  />
                );
              })}
            </ul>
          )}
        </>
      )}
    </AppShell>
  );
}
