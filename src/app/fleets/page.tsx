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

function fleetDestName(fleet: FleetRow, fallback: string): string {
  if (fleet.mission === "harvest" || fleet.mission === "harvest_return") return "Debris field";
  if (fleet.mission === "mine" || fleet.mission === "mine_hold" || fleet.mission === "mine_return") {
    return "Asteroid belt";
  }
  if (fleet.mission.startsWith("expedition")) return fleet.dest_name || "Empty slot";
  return fleet.dest_name || fallback;
}

function isReturnMission(mission: FleetRow["mission"]) {
  return (
    mission === "return" ||
    mission === "espionage_return" ||
    mission === "harvest_return" ||
    mission === "colonize_return" ||
    mission === "expedition_return" ||
    mission === "transport_return" ||
    mission === "mine_return"
  );
}

function oneWayMs(fleet: FleetRow, planet: PlanetRow, propulsion: number): number {
  if (fleet.dest_system == null || fleet.dest_slot == null) return PIRATE_FLIGHT_SECONDS * 1000;
  const originGalaxy = fleet.origin_galaxy ?? planet.galaxy;
  const originSystem = fleet.origin_system ?? planet.system;
  const originSlot = fleet.origin_slot ?? planet.slot;
  const fn =
    fleet.mission === "expedition" || fleet.mission === "expedition_return"
      ? expeditionFlightSeconds
      : flightSeconds;
  return (
    fn(
      originSystem,
      originSlot,
      fleet.dest_system,
      fleet.dest_slot,
      propulsion,
      originGalaxy,
      fleet.dest_galaxy ?? originGalaxy,
    ) * 1000
  );
}

function durationMs(fleet: FleetRow, planet: PlanetRow, propulsion: number, inbound: boolean): number {
  const created = fleet.created_at ? new Date(fleet.created_at).getTime() : NaN;
  const arrives = new Date(fleet.arrives_at).getTime();
  const fromCreated = Number.isFinite(created) && arrives > created ? arrives - created : 0;

  if (isReturnMission(fleet.mission) && !inbound) {
    const oneWay = oneWayMs(fleet, planet, propulsion);
    // Belt spy/mine keep created_at from the outbound launch, so arrives−created is the round trip.
    if (fromCreated > oneWay * 1.25 && fromCreated <= oneWay * 2.5) return Math.round(fromCreated / 2);
    if (fromCreated > 0 && fromCreated <= oneWay * 1.25) return fromCreated;
    return oneWay;
  }

  if (
    fromCreated > 0 &&
    (!inbound || fleet.mission === "transport" || fleet.mission === "deploy" || fleet.mission === "missile")
  ) {
    return fromCreated;
  }
  if (inbound) return PIRATE_FLIGHT_SECONDS * 1000;
  if (fleet.mission === "expedition_hold") return EXPEDITION_HOLD_SECONDS * 1000;
  if (fleet.mission === "mine_hold") return fromCreated > 0 ? fromCreated : oneWayMs(fleet, planet, propulsion);
  return oneWayMs(fleet, planet, propulsion);
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
                  originName={fleet.attacker_name || fleet.origin_name || "Pirates"}
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
              FLEETS: {outbound.filter((fleet) => fleet.mission !== "missile").length}
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
                  fleet.mission === "colonize" ||
                  fleet.mission === "deploy" ||
                  fleet.mission === "mine" ||
                  fleet.mission === "mine_hold";
                return (
                  <FleetEventStrip
                    key={fleet.id}
                    fleet={fleet}
                    now={now}
                    durationMs={durationMs(fleet, state.planet, state.empire.propulsion_level, false)}
                  originName={fleet.origin_name || state.planet.name}
                    destName={fleetDestName(fleet, "Unknown")}
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
