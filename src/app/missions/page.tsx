"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { AppShell } from "@/components/app-shell";
import { useEmpire } from "@/components/empire-provider";
import {
  acceptAgentMission,
  claimAgentMission,
  claimDailyMission,
  listAgentMissions,
  listDailyMissions,
} from "@/lib/game/actions";
import { AGENTS, formatMissionReward, type AgentId } from "@/lib/game/agents";
import {
  dailyActionHref,
  dailyActionLabel,
  type DailyMissionRow,
} from "@/lib/game/dailies";
import type { AgentMissionRow } from "@/lib/game/types";

function coords(row: { dest_galaxy: number | null; dest_system: number | null; dest_slot: number | null }): string | null {
  if (row.dest_galaxy == null || row.dest_system == null || row.dest_slot == null) return null;
  return `[${row.dest_galaxy}:${row.dest_system}:${row.dest_slot}]`;
}

function statusLabel(status: string): string {
  if (status === "offered") return "Available";
  if (status === "active") return "In progress";
  if (status === "ready") return "Complete";
  return "Collected";
}

export default function MissionsPage() {
  const { error, configured, state, refresh } = useEmpire();
  const [missions, setMissions] = useState<AgentMissionRow[] | null>(null);
  const [dailies, setDailies] = useState<DailyMissionRow[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [pendingAgent, setPendingAgent] = useState<AgentId | null>(null);
  const [pendingDaily, setPendingDaily] = useState<number | null>(null);

  const reload = useCallback(async () => {
    const [agentRows, dailyRows] = await Promise.all([listAgentMissions(), listDailyMissions()]);
    setMissions(agentRows);
    setDailies(dailyRows);
    setLoadError(null);
  }, []);

  useEffect(() => {
    if (!configured || !state) return;
    let cancelled = false;
    void reload().catch((err) => {
      if (!cancelled) setLoadError(err instanceof Error ? err.message : "Could not load missions.");
    });
    return () => {
      cancelled = true;
    };
  }, [configured, state, reload]);

  async function runAgent(agentId: AgentId, action: (id: AgentId) => Promise<AgentMissionRow[]>) {
    setPendingAgent(agentId);
    setLoadError(null);
    try {
      const rows = await action(agentId);
      setMissions(rows);
      await refresh();
    } catch (err) {
      setLoadError(err instanceof Error ? err.message : "The agent did not answer.");
    } finally {
      setPendingAgent(null);
    }
  }

  async function collectDaily(id: number) {
    setPendingDaily(id);
    setLoadError(null);
    try {
      const rows = await claimDailyMission(id);
      setDailies(rows);
      await refresh();
    } catch (err) {
      setLoadError(err instanceof Error ? err.message : "Could not collect that daily.");
    } finally {
      setPendingDaily(null);
    }
  }

  if (!configured) {
    return (
      <AppShell title="Missions">
        <p className="text-sm text-[var(--muted-fg)]">Supabase is not configured.</p>
      </AppShell>
    );
  }

  const readyDailies = dailies?.filter((row) => row.status === "ready").length ?? 0;
  const totalDailies = dailies?.length ?? 0;

  return (
    <AppShell title="Missions">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      {loadError ? <p className="mb-3 text-sm text-red-300">{loadError}</p> : null}
      {!state ? (
        <p className="text-sm text-[var(--muted-fg)]">Establishing a hold…</p>
      ) : missions == null && dailies == null && !loadError ? (
        <p className="text-sm text-[var(--muted-fg)]">Contacting agents…</p>
      ) : (
        <div className="flex flex-col gap-3">
          <section className="flex flex-col gap-3">
            <h2 className="px-1 pt-1 text-xs font-semibold tracking-wide text-[var(--muted-fg)] uppercase">
              Daily · {readyDailies}/{totalDailies || 4} ready · resets 00:00 UTC
            </h2>
            <p className="text-sm text-[var(--muted-fg)]">
              Four contracts each UTC day. Fly them, then collect. Leftovers expire at reset.
            </p>
            {(dailies ?? []).map((row) => {
              const busy = pendingDaily === row.id;
              return (
                <article key={row.id} className="sci-card p-4">
                  <p className="text-xs uppercase tracking-wide text-[var(--muted-fg)]">Daily</p>
                  <h2 className="font-[family-name:var(--font-display)] text-sm font-bold tracking-wide text-cyan-300 uppercase">
                    {row.title}
                  </h2>
                  <p className="mt-1 text-xs font-semibold uppercase tracking-wide text-[#fde68a]">
                    {statusLabel(row.status)}
                  </p>
                  <p className="mt-1 text-sm">{row.blurb}</p>
                  {coords(row) ? <p className="mt-1 font-mono text-xs text-cyan-200">{coords(row)}</p> : null}
                  <p className="mt-2 text-xs text-cyan-200">
                    Reward:{" "}
                    {formatMissionReward({
                      ore: row.reward_ore,
                      crystal: row.reward_crystal,
                      deuterium: row.reward_deuterium,
                    })}
                  </p>
                  {row.status === "active" ? (
                    <Link
                      href={dailyActionHref(row.kind)}
                      className="sci-btn sci-btn-muted mt-3 flex h-11 w-full items-center justify-center"
                    >
                      {dailyActionLabel(row.kind)}
                    </Link>
                  ) : null}
                  {row.status === "ready" ? (
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => void collectDaily(row.id)}
                      className="sci-btn mt-3 h-11 w-full"
                    >
                      Collect reward
                    </button>
                  ) : null}
                </article>
              );
            })}
          </section>
          <section className="flex flex-col gap-3">
            <h2 className="px-1 pt-2 text-xs font-semibold tracking-wide text-[var(--muted-fg)] uppercase">
              Agents
            </h2>
            <p className="text-sm text-[var(--muted-fg)]">
              Agents post contracts. Accept one, fly it from Galaxy, then collect here.
            </p>
            {AGENTS.map((agent) => {
              const row = missions?.find((m) => m.agent_id === agent.id) ?? null;
              const busy = pendingAgent === agent.id;
              return (
                <article key={agent.id} className="sci-card p-4">
                  <p className="text-xs uppercase tracking-wide text-[var(--muted-fg)]">{agent.role}</p>
                  <h2 className="font-[family-name:var(--font-display)] text-sm font-bold tracking-wide text-cyan-300 uppercase">
                    {agent.name}
                  </h2>
                  <p className="mt-1 text-sm text-[var(--muted-fg)]">{agent.blurb}</p>
                  {row ? (
                    <>
                      <p className="mt-3 text-xs font-semibold uppercase tracking-wide text-[#fde68a]">
                        {row.title} · {statusLabel(row.status)}
                      </p>
                      <p className="mt-1 text-sm">{row.blurb}</p>
                      {coords(row) ? <p className="mt-1 font-mono text-xs text-cyan-200">{coords(row)}</p> : null}
                      <p className="mt-2 text-xs text-cyan-200">
                        Reward:{" "}
                        {formatMissionReward({
                          ore: row.reward_ore,
                          crystal: row.reward_crystal,
                          deuterium: row.reward_deuterium,
                        })}
                      </p>
                      {row.status === "offered" ? (
                        <button
                          type="button"
                          disabled={busy}
                          onClick={() => void runAgent(agent.id, acceptAgentMission)}
                          className="sci-btn mt-3 h-11 w-full"
                        >
                          Accept
                        </button>
                      ) : null}
                      {row.status === "active" ? (
                        <Link
                          href="/galaxy"
                          className="sci-btn sci-btn-muted mt-3 flex h-11 w-full items-center justify-center"
                        >
                          Open galaxy
                        </Link>
                      ) : null}
                      {row.status === "ready" ? (
                        <button
                          type="button"
                          disabled={busy}
                          onClick={() => void runAgent(agent.id, claimAgentMission)}
                          className="sci-btn mt-3 h-11 w-full"
                        >
                          Collect reward
                        </button>
                      ) : null}
                    </>
                  ) : (
                    <p className="mt-3 text-sm text-[var(--muted-fg)]">No contract on file.</p>
                  )}
                </article>
              );
            })}
          </section>
        </div>
      )}
    </AppShell>
  );
}
