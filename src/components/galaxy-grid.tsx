"use client";

import { useEffect, useMemo, useState, type ReactNode } from "react";
import { AttackSheet } from "@/components/attack-sheet";
import { Countdown } from "@/components/countdown";
import { ExpeditionSheet } from "@/components/expedition-sheet";
import { DeploySheet } from "@/components/deploy-sheet";
import { TransportSheet } from "@/components/transport-sheet";
import { SheetDock, SheetPortal } from "@/components/sheet-portal";
import { useEmpire } from "@/components/empire-provider";
import { PlanetAvatar } from "@/components/planet-avatar";
import { loadSolarSystem } from "@/lib/game/actions";
import { attackFlightSeconds, attackFuel, canColonizeSlot, colonizeSlotRange, flightSeconds, hullSpeed, maxPlanets, starLabel, debrisVisible, fleetFuelRoundTrip, shipSpec } from "@/lib/game/catalog";
import type { SolarSlot, SolarSystemView } from "@/lib/game/types";

function DebrisMark() {
  return (
    <span
      className="inline-flex h-5 w-5 items-center justify-center rounded-full border border-amber-500/50 bg-amber-950/80 text-[10px] text-amber-200"
      title="Debris field"
      aria-label="Debris field"
    >
      <svg viewBox="0 0 16 16" className="h-3.5 w-3.5" aria-hidden>
        <path fill="currentColor" d="M3 11 6 5l3 4 2-3 3 5H3Zm1.5-1.2h7.2l-1.6-2.6-1.8 2.6-2.2-3-1.6 3Z" />
        <circle cx="5" cy="12.5" r="0.9" fill="currentColor" />
        <circle cx="11" cy="12.2" r="0.7" fill="currentColor" />
      </svg>
    </span>
  );
}

