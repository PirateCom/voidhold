"use client";

import Link from "next/link";
import {
  DIRECTIVES,
  activeDirective,
  directiveComplete,
  directiveProgress,
  directiveUnlocked,
  formatDirectiveReward,
  isDirectiveClaimed,
  levelsFromPlanet,
  objectiveMet,
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
  const { state, live, pending, claimDirective } = useEmpire();
  const claimed = isDirectiveClaimed(state?.empire.claimed_directives, spec.id);
  const unlocked = directiveUnlocked(state?.empire.claimed_directives, spec.id);
  const levels = levelsFromPlanet({
    ore_mine: state?.planet.ore_mine ?? 0,
    crystal_mine: state?.planet.crystal_mine ?? 0,
    deuterium_extractor: state?.planet.deuterium_extractor,
    power_plant: state?.planet.power_plant ?? 0,
    fusion_reactor: state?.planet.fusion_reactor,
    ore_storage: state?.planet.ore_storage,
    crystal_storage: state?.planet.crystal_storage,
    deuterium_storage: state?.planet.deuterium_storage,
    energyOutput: live?.energy.output,
    energyDrain: live?.energy.drain,
    starType: state?.star.type,
  });
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
        {claimed ? (
          <span className="sci-btn sci-btn-quiet pointer-events-none h-9 px-3">Collected</span>
        ) : !unlocked ? (
          <span className="sci-btn sci-btn-quiet pointer-events-none h-9 px-3">Locked</span>
        ) : canCollect ? (
          <button
            type="button"
            className="sci-btn h-9 px-3"
            disabled={pending}
            onClick={() => void claimDirective(spec.id)}
          >
            Collect reward
          </button>
        ) : (
          <Link href="/" className="sci-btn sci-btn-muted flex h-9 items-center px-3">
            Track
          </Link>
        )}
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
  const current = activeDirective(state?.empire.claimed_directives);
  if (!current) {
    const allClaimed = DIRECTIVES.every((d) => isDirectiveClaimed(state?.empire.claimed_directives, d.id));
    if (!allClaimed) return null;
    return (
      <p className="mb-3 text-center text-xs text-[var(--muted-fg)]">
        All beginner directives collected.{" "}
        <Link href="/directives" className="underline">
          Review
        </Link>
      </p>
    );
  }
  return (
    <div className="mb-4">
      <DirectiveCard spec={current} compact />
      <Link href="/directives" className="mt-2 block text-center text-xs text-[var(--muted-fg)] underline">
        All directives
      </Link>
    </div>
  );
}
