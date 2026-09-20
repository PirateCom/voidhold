"use client";

import { useMemo, useState } from "react";
import { useEmpire } from "@/components/empire-provider";
import { flightSeconds } from "@/lib/game/catalog";
import type { GalaxyCell } from "@/lib/game/types";

function cellClass(kind: GalaxyCell["kind"], selected: boolean) {
  const base = "aspect-square rounded-md text-[10px] font-semibold";
  const ring = selected ? " ring-2 ring-[var(--accent)]" : "";
  if (kind === "home") return `${base}${ring} bg-[var(--accent)] text-[var(--accent-fg)]`;
  if (kind === "npc") return `${base}${ring} bg-[#3a2418] text-[#f0c9a0]`;
  if (kind === "player") return `${base}${ring} bg-[#1d2a4a] text-[#9db7ff]`;
  return `${base}${ring} bg-[var(--muted)] text-[var(--muted-fg)]`;
}

export function GalaxyGrid() {
  const { state, pending, raid, now } = useEmpire();
  const [selected, setSelected] = useState<GalaxyCell | null>(null);
  const [ships, setShips] = useState(1);

  const home = state?.planet;
  const flight = useMemo(() => {
    if (!state || !selected || !home) return null;
    if (selected.kind === "empty" || selected.kind === "home") return null;
    return flightSeconds(home.system, home.slot, selected.system, selected.slot, state.empire.propulsion_level);
  }, [state, selected, home]);

  if (!state) return null;

  return (
    <div>
      <div className="grid grid-cols-10 gap-1">
        {state.galaxy.map((cell) => {
          const isSelected = selected?.system === cell.system && selected?.slot === cell.slot;
          return (
            <button
              key={`${cell.system}-${cell.slot}`}
              type="button"
              title={cell.name ?? `${cell.system}:${cell.slot}`}
              className={cellClass(cell.kind, isSelected)}
              onClick={() => setSelected(cell)}
            >
              {cell.kind === "home" ? "H" : cell.kind === "npc" ? "N" : cell.kind === "player" ? "P" : ""}
            </button>
          );
        })}
      </div>
      <p className="mt-3 text-xs text-[var(--muted-fg)]">H home · N derelict · P commander · empty space</p>

      {selected ? (
        <section className="mt-4 rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4">
          <h2 className="font-semibold">
            [{selected.system}:{selected.slot}] {selected.name ?? "Empty space"}
          </h2>
          <p className="mt-1 text-xs text-[var(--muted-fg)]">
            {selected.kind === "npc"
              ? "Abandoned world. Raid it for ore and crystal."
              : selected.kind === "home"
                ? "Your hold."
                : selected.kind === "player"
                  ? selected.owner_name
                    ? `Held by ${selected.owner_name}. Protected in v1.`
                    : "Another commander. Protected in v1."
                  : "No planet here."}
          </p>
          {selected.kind === "npc" ? (
            <form
              className="mt-3 flex flex-col gap-2"
              onSubmit={(e) => {
                e.preventDefault();
                void raid(selected.system, selected.slot, ships);
              }}
            >
              <label className="text-xs text-[var(--muted-fg)]">
                Raiders (you have {state.empire.raiders})
                <input
                  type="number"
                  min={1}
                  max={Math.max(1, state.empire.raiders)}
                  value={ships}
                  onChange={(e) => setShips(Number(e.target.value))}
                  className="mt-1 h-11 w-full rounded-2xl border border-[var(--border)] bg-[var(--background)] px-3"
                />
              </label>
              {flight != null ? (
                <p className="text-xs text-[var(--muted-fg)]">
                  Flight ~{flight}s each way · now {new Date(now).toLocaleTimeString()}
                </p>
              ) : null}
              <button
                type="submit"
                disabled={pending || state.empire.raiders < 1}
                className="h-11 rounded-2xl bg-[var(--accent)] text-sm font-semibold text-[var(--accent-fg)] disabled:opacity-50"
              >
                Launch raid
              </button>
            </form>
          ) : null}
        </section>
      ) : null}
    </div>
  );
}