type GalaxyAction = "attack" | "spy" | "transport" | "deploy" | "expedition" | "colonize" | "recycle";

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
  const { state, pending, spy, harvest, colonize, now } = useEmpire();
  const [galaxy, setGalaxy] = useState(1);
  const [system, setSystem] = useState(1);
  const [ready, setReady] = useState(false);
  const [view, setView] = useState<SolarSystemView | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [selected, setSelected] = useState<SolarSlot | null>(null);
  const [spyShips, setSpyShips] = useState(1);
  const [harvestShips, setHarvestShips] = useState(1);
  const [colonizeShips, setColonizeShips] = useState(1);
  const [action, setAction] = useState<GalaxyAction | null>(null);

  useEffect(() => {
    setAction(null);
  }, [selected?.slot, galaxy, system]);

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
    if (selected.kind !== "npc" && selected.kind !== "player") return null;
    return flightSeconds(
      home.system,
      home.slot,
      system,
      selected.slot,
      state.empire.propulsion_level,
      home.galaxy,
      galaxy,
      hullSpeed("espionage_probe", 0, 0, state.empire.propulsion_level),
    );
  }, [state, selected, home, system, galaxy]);

  const harvestFlight = useMemo(() => {
    if (!state || !selected || !home) return null;
    if (selected.kind === "outer") return null;
    return attackFlightSeconds(
      home.system,
      home.slot,
      system,
      selected.slot,
      state.empire.propulsion_level,
      home.galaxy,
      galaxy,
      hullSpeed("recycler", state.empire.impulse_drive ?? 0, state.empire.hyperspace_drive ?? 0, state.empire.propulsion_level),
      100,
    );
  }, [state, selected, home, system, galaxy]);

  const probesDocked = Math.max(0, state?.empire.ships?.espionage_probe ?? 0);
  const recyclersDocked = Math.max(0, state?.empire.ships?.recycler ?? 0);
  const recyclersNeeded = useMemo(() => {
    if (!selected) return 0;
    const total = Number(selected.debris_ore ?? 0) + Number(selected.debris_crystal ?? 0);
    if (total <= 0) return 0;
    const hold = shipSpec("recycler")?.cargo ?? 20000;
    return Math.ceil(total / hold);
  }, [selected]);
  const harvestFuel = useMemo(() => {
    if (!state || !selected || !home) return 0;
    if (selected.kind === "outer") return 0;
    return attackFuel(
      { recycler: Math.max(1, harvestShips) },
      home.galaxy,
      home.system,
      home.slot,
      galaxy,
      system,
      selected.slot,
      state.empire.impulse_drive ?? 0,
      100,
    );
  }, [state, selected, home, harvestShips, galaxy, system]);
  const colonyShipsDocked = Math.max(0, state?.empire.ships?.colony_ship ?? 0);
  const astro = state?.empire.astrophysics ?? 0;
  const colonizeRange = colonizeSlotRange(astro);
  const colonizeFlight = useMemo(() => {
    if (!state || !selected || !home) return null;
    if (selected.kind !== "empty") return null;
    return attackFlightSeconds(
      home.system,
      home.slot,
      system,
      selected.slot,
      state.empire.propulsion_level,
      home.galaxy,
      galaxy,
      hullSpeed("colony_ship", state.empire.impulse_drive ?? 0, state.empire.hyperspace_drive ?? 0, state.empire.propulsion_level),
      100,
    );
  }, [state, selected, home, system, galaxy]);
  const colonizeFuel = useMemo(() => {
    if (!state || !selected || !home) return 0;
    if (selected.kind !== "empty") return 0;
    return attackFuel(
      { colony_ship: Math.max(1, colonizeShips) },
      home.galaxy,
      home.system,
      home.slot,
      galaxy,
      system,
      selected.slot,
      state.empire.impulse_drive ?? 0,
      100,
    );
  }, [state, selected, home, colonizeShips, galaxy, system]);
  const spyFuel = useMemo(() => {
    if (!state || !selected || !home) return 0;
    if (selected.kind !== "npc" && selected.kind !== "player") return 0;
    return fleetFuelRoundTrip(
      Math.max(1, spyShips),
      home.galaxy,
      home.system,
      home.slot,
      galaxy,
      system,
      selected.slot,
      "espionage_probe",
      state.empire.impulse_drive ?? 0,
    );
  }, [state, selected, home, spyShips, galaxy, system]);

  if (!state) return null;

  const hasDebris = Boolean(selected && (selected.debris_ore ?? 0) + (selected.debris_crystal ?? 0) > 0);
  const actions: { id: GalaxyAction; label: string; muted?: boolean }[] = [];
  if (selected) {
    const isCurrent =
      selected.kind === "home" &&
      galaxy === state.planet.galaxy &&
      system === state.planet.system &&
      selected.slot === state.planet.slot;
    if (selected.kind === "npc" || selected.kind === "player") {
      actions.push({ id: "attack", label: "Attack" }, { id: "spy", label: "Spy", muted: true });
    }
    if (selected.kind === "player" || (selected.kind === "home" && !isCurrent)) {
      actions.push({ id: "transport", label: "Haul", muted: true });
    }
    if (selected.kind === "home" && !isCurrent) {
      actions.push({ id: "deploy", label: "Deploy", muted: true });
    }
    if (selected.kind === "empty" || selected.kind === "outer") {
      actions.push({ id: "expedition", label: "Expedition" });
    }
    if (selected.kind === "empty") {
      actions.push({ id: "colonize", label: "Colonize", muted: true });
    }
    if (hasDebris && selected.kind !== "outer") {
      actions.push({ id: "recycle", label: "Recycle", muted: true });
    }
  }

  return (
    <div>
      <div className="grid grid-cols-2 gap-2">
        <label className="text-xs text-[var(--muted-fg)]">
          Galaxy
          <span className="mt-1 flex gap-1">
            <button
              type="button"
              aria-label="Previous galaxy"
              className="sci-btn sci-btn-muted h-12 w-14 shrink-0 px-0 text-lg"
              onClick={() => setGalaxy((g) => wrap(g - 1, 9))}
            >
              ◀
            </button>
            <input
              type="number"
              min={1}
              max={9}
              value={galaxy}
              onChange={(e) => setGalaxy(wrap(Number(e.target.value) || 1, 9))}
              className="sci-input h-12 w-0 min-w-0 flex-1 px-0 text-center text-base"
            />
            <button
              type="button"
              aria-label="Next galaxy"
              className="sci-btn sci-btn-muted h-12 w-14 shrink-0 px-0 text-lg"
              onClick={() => setGalaxy((g) => wrap(g + 1, 9))}
            >
              ▶
            </button>
          </span>
        </label>
        <label className="text-xs text-[var(--muted-fg)]">
          System
          <span className="mt-1 flex gap-1">
            <button
              type="button"
              aria-label="Previous system"
              className="sci-btn sci-btn-muted h-12 w-14 shrink-0 px-0 text-lg"
              onClick={() => setSystem((s) => wrap(s - 1, 499))}
            >
              ◀
            </button>
            <input
              type="number"
              min={1}
              max={499}
              value={system}
              onChange={(e) => setSystem(wrap(Number(e.target.value) || 1, 499))}
              className="sci-input h-12 w-0 min-w-0 flex-1 px-0 text-center text-base"
            />
            <button
              type="button"
              aria-label="Next system"
              className="sci-btn sci-btn-muted h-12 w-14 shrink-0 px-0 text-lg"
              onClick={() => setSystem((s) => wrap(s + 1, 499))}
            >
              ▶
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
                {slot.planet_id && slot.kind !== "empty" && slot.kind !== "outer" ? (
                  <PlanetAvatar seed={String(slot.planet_id)} size={20} own={slot.kind === "home"} />
                ) : null}
                <span className="font-semibold">{label}</span>
                {debrisVisible(slot.debris_ore ?? 0, slot.debris_crystal ?? 0) ? <DebrisMark /> : null}
                {slot.kind === "outer" ? (
                  <span className="ml-auto text-[10px] uppercase tracking-wide text-cyan-300">Expedition</span>
                ) : slot.owner_name ? (
                  <span className="ml-auto text-xs">{slot.owner_name}</span>
                ) : null}
              </button>
            </li>
          );
        })}
      </ul>

      {selected ? (
        <section className="sci-card mt-4 mb-16 p-4">
          <h2 className="font-semibold">
            [{galaxy}:{system}:{selected.slot}] {selected.name ?? (selected.kind === "empty" ? "Empty space" : "Outer space")}
          </h2>
          <p className="mt-1 text-xs text-[var(--muted-fg)]">
            {selected.kind === "npc"
              ? "Abandoned world. Attack it to plunder ore, crystal, and deuterium. A later NPC garrison will fight from here."
              : selected.kind === "home"
                ? "Your hold."
                : selected.kind === "player"
                  ? selected.owner_name
                    ? `Held by ${selected.owner_name}. Attack to raid. Docked ships and defenses fight back.`
                    : "Another commander. Attack to raid. Docked ships and defenses fight back."
                  : selected.kind === "outer"
                    ? "Uncolonizable. Expeditions launch from this slot."
                    : "Empty slot. A colony ship can found a world here if Astrophysics allows it, or send an expedition."}
          </p>
          {hasDebris ? (
            <p className="mt-2 text-xs text-amber-200">
              Debris field {Number(selected.debris_ore ?? 0).toLocaleString()} ore ·{" "}
              {Number(selected.debris_crystal ?? 0).toLocaleString()} crystal
              {debrisVisible(selected.debris_ore ?? 0, selected.debris_crystal ?? 0) ? "" : " (hidden on the map)"}
              {selected.debris_decays_at && selected.debris_gone_at ? (
                <span className="block text-[var(--muted-fg)]">
                  {new Date(selected.debris_decays_at).getTime() > now ? (
                    <>
                      Starts decaying in <Countdown until={selected.debris_decays_at} now={now} />
                    </>
                  ) : (
                    <>
                      Decaying · gone in <Countdown until={selected.debris_gone_at} now={now} />
                    </>
                  )}
                </span>
              ) : null}
            </p>
          ) : null}
        </section>
      ) : null}

      {selected ? (
        <SheetDock>
          <div className="flex items-center gap-1">
            {actions.map((a) => (
              <button
                key={a.id}
                type="button"
                className={`sci-btn h-9 min-w-0 flex-1 truncate px-1 text-[10px] ${action === a.id ? "sci-btn-warn" : a.muted ? "sci-btn-muted" : ""}`}
                onClick={() => setAction((cur) => (cur === a.id ? null : a.id))}
              >
                {a.label}
              </button>
            ))}
            {actions.length === 0 ? (
              <span className="text-xs text-[var(--muted-fg)]">No fleet actions for this slot.</span>
            ) : null}
            <button
              type="button"
              aria-label="Close"
              className="sci-btn sci-btn-quiet ml-auto h-9 w-9 shrink-0 px-0"
              onClick={() => {
                setAction(null);
                setSelected(null);
              }}
            >
              ✕
            </button>
          </div>
        </SheetDock>
      ) : null}

      {selected && action === "colonize" ? (
        <ActionSheet title="Colonize" subtitle={`[${galaxy}:${system}:${selected.slot}] Empty slot`} onClose={() => setAction(null)}>
          <form
            className="flex flex-col gap-2"
            onSubmit={(e) => {
              e.preventDefault();
              void colonize(galaxy, system, selected.slot, colonizeShips).then(() => setAction(null));
            }}
          >
            <label className="text-xs text-[var(--muted-fg)]">
              Colony ships (you have {colonyShipsDocked})
              <input
                type="number"
                min={1}
                max={Math.max(1, colonyShipsDocked)}
                value={colonizeShips}
                onChange={(e) => setColonizeShips(Number(e.target.value))}
                className="sci-input mt-1 h-11 w-full px-3"
              />
            </label>
            {colonizeFlight != null ? (
              <p className="text-xs text-[var(--muted-fg)]">
                Colonize flight ~{colonizeFlight}s · fuel {colonizeFuel.toLocaleString()} deut (round trip reserved) ·
                slots {colonizeRange.min}–{colonizeRange.max} · planets {maxPlanets(astro)}
              </p>
            ) : null}
            <button
              type="submit"
              disabled={
                pending ||
                colonyShipsDocked < 1 ||
                astro < 1 ||
                !canColonizeSlot(selected.slot, astro) ||
                Number(state.planet.deuterium) < colonizeFuel
              }
              className="sci-btn h-11"
            >
              {astro < 1
                ? "Needs Astrophysics 1"
                : !canColonizeSlot(selected.slot, astro)
                  ? `Needs slots ${colonizeRange.min}–${colonizeRange.max}`
                  : "Colonize"}
            </button>
          </form>
        </ActionSheet>
      ) : null}

      {selected && action === "recycle" ? (
        <ActionSheet
          title="Recycle debris"
          subtitle={`[${galaxy}:${system}:${selected.slot}] ${Number(selected.debris_ore ?? 0).toLocaleString()} ore · ${Number(selected.debris_crystal ?? 0).toLocaleString()} crystal`}
          onClose={() => setAction(null)}
        >
          <form
            className="flex flex-col gap-2"
            onSubmit={(e) => {
              e.preventDefault();
              void harvest(galaxy, system, selected.slot, harvestShips).then(() => setAction(null));
            }}
          >
            {selected.debris_decays_at && new Date(selected.debris_decays_at).getTime() > now ? (
              <p className="text-xs text-amber-200">
                Decaying in <Countdown until={selected.debris_decays_at} now={now} />
              </p>
            ) : null}
            {recyclersNeeded > 0 ? (
              <p className="text-xs text-[var(--muted-fg)]">
                Recyclers needed: {recyclersNeeded.toLocaleString()}
                {recyclersDocked < recyclersNeeded ? ` · you have ${recyclersDocked}` : ""}
              </p>
            ) : null}
            <label className="text-xs text-[var(--muted-fg)]">
              Recyclers (you have {recyclersDocked})
              <input
                type="number"
                min={1}
                max={Math.max(1, recyclersDocked)}
                value={harvestShips}
                onChange={(e) => setHarvestShips(Number(e.target.value))}
                className="sci-input mt-1 h-11 w-full px-3"
              />
            </label>
            {harvestFlight != null ? (
              <p className="text-xs text-[var(--muted-fg)]">
                Harvest flight ~{harvestFlight}s each way · fuel {harvestFuel.toLocaleString()} deut round trip
              </p>
            ) : null}
            <button
              type="submit"
              disabled={pending || recyclersDocked < 1 || Number(state.planet.deuterium) < harvestFuel}
              className="sci-btn h-11"
            >
              Harvest debris
            </button>
          </form>
        </ActionSheet>
      ) : null}

      {selected && action === "spy" ? (
        <ActionSheet
          title="Espionage"
          subtitle={`[${galaxy}:${system}:${selected.slot}] ${selected.name ?? "Unknown"}`}
          onClose={() => setAction(null)}
        >
          <form
            className="flex flex-col gap-2"
            onSubmit={(e) => {
              e.preventDefault();
              void spy(galaxy, system, selected.slot, spyShips).then(() => setAction(null));
            }}
          >
            <label className="text-xs text-[var(--muted-fg)]">
              Espionage probes (you have {probesDocked})
              <input
                type="number"
                min={1}
                max={Math.max(1, probesDocked)}
                value={spyShips}
                onChange={(e) => setSpyShips(Number(e.target.value))}
                className="sci-input mt-1 h-11 w-full px-3"
              />
            </label>
            {flight != null ? (
              <p className="text-xs text-[var(--muted-fg)]">
                Spy flight ~{flight}s each way · fuel {spyFuel.toLocaleString()} deut round trip
              </p>
            ) : null}
            <button
              type="submit"
              disabled={
                pending ||
                probesDocked < 1 ||
                (state.empire.espionage_tech ?? 0) < 2 ||
                Number(state.planet.deuterium) < spyFuel
              }
              className="sci-btn h-11"
            >
              {(state.empire.espionage_tech ?? 0) < 2 ? "Needs Espionage 2" : "Launch spy"}
            </button>
          </form>
        </ActionSheet>
      ) : null}

      <AttackSheet
        open={action === "attack"}
        galaxy={galaxy}
        system={system}
        slot={selected?.slot ?? 1}
        targetName={selected?.name ?? "Unknown"}
        onClose={() => setAction(null)}
      />
      <ExpeditionSheet
        open={action === "expedition"}
        galaxy={galaxy}
        system={system}
        slot={selected?.slot ?? 16}
        onClose={() => setAction(null)}
      />
      <TransportSheet
        open={action === "transport"}
        galaxy={galaxy}
        system={system}
        slot={selected?.slot ?? 1}
        targetName={selected?.name ?? "Unknown"}
        onClose={() => setAction(null)}
      />
      <DeploySheet
        open={action === "deploy"}
        galaxy={galaxy}
        system={system}
        slot={selected?.slot ?? 1}
        targetName={selected?.name ?? "Unknown"}
        onClose={() => setAction(null)}
      />
    </div>
  );
}

function ActionSheet({
  title,
  subtitle,
  onClose,
  children,
}: {
  title: string;
  subtitle: string;
  onClose: () => void;
  children: ReactNode;
}) {
  return (
    <SheetPortal>
      <div className="sci-card max-h-full w-full max-w-md overflow-y-auto p-4">
        <div className="mb-3 flex items-start justify-between gap-3">
          <div>
            <h2 className="font-semibold">{title}</h2>
            <p className="mt-1 text-xs text-[var(--muted-fg)]">{subtitle}</p>
          </div>
          <button type="button" className="sci-btn sci-btn-quiet h-11 px-3" onClick={onClose}>
            Close
          </button>
        </div>
        {children}
      </div>
    </SheetPortal>
  );
}
