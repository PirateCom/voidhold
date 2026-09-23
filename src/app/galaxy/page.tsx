"use client";

import { AppShell } from "@/components/app-shell";
import { GalaxyGrid } from "@/components/galaxy-grid";
import { useEmpire } from "@/components/empire-provider";

export default function GalaxyPage() {
  const { error } = useEmpire();
  return (
    <AppShell title="Galaxy">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      <GalaxyGrid />
    </AppShell>
  );
}
