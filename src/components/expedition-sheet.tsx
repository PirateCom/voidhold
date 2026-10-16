"use client";

import { useMemo, useState } from "react";
import { SpriteThumb } from "@/components/sprite-thumb";
import { useEmpire } from "@/components/empire-provider";
import { SheetPortal } from "@/components/sheet-portal";
import {
  EXPEDITION_HOLD_SECONDS,
  EXPEDITION_SLOT,
  SHIPS,
  expeditionFleetCap,
  expeditionFlightSeconds,
  fleetFuelRoundTrip,
} from "@/lib/game/catalog";

export function ExpeditionSheet({
  open,
  galaxy,
  system,
  slot = EXPEDITION_SLOT,
  onClose,
}: {
  open: boolean;
  galaxy: number;
  system: number;
  slot?: number;
  onClose: () => void;
}) {
  const { state, pending, sendExpedition, now } = useEmpire();
  const [counts, setCounts] = useState<Record<string, number>>({ small_cargo: 1 });

  const flyable = useMemo(() => SHIPS.filter((ship) => ship.speed > 0), []);
  if (!open || !state) return null;

  const astro = state.empire.astrophysics ?? 0;
  const cap = expeditionFleetCap(astro);
  const active = state.fleets.filter((fleet) =>
    fleet.mission === "expedition" ||
    fleet.mission === "expedition_hold" ||
    fleet.mission === "expedition_return",
  ).length;
  const docked: Record<string, number> = {
    ...(state.empire.ships ?? {}),
    small_cargo: state.empire.raiders,
  };
  const selectedShips = Object.fromEntries(
    Object.entries(counts)
      .map(([id, n]) => [id, Math.max(0, Math.floor(n || 0))])
      .filter(([, n]) => Number(n) > 0),
  ) as Record<string, number>;
  const totalSelected = Object.values(selectedShips).reduce((sum, n) => sum + n, 0);
  const hasPathfinder = (selectedShips.pathfinder ?? 0) > 0;
  const overDocked = Object.entries(selectedShips).some(([id, n]) => n > (docked[id] ?? 0));
  const flight = expeditionFlightSeconds(
    state.planet.system,
    state.planet.slot,
    system,
    slot,
    state.empire.propulsion_level,
    state.planet.galaxy,
    galaxy,
    state.empire.impulse_drive ?? 0,
    state.empire.hyperspace_drive ?? 0,
  );
  const fuel = Object.entries(selectedShips).reduce(
    (sum, [id, n]) =>
      sum +
      fleetFuelRoundTrip(
        n,
        state.planet.galaxy,
        state.planet.system,
        state.planet.slot,
        galaxy,
        system,
        slot,
        id,
        state.empire.impulse_drive ?? 0,
      ),
    0,
  );
  const blocked =
    astro < 1
      ? "Needs Astronomy 1."
      : active >= cap
        ? "No free expedition slots."
        : totalSelected < 1
          ? "Select at least one ship."
          : overDocked
            ? "Not enough docked ships."
            : Number(state.planet.deuterium) < fuel
              ? "Not enough deuterium for fuel."
              : null;

  return (
    <SheetPortal>
      <div className="sci-card max-h-full w-full max-w-md overflow-y-auto p-4">
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 className="font-semibold">Expedition</h2>
            <p className="mt-1 text-xs text-[var(--muted-fg)]">
              [{galaxy}:{system}:{slot}] {slot === EXPEDITION_SLOT ? "Outer space" : "Empty slot"} · hold {EXPEDITION_HOLD_SECONDS}s · slots {active}/{cap}
            </p>
          </div>
          <button type="button" className="sci-btn sci-btn-quiet h-11 px-3" onClick={onClose}>
            Close
          </button>
        </div>
        <p className="mt-3 text-xs text-[var(--muted-fg)]">
          Expeditions need Astronomy 1. Any flyable docked hull can launch. Including a{" "}
          <span className="text-cyan-300">Pathfinder</span> doubles (×2) expedition resource finds and boosts Ancient
          Relic discovery.
        </p>
        {hasPathfinder ? (
          <p className="mt-2 rounded border border-cyan-400/50 bg-cyan-950/40 px-2.5 py-1.5 font-mono text-xs text-cyan-200">
            Pathfinder scanner active · ×2 expedition loot & relic discovery bonus
          </p>
        ) : null}
        <ul className="mt-3 flex flex-col gap-2">
          {flyable.map((ship) => {
            const have = docked[ship.id] ?? 0;
            const locked = have < 1;
            return (
              <li key={ship.id} className="flex items-center gap-3 rounded-xl border border-[var(--border)] px-3 py-2">
                <SpriteThumb id={ship.id} />
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold">{ship.name}</p>
                  <p className="text-xs text-[var(--muted-fg)]">
                    Docked {have}
                    {ship.id === "pathfinder" ? " · ×2 expedition bonus" : ""}
                  </p>
                </div>
                <input
                  type="number"
                  min={0}
                  max={Math.max(have, 0)}
                  disabled={locked || pending}
                  value={counts[ship.id] ?? 0}
                  onChange={(e) =>
                    setCounts((prev) => ({ ...prev, [ship.id]: Math.max(0, Number(e.target.value) || 0) }))
                  }
                  className="sci-input h-11 w-20 px-2 text-center"
                />
              </li>
            );
          })}
        </ul>
        <p className="mt-3 text-xs text-[var(--muted-fg)]">
          Flight ~{flight}s each way · fuel {fuel.toLocaleString()} deut round trip · now {new Date(now).toLocaleTimeString()}
        </p>
        {blocked ? <p className="mt-2 text-sm text-amber-200">{blocked}</p> : null}
        <button
          type="button"
          disabled={pending || Boolean(blocked)}
          className="sci-btn mt-3 h-11 w-full"
          onClick={() => {
            void sendExpedition(galaxy, system, slot, selectedShips).then((ok) => {
              if (ok) onClose();
            });
          }}
        >
          Send expedition
        </button>
      </div>
    </SheetPortal>
  );
}
