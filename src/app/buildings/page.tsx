"use client";

import Link from "next/link";
import { AppShell } from "@/components/app-shell";
import { BuildingList } from "@/components/building-list";
import { useEmpire } from "@/components/empire-provider";
import { createClient } from "@/lib/supabase/client";
import { useRouter } from "next/navigation";

export default function BuildingsPage() {
  const { state, live, error, configured, refresh, pending, resetProgress, spawnPirates, fillResources } = useEmpire();
  const router = useRouter();

  async function signOut() {
    const supabase = createClient();
    if (supabase) await supabase.auth.signOut();
    router.push("/login");
    router.refresh();
  }

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
          <BuildingList />
          <Link
            href="/"
            className="sci-btn sci-btn-muted mt-4 flex h-11 w-full items-center justify-center"
          >
            Resources
          </Link>
          <button
            type="button"
            onClick={() => void refresh()}
            className="sci-btn sci-btn-muted mt-2 h-11 w-full"
          >
            Sync clocks
          </button>
          <button
            type="button"
            disabled={pending}
            onClick={() => {
              if (
                !window.confirm(
                  "Reset this empire to a fresh start? Buildings, stockpiles, research, small cargo, and fleets will wipe.",
                )
              ) {
                return;
              }
              void resetProgress();
            }}
            className="sci-btn sci-btn-danger mt-2 h-11 w-full"
          >
            Debug: reset progress
          </button>
          <button
            type="button"
            disabled={pending}
            onClick={() => void fillResources()}
            className="sci-btn sci-btn-warn mt-2 h-11 w-full"
          >
            Debug: fill resources
          </button>
          <button
            type="button"
            disabled={pending}
            onClick={() => void spawnPirates()}
            className="sci-btn sci-btn-warn mt-2 h-11 w-full"
          >
            Debug: deploy pirates
          </button>
          <button
            type="button"
            onClick={() => void signOut()}
            className="sci-btn sci-btn-quiet mt-2 h-11 w-full"
          >
            Sign out
          </button>
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
