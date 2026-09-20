"use client";

import { AppShell } from "@/components/app-shell";
import { Countdown } from "@/components/countdown";
import { useEmpire } from "@/components/empire-provider";
import { formatDuration, RAIDER_COST, researchCost, researchTimeSeconds } from "@/lib/game/catalog";
import { useState } from "react";

export default function YardsPage() {
  const { state, pending, error, research, build, now } = useEmpire();
  const [count, setCount] = useState(1);

  if (!state) {
    return (
      <AppShell title="Yards">
        <p className="text-sm text-[var(--muted-fg)]">No empire loaded.</p>
      </AppShell>
    );
  }

  const nextResearch = researchCost(state.empire.propulsion_level);
  const researching = Boolean(state.empire.research_completes_at);

  return (
    <AppShell title="Yards">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}

      <article className="rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4">
        <h2 className="font-semibold">Propulsion</h2>
        <p className="mt-1 text-xs text-[var(--muted-fg)]">
          Shortens fleet flight time. Level {state.empire.propulsion_level}.
        </p>
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

      <article className="mt-4 rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4">
        <h2 className="font-semibold">Raider</h2>
        <p className="mt-1 text-xs text-[var(--muted-fg)]">
          One hull. Cargo 5,000. Cost {RAIDER_COST.ore} ore + {RAIDER_COST.crystal} crystal. Docked:{" "}
          {state.empire.raiders}. In yard: {state.empire.raiders_queued}.
        </p>
        {state.empire.raiders_queued > 0 ? (
          <p className="mt-3 text-sm">
            Next hull <Countdown until={state.empire.raider_completes_at} now={now} />
          </p>
        ) : null}
        <label className="mt-3 block text-xs text-[var(--muted-fg)]">
          Queue
          <input
            type="number"
            min={1}
            max={20}
            value={count}
            onChange={(e) => setCount(Number(e.target.value))}
            className="mt-1 h-11 w-full rounded-2xl border border-[var(--border)] bg-[var(--background)] px-3"
          />
        </label>
        <button
          type="button"
          disabled={pending}
          onClick={() => void build(count)}
          className="mt-3 h-11 w-full rounded-2xl bg-[var(--accent)] text-sm font-semibold text-[var(--accent-fg)] disabled:opacity-50"
        >
          Build raiders
        </button>
      </article>
    </AppShell>
  );
}
