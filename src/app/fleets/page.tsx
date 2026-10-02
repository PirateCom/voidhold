"use client";

import { AppShell } from "@/components/app-shell";
import { FleetEventStrip } from "@/components/fleet-event";
import { useEmpire } from "@/components/empire-provider";
import { useGhostFleetEnabled } from "@/components/ghost-fleet-toggle";
import {
  expeditionFlightSeconds,
  EXPEDITION_HOLD_SECONDS,
  flightSeconds,
  isInboundFleet,
  PIRATE_FLIGHT_SECONDS,
} from "@/lib/game/catalog";
import type { FleetRow, PlanetRow } from "@/lib/game/types";

function durationMs(fleet: FleetRow, planet: PlanetRow, propulsion: number, inbound: boolean): number {
  if (fleet.created_at && (!inbound || fleet.mission === "transport")) {
    const start = new Date(fleet.created_at).getTime();
    const end = new Date(fleet.arrives_at).getTime();
    if (Number.isFinite(start) && end > start) return end - start;
  }
  if (inbound) return PIRATE_FLIGHT_SECONDS * 1000;
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

const GHOST_ELAPSED_MS = 60_000;
const GHOST_REMAINING_MS = 3_600_000;

function ghostFleet(planet: PlanetRow, ownerId: string, now: number): FleetRow {
  return {
    id: -1,
    owner_id: ownerId,
    origin_planet_id: planet.id,
    dest_planet_id: null,
    dest_name: "Ghost target",
    dest_galaxy: planet.galaxy,
    dest_system: planet.system,
    dest_slot: planet.slot === 15 ? 1 : planet.slot + 1,
    origin_name: planet.name,
    origin_galaxy: planet.galaxy,
    origin_system: planet.system,
    origin_slot: planet.slot,
    created_at: new Date(now - GHOST_ELAPSED_MS).toISOString(),
    arrives_at: new Date(now + GHOST_REMAINING_MS).toISOString(),
    raiders: 42,
    ship_count: 42,
    composition: { light_fighter: 20, cruiser: 12, battleship: 6, small_cargo: 4 },
    mission: "attack",
    cargo_ore: 12_000,
    cargo_crystal: 8_000,
    cargo_deuterium: 3_000,
    status: "en_route",
    report: null,
  };
}

export default function FleetsPage() {
  const { state, error, now, pending, recallFleet, isDebug } = useEmpire();
  const ghostEnabled = useGhostFleetEnabled();
  const ghost = isDebug && ghostEnabled && state ? ghostFleet(state.planet, state.empire.user_id, now) : null;
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
          <h2 className="font-[family-name:var(--font-display)] text-sm font-bold tracking-wider text-cyan-300 uppercase">
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
                  destName={fleet.dest_name || state.planet.name}
                  inbound
                />
              ))}
            </ul>
          )}

          <div className="mt-6 flex items-center justify-between">
            <h2 className="font-[family-name:var(--font-display)] text-sm font-bold tracking-wider text-cyan-300 uppercase">
              Active fleets
            </h2>
            <span className="font-mono text-xs font-semibold text-cyan-400">
              FLEETS: {outbound.length}
            </span>
          </div>
          {ghost ? (
            <div className="mt-2">
              <p className="mb-1 text-xs font-semibold tracking-wide text-[#fde68a] uppercase">
                Debug: ghost fleet (never arrives)
              </p>
              <ul className="flex flex-col gap-2 opacity-80">
                <FleetEventStrip
                  fleet={ghost}
                  now={now}
                  durationMs={GHOST_ELAPSED_MS + GHOST_REMAINING_MS}
                  originName={ghost.origin_name ?? state.planet.name}
                  destName={ghost.dest_name ?? "Unknown"}
                  canReturn
                  pending
                  onReturn={() => {}}
                />
              </ul>
            </div>
          ) : null}
          {outbound.length === 0 ? (
            <p className="mt-2 text-sm text-[var(--muted-fg)]">No hulls away from dock.</p>
          ) : (
            <ul className="mt-2 flex flex-col gap-2">
              {outbound.map((fleet) => {
                const canReturn =
                  fleet.mission === "attack" ||
                  fleet.mission === "expedition" ||
                  fleet.mission === "espionage" ||
                  fleet.mission === "harvest" ||
                  fleet.mission === "colonize";
                return (
                  <FleetEventStrip
                    key={fleet.id}
                    fleet={fleet}
                    now={now}
                    durationMs={durationMs(fleet, state.planet, state.empire.propulsion_level, false)}
                    originName={fleet.origin_name || state.planet.name}
                    destName={fleet.dest_name || (fleet.mission.startsWith("expedition") ? "Empty slot" : "Unknown")}
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
