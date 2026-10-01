"use client";

import { useState } from "react";
import { Countdown } from "@/components/countdown";
import { progressToward } from "@/lib/game/catalog";
import type { FleetRow } from "@/lib/game/types";

const HULL_LABELS: Record<string, string> = {
  light_fighter: "Light fighter",
  heavy_fighter: "Heavy fighter",
  cruiser: "Cruiser",
  battleship: "Battleship",
  battlecruiser: "Battlecruiser",
  bomber: "Bomber",
  destroyer: "Destroyer",
  deathstar: "Deathstar",
  small_cargo: "Small cargo",
  large_cargo: "Large cargo",
  colony_ship: "Colony ship",
  recycler: "Recycler",
  espionage_probe: "Probe",
  reaper: "Reaper",
  pathfinder: "Pathfinder",
  crawler: "Crawler",
  solar_satellite: "Satellite",
  pirate: "Pirate",
};

function coords(galaxy?: number | null, system?: number | null, slot?: number | null) {
  if (galaxy == null || system == null || slot == null) return "—";
  return `[${galaxy}:${system}:${slot}]`;
}

function clock(value: number | string | null | undefined) {
  if (value == null) return "—";
  const t = typeof value === "string" ? new Date(value).getTime() : value;
  if (!Number.isFinite(t)) return "—";
  return new Date(t).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
}

function isReturnMission(mission: FleetRow["mission"]) {
  return (
    mission === "return" ||
    mission === "espionage_return" ||
    mission === "harvest_return" ||
    mission === "colonize_return" ||
    mission === "expedition_return"
  );
}

function missionLabel(fleet: FleetRow, inbound?: boolean) {
  if (inbound) return "Attack";
  switch (fleet.mission) {
    case "attack":
      return "Attack";
    case "espionage":
      return "Espionage";
    case "harvest":
      return "Harvest";
    case "colonize":
      return "Colonize";
    case "expedition":
    case "expedition_hold":
      return "Expedition";
    case "return":
    case "espionage_return":
    case "harvest_return":
    case "colonize_return":
    case "expedition_return":
      return "Return";
    default:
      return fleet.mission;
  }
}

function shipSummary(fleet: FleetRow, inbound?: boolean) {
  const ships = fleet.ship_count ?? fleet.raiders;
  if (inbound) return `${ships.toLocaleString()} ship${ships === 1 ? "" : "s"}`;
  const entries = Object.entries(fleet.composition ?? {}).filter(([, n]) => n > 0);
  const hull =
    entries.length === 1 ? HULL_LABELS[entries[0][0]] ?? entries[0][0].replace(/_/g, " ") : null;
  const cargo = (fleet.cargo_ore ?? 0) + (fleet.cargo_crystal ?? 0) + (fleet.cargo_deuterium ?? 0);
  const cargoBit = cargo > 0 ? ` · +${cargo.toLocaleString()} cargo` : "";
  if (hull) return `${ships} ship (${hull})${cargoBit}`;
  return `${ships} ship${ships === 1 ? "" : "s"}${cargoBit}`;
}

