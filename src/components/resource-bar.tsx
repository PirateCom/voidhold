"use client";

import { useEmpire } from "@/components/empire-provider";

function Stat({ label, value, cap, tone }: { label: string; value: string; cap?: string; tone: string }) {
  return (
    <div className="min-w-0">
      <div className="text-[10px] uppercase tracking-wide" style={{ color: tone }}>
        {label}
      </div>
      <div className="truncate font-mono text-sm text-[var(--foreground)]">
        {value}
        {cap ? <span className="text-[var(--muted-fg)]">/{cap}</span> : null}
      </div>
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
      />
      <Stat
        label="Crystal"
        value={Math.floor(live.crystal).toLocaleString()}
        cap={live.crystalCap.toLocaleString()}
        tone="var(--crystal)"
      />
      <Stat
        label="Energy"
        value={`${live.energy.output}/${live.energy.drain}`}
        tone="var(--energy)"
      />
    </div>
  );
}
