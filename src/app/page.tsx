"use client";

import { AppShell } from "@/components/app-shell";
import { ResourceBuildings } from "@/components/building-list";
import { useEmpire } from "@/components/empire-provider";
import { starLabel } from "@/lib/game/catalog";
import { totalFieldsUsed } from "@/lib/game/simulate";

function Fact({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between gap-4 border-b border-[var(--border)] py-3">
      <dt className="text-sm text-[var(--muted-fg)]">{label}</dt>
      <dd className="text-right text-sm font-semibold">{value}</dd>
    </div>
  );
}

export default function OverviewPage() {
  const { state, live, error, configured } = useEmpire();

  if (!configured) {
    return (
      <AppShell title="Resources">
        <p className="text-sm text-[var(--muted-fg)]">
          Supabase is not configured. Copy <code>.env.local.example</code> after creating the voidhold
          project.
        </p>
      </AppShell>
    );
  }

  const planet = state?.planet;
  const ready = Boolean(state?.star && planet && planet.diameter_km != null && planet.max_fields != null);
  const used = live ? totalFieldsUsed(live) : 0;

  return (
    <AppShell title="Resources">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      {ready && state && planet ? (
        <>
          <p className="mb-2 text-xs uppercase tracking-[0.2em] text-[var(--muted-fg)]">
            {state.profile.display_name}
          </p>
          <dl className="sci-card mb-4 px-4">
            <Fact
              label="Diameter"
              value={`${planet.diameter_km.toLocaleString()} km (${used}/${planet.max_fields})`}
            />
            <Fact label="Temperature" value={`${planet.temp_min}°C to ${planet.temp_max}°C`} />
            <Fact label="Position" value={`[${planet.galaxy}:${planet.system}:${planet.slot}]`} />
            <Fact
              label="Points"
              value={`${state.rank.points.toLocaleString()} (Place ${state.rank.place.toLocaleString()} of ${state.rank.total.toLocaleString()})`}
            />
            <Fact
              label="Star"
              value={`${starLabel(state.star.type)} · solar ×${state.star.multiplier}`}
            />
          </dl>
          <ResourceBuildings />
        </>
      ) : state ? (
        <p className="text-sm text-[var(--muted-fg)]">
          The galaxy map is not on the database yet. Run{" "}
          <code>supabase/migrations/006_galaxy.sql</code> in the Supabase SQL editor, then reload.
        </p>
      ) : (
        <p className="text-sm text-[var(--muted-fg)]">Establishing a hold…</p>
      )}
    </AppShell>
  );
}