function Chevron({ left }: { left?: boolean }) {
  return (
    <svg viewBox="0 0 8 12" className="h-2.5 w-2" aria-hidden>
      <path
        fill="currentColor"
        d={left ? "M7 1 1 6l6 5" : "M1 1l6 5-6 5"}
        fillOpacity="0"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function FlightArrow({ returning, ships }: { returning?: boolean; ships: number }) {
  const double = ships > 1;
  return (
    <svg
      viewBox={double ? "0 0 16 12" : "0 0 10 12"}
      className={`h-3.5 ${double ? "w-4" : "w-3"} animate-pulse`}
      aria-hidden
    >
      {returning ? (
        double ? (
          <>
            <path
              d="M7.5 1.5 1.5 6l6 4.5"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.8"
              strokeLinejoin="round"
              strokeLinecap="round"
            />
            <path
              d="M14.5 1.5 8.5 6l6 4.5"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.8"
              strokeLinejoin="round"
              strokeLinecap="round"
            />
          </>
        ) : (
          <path
            d="M8 1.5 2 6l6 4.5"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinejoin="round"
            strokeLinecap="round"
          />
        )
      ) : double ? (
        <>
          <path
            d="M1.5 1.5 7.5 6l-6 4.5"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinejoin="round"
            strokeLinecap="round"
          />
          <path
            d="M8.5 1.5 14.5 6l-6 4.5"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinejoin="round"
            strokeLinecap="round"
          />
        </>
      ) : (
        <path
          d="M2 1.5 8 6 2 10.5"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.8"
          strokeLinejoin="round"
          strokeLinecap="round"
        />
      )}
    </svg>
  );
}

export function FleetEventStrip({
  fleet,
  now,
  durationMs,
  originName,
  destName,
  inbound,
  canReturn,
  pending,
  onReturn,
}: {
  fleet: FleetRow;
  now: number;
  durationMs: number;
  originName: string;
  destName: string;
  inbound?: boolean;
  canReturn?: boolean;
  pending?: boolean;
  onReturn?: () => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const shipEntries = Object.entries(fleet.composition ?? {})
    .filter(([, n]) => n > 0)
    .sort(([, a], [, b]) => b - a);
  const cargoTotal = (fleet.cargo_ore ?? 0) + (fleet.cargo_crystal ?? 0) + (fleet.cargo_deuterium ?? 0);
  const returning = !inbound && isReturnMission(fleet.mission);
  const start =
    durationMs > 0
      ? new Date(fleet.arrives_at).getTime() - durationMs
      : new Date(fleet.created_at ?? fleet.arrives_at).getTime();
  const pct = Math.min(0.96, Math.max(0.04, progressToward(fleet.arrives_at, durationMs, now)));
  const arrowLeft = returning ? `${(1 - pct) * 100}%` : `${pct * 100}%`;
  const mission = missionLabel(fleet, inbound);
  const leftName = returning ? destName : originName;
  const rightName = returning ? originName : destName;
  const leftCoords = returning
    ? coords(fleet.dest_galaxy, fleet.dest_system, fleet.dest_slot)
    : inbound
      ? "void"
      : coords(fleet.origin_galaxy, fleet.origin_system, fleet.origin_slot);
  const rightCoords = returning
    ? coords(fleet.origin_galaxy, fleet.origin_system, fleet.origin_slot)
    : coords(fleet.dest_galaxy, fleet.dest_system, fleet.dest_slot);
  const status = inbound
    ? "STATUS: INCOMING STRIKE"
    : returning
      ? "STATUS: RETURNING TO HOMEWORLD"
      : fleet.mission === "expedition_hold"
        ? "STATUS: HOLDING IN THE VOID"
        : `STATUS: TRANSIT TO ${destName.toUpperCase()}`;
  const tone = inbound ? "red" : returning ? "emerald" : "amber";
  const cardBorder =
    tone === "red"
      ? "border-red-500/40"
      : tone === "emerald"
        ? "border-emerald-500/40"
        : "border-amber-500/40";
  const badge =
    tone === "red"
      ? "border-red-500/40 bg-red-950 text-red-300"
      : tone === "emerald"
        ? "border-emerald-500/40 bg-emerald-950 text-emerald-300"
        : "border-amber-500/40 bg-amber-950 text-amber-300";
  const heading =
    tone === "red" ? "text-red-400" : tone === "emerald" ? "text-emerald-400" : "text-amber-400";
  const barClass =
    tone === "red"
      ? "bg-gradient-to-r from-red-700 via-red-400 to-amber-300"
      : tone === "emerald"
        ? "bg-gradient-to-l from-emerald-500 via-cyan-400 to-cyan-300"
        : "bg-gradient-to-r from-cyan-500 via-amber-400 to-amber-300";
  const arrowRing =
    tone === "red"
      ? "border-red-400 text-red-300"
      : tone === "emerald"
        ? "border-emerald-400 text-emerald-300"
        : "border-amber-400 text-amber-300";
  const chevronColor =
    tone === "red" ? "text-red-400" : tone === "emerald" ? "text-emerald-400" : "text-amber-400";

  return (
    <li className={`sci-card overflow-hidden border p-3 ${cardBorder}`}>
      <div className="flex items-center justify-between border-b border-slate-800 pb-2">
        <div className="flex min-w-0 items-center gap-2">
          <span className={`rounded border px-2 py-0.5 text-[11px] font-bold uppercase ${badge}`}>{mission}</span>
          <span className="truncate text-xs font-semibold text-slate-300">{shipSummary(fleet, inbound)}</span>
        </div>
        <div className="shrink-0 text-right">
          <span className={`block text-[11px] font-bold uppercase ${heading}`}>
            {inbound ? "Incoming" : returning ? "Inbound" : "Outbound"}
          </span>
          <span className="text-[10px] text-slate-400">{clock(start)}</span>
        </div>
      </div>

      <div className="mt-3">
        <div className="flex items-start justify-between text-[11px]">
          <div className="min-w-0 pr-2">
            <p className="truncate text-xs font-bold text-slate-100">{leftName}</p>
            <p className="font-mono font-bold text-cyan-400">{leftCoords}</p>
            <p className={`mt-0.5 text-[10px] ${returning ? "text-emerald-400" : "text-slate-400"}`}>
              {returning ? `ETA ${clock(fleet.arrives_at)}` : clock(start)}
            </p>
          </div>
          <div className="min-w-0 pl-2 text-right">
            <p className="truncate text-xs font-bold text-slate-100">{rightName}</p>
            <p className={`font-mono font-bold ${returning ? "text-amber-400" : heading}`}>{rightCoords}</p>
            <p className="mt-0.5 text-[10px] text-slate-400">{clock(returning ? start : fleet.arrives_at)}</p>
          </div>
        </div>

        <div className="relative my-1.5 flex h-8 w-full items-center">
          <div className="relative h-1 w-full overflow-hidden rounded-full border border-slate-800 bg-slate-900">
            <div
              className={`absolute top-0 h-full ${returning ? "right-0" : "left-0"} ${barClass}`}
              style={{ width: `${pct * 100}%` }}
            />
          </div>
          <div
            className={`absolute top-1/2 z-10 flex h-7 w-7 -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full border-2 bg-slate-950 ${arrowRing}`}
            style={{ left: arrowLeft }}
          >
            <FlightArrow returning={returning} ships={fleet.ship_count ?? fleet.raiders} />
          </div>
          <div
            className={`fleet-trajectory pointer-events-none absolute inset-0 flex items-center justify-around text-[10px] ${chevronColor}`}
            aria-hidden
          >
            {Array.from({ length: 5 }, (_, i) => (
              <Chevron key={i} left={returning} />
            ))}
          </div>
        </div>

        <div className="flex items-center justify-between pt-1 text-[10px] text-slate-400">
          <span>{status}</span>
          <span className={`font-bold ${heading}`}>
            ETA: <Countdown until={fleet.arrives_at} now={now} />
          </span>
        </div>
      </div>

      {shipEntries.length > 0 || cargoTotal > 0 ? (
        <>
          <button
            type="button"
            aria-expanded={expanded}
            onClick={() => setExpanded((v) => !v)}
            className="mt-2 flex w-full items-center justify-center gap-1 text-[11px] font-semibold tracking-wide text-cyan-300 uppercase"
          >
            {expanded ? "Hide details" : "Show details"}
            <span className={`inline-block transition-transform ${expanded ? "-rotate-90" : "rotate-90"}`}>
              <Chevron />
            </span>
          </button>
          {expanded ? (
            <div className="mt-2 rounded-lg border border-slate-800 bg-slate-950/60 p-2 text-xs">
              {shipEntries.length > 0 ? (
                <ul className="flex flex-col gap-0.5">
                  {shipEntries.map(([id, n]) => (
                    <li key={id} className="flex justify-between">
                      <span className="text-slate-300">{HULL_LABELS[id] ?? id.replace(/_/g, " ")}</span>
                      <span className="font-mono text-slate-100">{n.toLocaleString()}</span>
                    </li>
                  ))}
                </ul>
              ) : null}
              {cargoTotal > 0 ? (
                <div className={shipEntries.length > 0 ? "mt-2 border-t border-slate-800 pt-2" : ""}>
                  <p className="mb-0.5 text-[10px] tracking-wide text-[var(--muted-fg)] uppercase">Cargo</p>
                  {(
                    [
                      ["Ore", fleet.cargo_ore ?? 0],
                      ["Crystal", fleet.cargo_crystal ?? 0],
                      ["Deuterium", fleet.cargo_deuterium ?? 0],
                    ] as const
                  ).map(([label, n]) => (
                    <p key={label} className="flex justify-between">
                      <span className="text-slate-300">{label}</span>
                      <span className="font-mono text-slate-100">{n.toLocaleString()}</span>
                    </p>
                  ))}
                </div>
              ) : null}
            </div>
          ) : null}
        </>
      ) : null}

      {canReturn && onReturn ? (
        <button
          type="button"
          disabled={pending}
          onClick={onReturn}
          className="sci-btn sci-btn-muted mt-3 h-10 w-full text-xs font-bold tracking-wide uppercase"
        >
          Return fleet
        </button>
      ) : null}
    </li>
  );
}
