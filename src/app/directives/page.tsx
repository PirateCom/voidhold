"use client";

import { AppShell } from "@/components/app-shell";
import { DirectiveCard } from "@/components/directive-card";
import { useEmpire } from "@/components/empire-provider";
import { DIRECTIVES } from "@/lib/game/directives";

export default function DirectivesPage() {
  const { error, configured, state } = useEmpire();

  if (!configured) {
    return (
      <AppShell title="Directives">
        <p className="text-sm text-[var(--muted-fg)]">Supabase is not configured.</p>
      </AppShell>
    );
  }

  return (
    <AppShell title="Directives">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      {!state ? (
        <p className="text-sm text-[var(--muted-fg)]">Establishing a hold…</p>
      ) : (
        <div className="flex flex-col gap-3">
          <p className="text-sm text-[var(--muted-fg)]">
            Officer directives for a new hold. Claim rewards in order. Mine output sliders are not in Voidhold,
            so those OGame steps are skipped.
          </p>
          {DIRECTIVES.map((spec) => (
            <DirectiveCard key={spec.id} spec={spec} />
          ))}
        </div>
      )}
    </AppShell>
  );
}
