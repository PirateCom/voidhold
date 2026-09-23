"use client";

import type { ReactNode } from "react";
import { useEmpire } from "@/components/empire-provider";

function Chip({
  label,
  rate,
  rateClass = "text-emerald-400",
  value,
  icon,
  border,
  iconClass,
  labelClass,
  valueClass,
}: {
  label: string;
  rate: string;
  rateClass?: string;
  value: string;
  icon: ReactNode;
  border: string;
  iconClass: string;
  labelClass: string;
  valueClass: string;
}) {
  return (
    <div className={`flex min-w-0 items-center gap-1.5 border bg-slate-900/90 p-1 ${border}`}>
      <div className={`flex h-6 w-6 shrink-0 items-center justify-center border ${iconClass}`}>{icon}</div>
      <div className="min-w-0 flex-1">
        <div className={`flex justify-between gap-1 font-mono text-[10px] ${labelClass}`}>
          <span className="truncate">{label}</span>
          <span className={rateClass}>{rate}</span>
        </div>
        <div className={`truncate font-[family-name:var(--font-display)] text-xs font-bold ${valueClass}`}>{value}</div>
      </div>
    </div>
  );
}

export function ResourceBar() {
  const { live, state } = useEmpire();
  if (!live) {
    return <p className="mt-2 font-mono text-xs text-[var(--muted-fg)]">Awaiting telemetry…</p>;
  }

  const oreRate = `+${Math.floor(live.orePerHour).toLocaleString()}/h`;
  const crystalRate = `+${Math.floor(live.crystalPerHour).toLocaleString()}/h`;
  const solar = live.energy.output;
  const drain = live.energy.drain;
  const short = drain > solar;
  const star = state?.star.multiplier;
  const solarLabel = star && star !== 1 ? `SOL ×${star}` : "SOL";

  return (
    <div className="grid grid-cols-4 gap-1.5">
      <Chip
        label="ORE"
        rate={oreRate}
        value={Math.floor(live.ore).toLocaleString()}
        border="border-slate-700/60"
        iconClass="border-zinc-500/40 bg-zinc-800 text-slate-300"
        labelClass="text-slate-400"
        valueClass="text-slate-100"
        icon={<Cubes />}
      />
      <Chip
        label="CRY"
        rate={crystalRate}
        value={Math.floor(live.crystal).toLocaleString()}
        border="border-cyan-900/60"
        iconClass="border-cyan-400/40 bg-cyan-950 text-cyan-300"
        labelClass="text-cyan-400/70"
        valueClass="text-cyan-100"
        icon={<Gem />}
      />
      <Chip
        label="DEUT"
        rate="+0/h"
        value={Math.floor(live.deuterium ?? 0).toLocaleString()}
        border="border-blue-900/60"
        iconClass="border-blue-400/40 bg-blue-950 text-blue-300"
        labelClass="text-blue-400/70"
        valueClass="text-blue-100"
        icon={<Flask />}
      />
      <Chip
        label={solarLabel}
        rate={`${drain}/${solar}`}
        rateClass={short ? "text-red-400" : "text-emerald-400"}
        value={String(solar)}
        border="border-amber-900/60"
        iconClass="border-amber-400/40 bg-amber-950 text-amber-300"
        labelClass="text-amber-400/70"
        valueClass="text-amber-200"
        icon={<Sun />}
      />
    </div>
  );
}

function Cubes() {
  return (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M4 7.5 8 5l4 2.5L8 10 4 7.5Zm8 0L16 5l4 2.5-4 2.5-4-2.5ZM8 11.2l4-2.5 4 2.5-4 2.5-4-2.5Zm-4 2.3 4-2.5 4 2.5v4.6l-4 2.4-4-2.4v-4.6Zm12 0 4-2.5v4.6l-4 2.4-4-2.4v-4.6l4-2.5Z" />
    </svg>
  );
}

function Gem() {
  return (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M6 4h12l3 6-9 11L3 10l3-6Zm2.2 2L6.6 9h10.8l-1.6-3H8.2ZM8 11l4 8 4-8H8Z" />
    </svg>
  );
}

function Sun() {
  return (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M19.1 4.9 17 7M7 17l-2.1 2.1" stroke="currentColor" strokeWidth="2" />
    </svg>
  );
}

function Flask() {
  return (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M9 2h6v2h-1v4.2l4.6 8.2A4 4 0 0 1 15.1 22H8.9a4 4 0 0 1-3.5-5.6L10 8.2V4H9V2Zm3 8.4-3.8 6.8c.4.5 1 .8 1.7.8h6.2c.7 0 1.3-.3 1.7-.8L12 10.4Z" />
    </svg>
  );
}
