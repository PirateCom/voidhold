"use client";

import { AppShell } from "@/components/app-shell";
import { Countdown } from "@/components/countdown";
import { useEmpire } from "@/components/empire-provider";
import { SpriteThumb } from "@/components/sprite-thumb";
import { StripedProgress, TimedStripedProgress } from "@/components/striped-progress";
import {
  RESEARCHES,
  RESEARCH_GROUPS,
  formatDuration,
  researchTechCost,
  researchTimeSeconds,
  unmetResearch,
  type ResearchId,
} from "@/lib/game/catalog";
import type { EmpireRow } from "@/lib/game/types";

function levelOf(id: ResearchId, empire: EmpireRow): number {
  if (id === "combustion_drive") return empire.propulsion_level ?? 0;
  return empire[id] ?? 0;
}

export default function ResearchPage() {
  const { state, pending, error, research, now } = useEmpire();

  if (!state) {
    return (
      <AppShell title="Research">
        <p className="text-sm text-[var(--muted-fg)]">No empire loaded.</p>
      </AppShell>
    );
  }

  const active = state.empire.research_tech ?? (state.empire.research_completes_at ? "combustion_drive" : null);
  const labBusy = Boolean(state.empire.research_completes_at);

  return (
    <AppShell title="Research">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      <p className="mb-3 text-xs text-[var(--muted-fg)]">
        Costs follow the OGame wiki. Deuterium is listed and is not taken from the planet. Research-lab levels are
        recorded on each technology and are not required here.
      </p>
      <div className="flex flex-col gap-3">
        {RESEARCH_GROUPS.map((group) => (
          <section key={group.id} className="flex flex-col gap-3">
            <h2 className="px-1 pt-2 text-xs font-semibold tracking-wide text-[var(--muted-fg)] uppercase">
              {group.title}
            </h2>
            {RESEARCHES.filter((tech) => tech.group === group.id).map((tech) => {
              const level = levelOf(tech.id, state.empire);
              const cost = researchTechCost(tech.id, level);
              const missing = unmetResearch(tech.id, (id) => levelOf(id, state.empire));
              const thisBusy = labBusy && active === tech.id;
              return (
                <article key={tech.id} className="sci-card p-4">
                  <div className="flex items-start gap-3">
                    <SpriteThumb id={tech.id} />
                    <div className="min-w-0 flex-1">
                      <div className="flex items-start justify-between gap-3">
                        <h2 className="font-semibold">{tech.name}</h2>
                        <span className="sci-badge">L{level}</span>
                      </div>
                      <p className="mt-1 text-xs text-[var(--muted-fg)]">{tech.blurb}</p>
                    </div>
                  </div>
                  {thisBusy ? (
                    <TimedStripedProgress
                      className="mt-3"
                      until={state.empire.research_completes_at}
                      durationMs={researchTimeSeconds(level) * 1000}
                      now={now}
                      tone="var(--crystal)"
                      label={tech.name}
                    />
                  ) : (
                    <StripedProgress
                      className="mt-3"
                      value={0}
                      tone="var(--crystal)"
                      animated={false}
                      disabled
                      label={tech.name}
                    />
                  )}
                  <p className="mt-3 text-xs text-[var(--muted-fg)]">
                    Next: {cost.ore.toLocaleString()} ore · {cost.crystal.toLocaleString()} crystal ·{" "}
                    {cost.deuterium.toLocaleString()} deut
                    {tech.energy ? ` · ${tech.energy.toLocaleString()} energy` : ""} · {formatDuration(researchTimeSeconds(level))}
                    {" · "}lab {tech.lab}
                  </p>
                  {missing.length > 0 ? (
                    <p className="mt-1 text-xs text-amber-200">
                      Needs {missing.map((req) => `${req.name} ${req.level}`).join(", ")}.
                    </p>
                  ) : null}
                  {thisBusy ? (
                    <p className="mt-3 text-sm">
                      Researching… <Countdown until={state.empire.research_completes_at} now={now} />
                    </p>
                  ) : null}
                  <button
                    type="button"
                    disabled={pending || missing.length > 0 || (labBusy && !thisBusy)}
                    onClick={() => void research(tech.id)}
                    className="sci-btn mt-3 h-11 w-full"
                  >
                    {labBusy && !thisBusy ? "Lab occupied" : "Research"}
                  </button>
                </article>
              );
            })}
          </section>
        ))}
      </div>
    </AppShell>
  );
}
