"use client";

import Link from "next/link";
import {
  directiveComplete,
  directiveProgress,
  directiveUnlocked,
  formatDirectiveReward,
  isDirectiveClaimed,
  isDirectiveTracked,
  levelsFromHold,
  trackedDirectiveSpecs,
  objectiveMet,
  type DirectiveLevels,
  type DirectiveSpec,
} from "@/lib/game/directives";
import { useEmpire } from "@/components/empire-provider";

export function DirectiveCard({
  spec,
  compact = false,
}: {
  spec: DirectiveSpec;
  compact?: boolean;
}) {
  const { state, live, pending, claimDirective, setDirectiveTracked } = useEmpire();
  const claimed = isDirectiveClaimed(state?.empire.claimed_directives, spec.id);
  const unlocked = directiveUnlocked(state?.empire.claimed_directives, spec.id);
  const tracked = isDirectiveTracked(state?.empire.tracked_directives, spec.id);
  const levels: DirectiveLevels =
    state?.planet && state.empire
      ? levelsFromHold({
          planet: state.planet,
          empire: state.empire,
          energyOutput: live?.energy.output,
          energyDrain: live?.energy.drain,
          starType: state.star?.type,
        })
      : {};
  const { done, total } = directiveProgress(spec, levels);
  const complete = directiveComplete(spec, levels);
  const canCollect = unlocked && complete && !claimed && !pending;

  return (
    <article className={`sci-card p-4 ${claimed ? "opacity-70" : ""}`}>
      <div className="flex items-start justify-between gap-3">
        <div>
          <h2 className="font-[family-name:var(--font-display)] text-sm font-bold tracking-wide text-cyan-300 uppercase">
            {spec.title}
          </h2>
          <p className="mt-0.5 font-mono text-xs text-[var(--muted-fg)]">
            {claimed ? "Collected" : `${done} / ${total}`}
          </p>
        </div>
        <div className="flex shrink-0 flex-col items-end gap-1">
          {claimed ? (
            <span className="sci-btn sci-btn-quiet pointer-events-none h-9 px-3">Collected</span>
          ) : !unlocked ? (
            <span className="sci-btn sci-btn-quiet pointer-events-none h-9 px-3">Locked</span>
          ) : (
            <>
              {canCollect ? (
                <button
                  type="button"
                  className="sci-btn h-9 px-3"
                  disabled={pending}
                  onClick={() => void claimDirective(spec.id)}
                >
                  Collect reward
                </button>
              ) : null}
              {tracked ? (
                <button
                  type="button"
                  className="sci-btn sci-btn-muted h-9 px-3"
                  disabled={pending}
                  onClick={() => void setDirectiveTracked(spec.id, false)}
                >
                  Untrack
                </button>
              ) : (
                <button
                  type="button"
                  className="sci-btn sci-btn-muted h-9 px-3"
                  disabled={pending}
                  onClick={() => void setDirectiveTracked(spec.id, true)}
                >
                  Track
                </button>
              )}
            </>
          )}
        </div>
      </div>
      {compact ? null : <p className="mt-2 text-sm text-[var(--muted-fg)]">{spec.blurb}</p>}
      <p className="mt-3 text-xs uppercase tracking-wide text-[var(--muted-fg)]">Complete the following missions:</p>
      <ul className="mt-1 space-y-1 text-sm">
        {spec.objectives.map((objective) => {
          const met = claimed || objectiveMet(objective, levels);
          return (
            <li key={objective.label} className={met ? "text-emerald-300" : ""}>
              {met ? "✓ " : "○ "}
              {objective.label}
            </li>
          );
        })}
      </ul>
      <p className="mt-3 text-xs text-cyan-200">
        For completing the mission you receive: {formatDirectiveReward(spec.reward)}
      </p>
    </article>
  );
}

export function CurrentDirective() {
  const { state } = useEmpire();
  const tracked = trackedDirectiveSpecs(state?.empire.tracked_directives, state?.empire.claimed_directives);
  if (tracked.length === 0) return null;
  return (
    <div className="mb-4 flex flex-col gap-3">
      {tracked.map((spec) => (
        <DirectiveCard key={spec.id} spec={spec} compact />
      ))}
      <Link href="/directives" className="block text-center text-xs text-[var(--muted-fg)] underline">
        All directives
      </Link>
    </div>
  );
}
