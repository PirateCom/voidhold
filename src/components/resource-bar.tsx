"use client";

import { StripedProgress } from "@/components/striped-progress";
import { useEmpire } from "@/components/empire-provider";

function Stat({
  label,
  value,
  cap,
  tone,
  capClassName,
  fill,
  barTone,
}: {
  label: string;
  value: string;
  cap?: string;
  tone: string;
  capClassName?: string;
  fill: number;
  barTone?: string;
}) {
  return (
    <div className="min-w-0">
      <div className="text-[10px] uppercase tracking-wide" style={{ color: tone }}>
        {label}
      </div>
      <div className="truncate font-mono text-sm text-[var(--foreground)]">
        {value}
        {cap ? <span className={capClassName ?? "text-[var(--muted-fg)]"}>/{cap}</span> : null}
      </div>
      <StripedProgress className="mt-1.5" size="sm" value={fill} tone={barTone ?? tone} label={label} />
    </div>
  );
}

export function ResourceBar() {
  const { live, state } = useEmpire();
  if (!live || !state) {
    return <p className="mt-2 text-xs text-[var(--muted-fg)]">Awaiting telemetry…</p>;
  }

  return (
    <div className="mt-3 grid grid-cols-3 gap-2">
      <Stat
        label="Ore"
        value={Math.floor(live.ore).toLocaleString()}
        cap={live.oreCap.toLocaleString()}
        tone="var(--ore)"
        fill={live.oreCap > 0 ? live.ore / live.oreCap : 0}
      />
      <Stat
        label="Crystal"
        value={Math.floor(live.crystal).toLocaleString()}
        cap={live.crystalCap.toLocaleString()}
        tone="var(--crystal)"
        fill={live.crystalCap > 0 ? live.crystal / live.crystalCap : 0}
      />
      <Stat
        label="Energy"
        value={String(live.energy.drain)}
        cap={String(live.energy.output)}
        tone="var(--energy)"
        capClassName={
          live.energy.drain > live.energy.output ? "text-red-400" : "text-[var(--muted-fg)]"
        }
        fill={
          live.energy.output <= 0
            ? live.energy.drain > 0
              ? 1
              : 0
            : Math.min(1, live.energy.drain / live.energy.output)
        }
        barTone={live.energy.drain > live.energy.output ? "#f87171" : "var(--energy)"}
      />
    </div>
  );
}
