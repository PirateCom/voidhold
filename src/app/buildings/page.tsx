"use client";

import { AppShell } from "@/components/app-shell";
import { BuildingList } from "@/components/building-list";
import { CurrentDirective } from "@/components/directive-card";
import { useEmpire } from "@/components/empire-provider";

export default function BuildingsPage() {
  const { state, live, error, configured } = useEmpire();

  if (!configured) {
    return (
      <AppShell title="Facilities">
        <p className="text-sm text-[var(--muted-fg)]">
          Supabase is not configured. Copy <code>.env.local.example</code> after creating the voidhold
          project.
        </p>
      </AppShell>
    );
  }

  return (
    <AppShell title="Facilities">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      {live && state?.star ? (
        <>
          <CurrentDirective />
          <BuildingList />
        </>
      ) : state && !state.star ? (
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
