"use client";

import { Countdown } from "@/components/countdown";
import { progressToward } from "@/lib/game/catalog";
import type { FleetRow } from "@/lib/game/types";

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

function Globe({ hostile }: { hostile?: boolean }) {
  return (
    <svg viewBox="0 0 36 36" className={`h-8 w-8 ${hostile ? "text-red-300" : "text-cyan-200"}`} aria-hidden>
      <circle cx="18" cy="18" r="12" fill={hostile ? "#3f1d1d" : "#0b3b4a"} stroke="currentColor" strokeWidth="1.4" />
      <path fill={hostile ? "#b91c1c" : "#1d9b7a"} d="M9 17c4-6 9-7 14-5 2 5 1 11-3 14-6 1-11-3-11-9Z" />
    </svg>
  );
}

function Craft({ inbound }: { inbound?: boolean }) {
  return (
    <svg viewBox="0 0 28 16" className={`h-4 w-7 ${inbound ? "text-red-300" : "text-cyan-200"}`} aria-hidden>
      <path
        fill="currentColor"
        d={inbound ? "M26 8 4 2v4H0v4h4v4Z" : "M2 8 24 2v4h4v4h-4v4Z"}
      />
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
  const ships = fleet.ship_count ?? fleet.raiders;
  const start = durationMs > 0 ? new Date(fleet.arrives_at).getTime() - durationMs : new Date(fleet.created_at ?? fleet.arrives_at).getTime();
  const pct = Math.min(0.92, Math.max(0.08, progressToward(fleet.arrives_at, durationMs, now)));
  const mission =
    inbound
      ? "Attack"
      : fleet.mission === "attack"
        ? "Attack"
        : fleet.mission === "expedition"
          ? "Expedition"
          : fleet.mission === "expedition_hold"
            ? "Expedition"
            : fleet.mission === "expedition_return" || fleet.mission === "return"
              ? "Return"
              : fleet.mission;
  const hostile = Boolean(inbound) || fleet.mission === "attack";

  return (
    <li
      className={`overflow-hidden rounded-lg border ${
        inbound ? "border-red-500/50 bg-red-950/40" : "border-cyan-500/20 bg-slate-950/80"
      }`}
    >
      <div className="flex items-stretch gap-2 p-2">
        <div className="w-[5.5rem] shrink-0 py-1 text-[10px] leading-tight">
          <p className="text-[var(--muted-fg)]">{clock(start)}</p>
          <p className={`mt-1 font-semibold uppercase ${hostile ? "text-red-400" : "text-emerald-400"}`}>{mission}</p>
          <p className="mt-0.5 truncate text-[var(--muted-fg)]">
            {inbound ? fleet.attacker_name || "Pirates" : `${ships} ship${ships === 1 ? "" : "s"}`}
          </p>
          {inbound ? (
            <p className="mt-0.5 font-semibold text-red-200">
              {ships.toLocaleString()} ship{ships === 1 ? "" : "s"}
            </p>
          ) : null}
        </div>
        <div className="fleet-grid relative min-h-[4.5rem] min-w-0 flex-1 rounded-md border border-white/10">
          <div className="absolute inset-y-0 left-1 flex w-14 flex-col items-center justify-center">
            <Globe hostile={inbound} />
            <p className="mt-0.5 w-full truncate text-center text-[9px] text-slate-300">{originName}</p>
            <p className="text-[9px] text-slate-400">
              {inbound ? "void" : coords(fleet.origin_galaxy, fleet.origin_system, fleet.origin_slot)}
            </p>
          </div>
          <div className="absolute inset-y-0 right-1 flex w-14 flex-col items-center justify-center">
            <Globe />
            <p className="mt-0.5 w-full truncate text-center text-[9px] text-slate-300">{destName}</p>
            <p className="text-[9px] text-slate-400">
              {coords(fleet.dest_galaxy, fleet.dest_system, fleet.dest_slot)}
            </p>
          </div>
          <div
            className="pointer-events-none absolute top-1/2 -translate-x-1/2 -translate-y-1/2"
            style={{ left: `${8 + pct * 84}%` }}
          >
            <Craft inbound={inbound} />
          </div>
        </div>
        <div className="flex w-[5.2rem] shrink-0 flex-col items-end justify-between py-1 text-right">
          <p className="text-[10px] text-[var(--muted-fg)]">{clock(fleet.arrives_at)}</p>
          {canReturn ? (
            <button
              type="button"
              disabled={pending}
              onClick={onReturn}
              className="text-xs font-semibold text-emerald-400 hover:text-emerald-300 disabled:opacity-50"
            >
              Return
            </button>
          ) : inbound ? (
            <span className="text-[10px] font-semibold tracking-wide text-red-400 uppercase">Incoming</span>
          ) : (
            <span className="text-[10px] text-emerald-400">en route</span>
          )}
          <p className="font-mono text-[10px] text-cyan-300">
            <Countdown until={fleet.arrives_at} now={now} />
          </p>
        </div>
      </div>
    </li>
  );
}
