"use client";

import { AppShell } from "@/components/app-shell";
import { BuildingList } from "@/components/building-list";
import { useEmpire } from "@/components/empire-provider";
import { createClient } from "@/lib/supabase/client";
import { useRouter } from "next/navigation";

export default function PlanetPage() {
  const { state, live, error, configured, refresh, pending, resetProgress, spawnPirates } = useEmpire();
  const router = useRouter();

  async function signOut() {
    const supabase = createClient();
    if (supabase) await supabase.auth.signOut();
    router.push("/login");
    router.refresh();
  }

  if (!configured) {
    return (
      <AppShell title="Planet">
        <p className="text-sm text-[var(--muted-fg)]">
          Supabase is not configured. Copy <code>.env.local.example</code> after creating the voidhold
          project.
        </p>
      </AppShell>
    );
  }

  return (
    <AppShell title={state?.planet.name ?? "Planet"}>
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      {live && state ? (
        <>
          <p className="mb-4 text-sm text-[var(--muted-fg)]">
            [{state.planet.system}:{state.planet.slot}] {state.profile.display_name} · ore{" "}
            {Math.floor(live.orePerHour)}/h · crystal {Math.floor(live.crystalPerHour)}/h
            {live.energy.factor < 1 ? " · underpowered" : ""}
          </p>
          <BuildingList />
          <button
            type="button"
            onClick={() => void refresh()}
            className="mt-4 h-11 w-full rounded-2xl bg-[var(--muted)] text-sm font-semibold"
          >
            Sync clocks
          </button>
          <button
            type="button"
            disabled={pending}
            onClick={() => {
              if (
                !window.confirm(
                  "Reset this empire to a fresh start? Buildings, stockpiles, research, raiders, and fleets will wipe.",
                )
              ) {
                return;
              }
              void resetProgress();
            }}
            className="mt-2 h-11 w-full rounded-2xl border border-red-400/40 text-sm font-semibold text-red-300 disabled:opacity-50"
          >
            Debug: reset progress
          </button>
          <button
            type="button"
            disabled={pending}
            onClick={() => void spawnPirates()}
            className="mt-2 h-11 w-full rounded-2xl border border-amber-400/40 text-sm font-semibold text-amber-200 disabled:opacity-50"
          >
            Debug: deploy pirates
          </button>
          <button
            type="button"
            onClick={() => void signOut()}
            className="mt-2 h-11 w-full rounded-2xl text-sm text-[var(--muted-fg)]"
          >
            Sign out
          </button>
        </>
      ) : (
        <p className="text-sm text-[var(--muted-fg)]">Establishing a hold…</p>
      )}
    </AppShell>
  );
}
