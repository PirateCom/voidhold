"use client";

import { AppShell } from "@/components/app-shell";
import { DirectiveCard } from "@/components/directive-card";
import { useEmpire } from "@/components/empire-provider";
import { useEffect, useRef } from "react";
import {
  DIRECTIVES,
  activeDirective,
  directiveComplete,
  directiveUnlocked,
  isDirectiveClaimed,
  levelsFromHold,
  trackedDirectiveSpecs,
} from "@/lib/game/directives";

export default function DirectivesPage() {
  const { error, configured, state, live } = useEmpire();
  const scrolled = useRef(false);

  useEffect(() => {
    if (!state || scrolled.current) return;
    const claimed = state.empire.claimed_directives;
    const tracked = trackedDirectiveSpecs(state.empire.tracked_directives, claimed)[0] ?? null;
    const levels =
      live && state.planet
        ? levelsFromHold({
            planet: state.planet,
            empire: state.empire,
            energyOutput: live.energy.output,
            energyDrain: live.energy.drain,
            starType: state.star?.type,
          })
        : null;
    const collectable =
      levels == null
        ? null
        : (DIRECTIVES.find(
            (spec) =>
              !isDirectiveClaimed(claimed, spec.id) &&
              directiveUnlocked(claimed, spec.id) &&
              directiveComplete(spec, levels),
          ) ?? null);
    const next = activeDirective(claimed);
    const target = collectable ?? tracked ?? next;
    if (!target) return;
    scrolled.current = true;
    const node = document.getElementById(`directive-${target.id}`);
    requestAnimationFrame(() => node?.scrollIntoView({ block: "start" }));
  }, [state, live]);

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
            Officer directives in order: first the beginner mines, then yards, research, small hulls and guns,
            climbing until every flyable ship and defence is on the list.
          </p>
          {DIRECTIVES.map((spec) => (
            <DirectiveCard key={spec.id} spec={spec} />
          ))}
        </div>
      )}
    </AppShell>
  );
}
