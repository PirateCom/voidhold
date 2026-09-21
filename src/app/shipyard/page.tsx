"use client";

import { AppShell } from "@/components/app-shell";
import { Countdown } from "@/components/countdown";
import { useEmpire } from "@/components/empire-provider";
import { StripedProgress, TimedStripedProgress } from "@/components/striped-progress";
import { RAIDER_BUILD_SECONDS, RAIDER_COST } from "@/lib/game/catalog";
import { useState } from "react";

export default function ShipyardPage() {
  const { state, pending, error, build, now } = useEmpire();
  const [count, setCount] = useState(1);

  if (!state) {
    return (
      <AppShell title="Shipyard">
        <p className="text-sm text-[var(--muted-fg)]">No empire loaded.</p>
      </AppShell>
    );
  }

  return (
    <AppShell title="Shipyard">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}

      <article className="rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4">
        <h2 className="font-semibold">Raider</h2>
        <p className="mt-1 text-xs text-[var(--muted-fg)]">
          One hull. Cargo 5,000. Cost {RAIDER_COST.ore} ore + {RAIDER_COST.crystal} crystal. Docked:{" "}
          {state.empire.raiders}. In yard: {state.empire.raiders_queued}.
        </p>
        {state.empire.raiders_queued > 0 ? (
          <TimedStripedProgress
            className="mt-3"
            until={state.empire.raider_completes_at}
            durationMs={RAIDER_BUILD_SECONDS * 1000}
            now={now}
            tone="var(--ore)"
            label="Raider hull"
          />
        ) : (
          <StripedProgress className="mt-3" value={0} tone="var(--ore)" animated={false} disabled label="Raider" />
        )}
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
