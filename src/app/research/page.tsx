"use client";

import { AppShell } from "@/components/app-shell";
import { Countdown } from "@/components/countdown";
import { useEmpire } from "@/components/empire-provider";
import { StripedProgress, TimedStripedProgress } from "@/components/striped-progress";
import { formatDuration, researchCost, researchTimeSeconds } from "@/lib/game/catalog";

export default function ResearchPage() {
  const { state, pending, error, research, now } = useEmpire();

  if (!state) {
    return (
      <AppShell title="Research">
        <p className="text-sm text-[var(--muted-fg)]">No empire loaded.</p>
      </AppShell>
    );
  }

  const nextResearch = researchCost(state.empire.propulsion_level);
  const researching = Boolean(state.empire.research_completes_at);

  return (
    <AppShell title="Research">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}

      <article className="rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4">
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 className="font-semibold">Propulsion</h2>
            <p className="mt-1 text-xs text-[var(--muted-fg)]">Shortens fleet flight time.</p>
          </div>
          <span className="rounded-full bg-[var(--muted)] px-2 py-1 font-mono text-xs">
            L{state.empire.propulsion_level}
          </span>
        </div>
        {researching ? (
          <TimedStripedProgress
            className="mt-3"
            until={state.empire.research_completes_at}
            durationMs={researchTimeSeconds(state.empire.propulsion_level) * 1000}
            now={now}
            label="Propulsion research"
          />
        ) : (
          <StripedProgress
            className="mt-3"
            value={0}
            tone="var(--crystal)"
            animated={false}
            disabled
            label="Propulsion"
          />
        )}
        <p className="mt-3 text-xs text-[var(--muted-fg)]">
          Next: {nextResearch.ore.toLocaleString()} ore · {nextResearch.crystal.toLocaleString()} crystal ·{" "}
          {formatDuration(researchTimeSeconds(state.empire.propulsion_level))}
        </p>
        {researching ? (
          <p className="mt-3 text-sm">
            Researching… <Countdown until={state.empire.research_completes_at} now={now} />
          </p>
        ) : (
          <button
            type="button"
            disabled={pending}
            onClick={() => void research()}
            className="mt-3 h-11 w-full rounded-2xl bg-[var(--accent)] text-sm font-semibold text-[var(--accent-fg)] disabled:opacity-50"
          >
            Research
          </button>
        )}
      </article>
    </AppShell>
  );
}
