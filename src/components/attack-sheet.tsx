"use client";

import { useMemo, useState } from "react";
import { SpriteThumb } from "@/components/sprite-thumb";
import { useEmpire } from "@/components/empire-provider";
import { SheetPortal } from "@/components/sheet-portal";
import { SHIPS, attackFlightSeconds, attackFuel, formatDuration, slowestHullSpeed } from "@/lib/game/catalog";

export function AttackSheet({
  open,
  galaxy,
  system,
  slot,
  targetName,
  onClose,
}: {
  open: boolean;
  galaxy: number;
  system: number;
  slot: number;
  targetName: string;
  onClose: () => void;
}) {
  const { state, pending, attack, now } = useEmpire();
  const [counts, setCounts] = useState<Record<string, number>>({});
  const [speed, setSpeed] = useState(100);
  const flyable = useMemo(() => SHIPS.filter((ship) => ship.speed > 0), []);
  if (!open || !state) return null;

  const docked: Record<string, number> = {
    ...(state.empire.ships ?? {}),
    small_cargo: state.empire.raiders,
  };
  const selected = Object.values(counts).reduce((sum, n) => sum + (n > 0 ? n : 0), 0);
  const slowest = slowestHullSpeed(
    counts,
    state.empire.impulse_drive ?? 0,
    state.empire.hyperspace_drive ?? 0,
    state.empire.propulsion_level,
  );
  const flight =
    slowest > 0
      ? attackFlightSeconds(
          state.planet.system,
          state.planet.slot,
          system,
          slot,
          state.empire.propulsion_level,
          state.planet.galaxy,
          galaxy,
          slowest,
          speed,
        )
      : null;
  const fuel = attackFuel(
    counts,
    state.planet.galaxy,
    state.planet.system,
    state.planet.slot,
    galaxy,
    system,
    slot,
    state.empire.impulse_drive ?? 0,
    speed,
  );
  const cargo = flyable.reduce((sum, ship) => sum + Math.max(0, counts[ship.id] ?? 0) * ship.cargo, 0);
  const blocked =
    selected < 1
      ? "Send at least one ship."
      : Number(state.planet.deuterium) < fuel
        ? "Not enough deuterium for fuel."
        : null;

  return (
    <SheetPortal>
      <div className="sci-card max-h-full w-full max-w-md overflow-y-auto p-4">
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 className="font-semibold">Attack</h2>
            <p className="mt-1 text-xs text-[var(--muted-fg)]">
              [{galaxy}:{system}:{slot}] {targetName}
            </p>
          </div>
          <button type="button" className="sci-btn sci-btn-quiet h-11 px-3" onClick={onClose}>
            Close
          </button>
        </div>
        <p className="mt-3 text-xs text-[var(--muted-fg)]">
          A win plunders up to half of each resource, limited by surviving cargo. Six rounds with both sides still
          standing is a draw and takes nothing. Docked ships and defenses fight back.
        </p>
        <ul className="mt-3 flex flex-col gap-2">
          {flyable.map((ship) => {
            const have = docked[ship.id] ?? 0;
            return (
              <li key={ship.id} className="flex items-center gap-3 rounded-xl border border-[var(--border)] px-3 py-2">
                <SpriteThumb id={ship.id} />
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold">{ship.name}</p>
                  <p className="text-xs text-[var(--muted-fg)]">
                    Docked {have} · cargo {ship.cargo.toLocaleString()}
                  </p>
                </div>
                <input
                  type="number"
                  min={0}
                  max={Math.max(have, 0)}
                  disabled={have < 1 || pending}
                  value={counts[ship.id] ?? 0}
                  onChange={(e) =>
                    setCounts((prev) => ({
                      ...prev,
                      [ship.id]: Math.max(0, Math.min(have, Math.floor(Number(e.target.value) || 0))),
                    }))
                  }
                  className="sci-input h-11 w-20 px-2 text-center"
                />
              </li>
            );
          })}
        </ul>
        <label className="mt-3 block text-xs text-[var(--muted-fg)]">
          Speed {speed}%
          <input
            type="range"
            min={10}
            max={100}
            step={10}
            value={speed}
            onChange={(e) => setSpeed(Number(e.target.value))}
            className="mt-1 w-full"
          />
        </label>
        <p className="mt-2 text-xs text-[var(--muted-fg)]">
          Flight {flight == null ? "—" : formatDuration(flight)} each way · fuel {fuel.toLocaleString()} deut · cargo{" "}
          {cargo.toLocaleString()} · slowest {slowest > 0 ? slowest.toLocaleString() : "—"} · now{" "}
          {new Date(now).toLocaleTimeString()}
        </p>
        {blocked ? <p className="mt-2 text-sm text-amber-200">{blocked}</p> : null}
        <button
          type="button"
          disabled={pending || Boolean(blocked)}
          className="sci-btn mt-3 h-11 w-full"
          onClick={() => {
            const payload = Object.fromEntries(Object.entries(counts).filter(([, n]) => n > 0));
            void attack(galaxy, system, slot, payload, speed).then((ok) => {
              if (ok) onClose();
            });
          }}
        >
          Launch attack
        </button>
      </div>
    </SheetPortal>
  );
}
