"use client";

import { useEmpire } from "@/components/empire-provider";
import { totalFieldsUsed } from "@/lib/game/simulate";

export function PlanetHeader({ title }: { title: string }) {
  const { state, live } = useEmpire();
  const planet = state?.planet;
  const name = (planet?.name ?? title).toUpperCase();
  const strained = Boolean(live && live.energy.factor < 1);
  const used = live ? totalFieldsUsed(live) : 0;
  const max = planet?.max_fields;

  return (
    <div className="mb-2 flex items-start justify-between gap-2">
      <div className="flex shrink-0 items-center gap-2">
        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full border border-cyan-400/50 bg-gradient-to-tr from-cyan-600 to-indigo-900 shadow-[0_0_15px_rgba(0,240,255,0.35)]">
          <svg className="globe-spin h-4 w-4 text-cyan-300" viewBox="0 0 24 24" fill="none" aria-hidden>
            <circle cx="12" cy="12" r="8" stroke="currentColor" strokeWidth="1.6" />
            <path d="M4 13c3.2-1.2 8.2-1.2 16 .4" stroke="currentColor" strokeWidth="1.6" />
            <path d="M12 4c2.2 2.4 3.2 5.2 3.2 8s-1 5.6-3.2 8c-2.2-2.4-3.2-5.2-3.2-8s1-5.6 3.2-8Z" stroke="currentColor" strokeWidth="1.6" />
          </svg>
        </div>
        <div>
          <span className="block font-[family-name:var(--font-display)] text-sm font-bold tracking-wider text-cyan-400">
            {name}
          </span>
          <div className="flex items-center gap-1 font-mono text-xs text-slate-300">
            <span className={`inline-block h-1.5 w-1.5 rounded-full ${strained ? "bg-amber-400" : "bg-emerald-400"} animate-pulse`} />
            <span>{strained ? "POWER: STRAINED" : "HOLD: NOMINAL"}</span>
          </div>
        </div>
      </div>
      {planet && live ? (
        <div className="pt-0.5 text-right font-mono text-[9px] leading-[1.2] text-cyan-200">
          <p className="whitespace-nowrap">
            [{planet.galaxy}:{planet.system}:{planet.slot}] {planet.name} · ore {Math.floor(live.orePerHour)}/h · crystal{" "}
            {Math.floor(live.crystalPerHour)}/h · deut {Math.floor(live.deuteriumPerHour ?? 0)}/h
          </p>
          <p className="text-slate-400">Fields {used}/{max}</p>
        </div>
      ) : null}
    </div>
  );
}
