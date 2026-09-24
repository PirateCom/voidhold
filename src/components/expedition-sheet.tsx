"use client";

import { useMemo, useState } from "react";
import { SpriteThumb } from "@/components/sprite-thumb";
import { useEmpire } from "@/components/empire-provider";
import {
  EXPEDITION_HOLD_SECONDS,
  EXPEDITION_SLOT,
  SHIPS,
  expeditionFleetCap,
  expeditionFlightSeconds,
} from "@/lib/game/catalog";

export function ExpeditionSheet({
  open,
  galaxy,
  system,
  onClose,
}: {
  open: boolean;
  galaxy: number;
  system: number;
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
  const cargo = Math.max(0, counts.small_cargo ?? 0);
  const flight = expeditionFlightSeconds(
    state.planet.system,
    state.planet.slot,
    system,
    EXPEDITION_SLOT,
    state.empire.propulsion_level,
    state.planet.galaxy,
    galaxy,
  );
  const blocked =
    astro < 1
      ? "Needs Astrophysics 1."
      : active >= cap
        ? "No free expedition slots."
        : cargo < 1
          ? "Send at least one small cargo."
          : cargo > state.empire.raiders
            ? "Not enough small cargo."
            : null;

  return (
    <div className="fixed inset-0 z-40 flex items-end justify-center bg-black/60 p-3">
      <div className="sci-card max-h-[80vh] w-full max-w-md overflow-y-auto p-4">
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 className="font-semibold">Expedition</h2>
            <p className="mt-1 text-xs text-[var(--muted-fg)]">
              [{galaxy}:{system}:{EXPEDITION_SLOT}] Outer space · hold {EXPEDITION_HOLD_SECONDS}s · slots {active}/{cap}
            </p>
          </div>
          <button type="button" className="sci-btn sci-btn-quiet h-11 px-3" onClick={onClose}>
            Close
          </button>
        </div>
        <p className="mt-3 text-xs text-[var(--muted-fg)]">
          Wiki expeditions need Astrophysics 1. Only docked hulls can launch. Small cargo is the hull in dock.
        </p>
        <ul className="mt-3 flex flex-col gap-2">
          {flyable.map((ship) => {
            const have = docked[ship.id] ?? 0;
            const locked = have < 1 && ship.id !== "small_cargo";
            return (
              <li key={ship.id} className="flex items-center gap-3 rounded-xl border border-[var(--border)] px-3 py-2">
                <SpriteThumb id={ship.id} />
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold">{ship.name}</p>
                  <p className="text-xs text-[var(--muted-fg)]">Docked {have}</p>
                </div>
                <input
                  type="number"
                  min={0}
                  max={Math.max(have, 0)}
                  disabled={locked || pending}
                  value={ship.id === "small_cargo" ? cargo : 0}
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
          Flight ~{flight}s each way · now {new Date(now).toLocaleTimeString()}
        </p>
        {blocked ? <p className="mt-2 text-sm text-amber-200">{blocked}</p> : null}
        <button
          type="button"
          disabled={pending || Boolean(blocked)}
          className="sci-btn mt-3 h-11 w-full"
          onClick={() => {
            void sendExpedition(galaxy, system, { small_cargo: cargo }).then((ok) => {
              if (ok) onClose();
            });
          }}
        >
          Send expedition
        </button>
      </div>
    </div>
  );
}
