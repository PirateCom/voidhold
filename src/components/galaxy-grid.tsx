"use client";

import { useEffect, useMemo, useState } from "react";
import { useEmpire } from "@/components/empire-provider";
import { loadSolarSystem } from "@/lib/game/actions";
import { flightSeconds, starLabel } from "@/lib/game/catalog";
import type { SolarSlot, SolarSystemView } from "@/lib/game/types";

function wrap(value: number, max: number) {
  return ((value - 1 + max) % max) + 1;
}

function slotClass(kind: SolarSlot["kind"], selected: boolean) {
  const ring = selected ? " ring-2 ring-[var(--accent)]" : "";
  if (kind === "home") return `bg-[var(--accent)] text-[var(--accent-fg)]${ring}`;
  if (kind === "npc") return `bg-[#3a2418] text-[#f0c9a0]${ring}`;
  if (kind === "player") return `bg-[#1d2a4a] text-[#9db7ff]${ring}`;
  if (kind === "outer") return `bg-[#12141c] text-[var(--muted-fg)]${ring}`;
  return `bg-[var(--muted)] text-[var(--muted-fg)]${ring}`;
}

export function GalaxyGrid() {
  const { state, pending, raid, now } = useEmpire();
  const [galaxy, setGalaxy] = useState(1);
  const [system, setSystem] = useState(1);
  const [ready, setReady] = useState(false);
  const [view, setView] = useState<SolarSystemView | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [selected, setSelected] = useState<SolarSlot | null>(null);
  const [ships, setShips] = useState(1);

  useEffect(() => {
    if (!state || ready) return;
    setGalaxy(state.planet.galaxy);
    setSystem(state.planet.system);
    setReady(true);
  }, [state, ready]);

  useEffect(() => {
    if (!ready) return;
    let cancel = false;
    void loadSolarSystem(galaxy, system)
      .then((next) => {
        if (!cancel) {
          setView(next);
          setLoadError(null);
        }
      })
      .catch((err: unknown) => {
        if (cancel) return;
        const message = err instanceof Error ? err.message : "Could not read this system.";
        setLoadError(
          message.includes("get_solar_system")
            ? "The galaxy map is not on the database yet. Run supabase/migrations/006_galaxy.sql in the Supabase SQL editor, then reload."
            : message,
        );
      });
    return () => {
      cancel = true;
    };
  }, [galaxy, system, ready, state?.server_now]);

  const home = state?.planet;
  const flight = useMemo(() => {
    if (!state || !selected || !home) return null;
    if (selected.kind !== "npc") return null;
    return flightSeconds(
      home.system,
      home.slot,
      system,
      selected.slot,
      state.empire.propulsion_level,
      home.galaxy,
      galaxy,
    );
  }, [state, selected, home, system, galaxy]);

  if (!state) return null;

  return (
    <div>
      <div className="grid grid-cols-2 gap-2">
        <label className="text-xs text-[var(--muted-fg)]">
          Galaxy
          <span className="mt-1 flex gap-1">
            <button
              type="button"
              className="sci-btn sci-btn-muted h-11 w-11"
              onClick={() => setGalaxy((g) => wrap(g - 1, 9))}
            >
              −
            </button>
            <input
              type="number"
              min={1}
              max={9}
              value={galaxy}
              onChange={(e) => setGalaxy(wrap(Number(e.target.value) || 1, 9))}
              className="sci-input h-11 w-full px-3 text-center"
            />
            <button
              type="button"
              className="sci-btn sci-btn-muted h-11 w-11"
              onClick={() => setGalaxy((g) => wrap(g + 1, 9))}
            >
              +
            </button>
          </span>
        </label>
        <label className="text-xs text-[var(--muted-fg)]">
          System
          <span className="mt-1 flex gap-1">
            <button
              type="button"
              className="sci-btn sci-btn-muted h-11 w-11"
              onClick={() => setSystem((s) => wrap(s - 1, 499))}
            >
              −
            </button>
            <input
              type="number"
              min={1}
              max={499}
              value={system}
              onChange={(e) => setSystem(wrap(Number(e.target.value) || 1, 499))}
              className="sci-input h-11 w-full px-3 text-center"
            />
            <button
              type="button"
              className="sci-btn sci-btn-muted h-11 w-11"
              onClick={() => setSystem((s) => wrap(s + 1, 499))}
            >
              +
            </button>
          </span>
        </label>
      </div>

      {view ? (
        <p className="mt-3 text-sm">
          {starLabel(view.star_type)} · solar ×{view.multiplier}
        </p>
      ) : null}
      {loadError ? <p className="mt-3 text-sm text-red-300">{loadError}</p> : null}

      <ul className="mt-3 flex flex-col gap-1">
        {(view?.slots ?? []).map((slot) => {
          const isSelected = selected?.slot === slot.slot;
          const label =
            slot.kind === "outer"
              ? "Outer space"
              : slot.kind === "empty"
                ? "Empty"
                : (slot.name ?? "Occupied");
          return (
            <li key={slot.slot}>
              <button
                type="button"
                className={`flex w-full items-center gap-3 rounded-xl px-3 py-2 text-left text-sm ${slotClass(slot.kind, isSelected)}`}
                onClick={() => setSelected(slot)}
              >
                <span className="w-6 font-mono text-xs">{slot.slot}</span>
                <span className="font-semibold">{label}</span>
                {slot.owner_name ? <span className="ml-auto text-xs">{slot.owner_name}</span> : null}
              </button>
            </li>
          );
        })}
      </ul>

      {selected ? (
        <section className="sci-card mt-4 p-4">
          <h2 className="font-semibold">
            [{galaxy}:{system}:{selected.slot}] {selected.name ?? (selected.kind === "empty" ? "Empty space" : "Outer space")}
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
                  : selected.kind === "outer"
                    ? "Uncolonizable."
                    : "No planet here."}
          </p>
          {selected.kind === "npc" ? (
            <form
              className="mt-3 flex flex-col gap-2"
              onSubmit={(e) => {
                e.preventDefault();
                void raid(galaxy, system, selected.slot, ships);
              }}
            >
              <label className="text-xs text-[var(--muted-fg)]">
                Small cargo (you have {state.empire.raiders})
                <input
                  type="number"
                  min={1}
                  max={Math.max(1, state.empire.raiders)}
                  value={ships}
                  onChange={(e) => setShips(Number(e.target.value))}
                  className="sci-input mt-1 h-11 w-full px-3"
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
                className="sci-btn h-11"
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
