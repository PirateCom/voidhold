"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { AppShell } from "@/components/app-shell";
import { useEmpire } from "@/components/empire-provider";
import { acceptAgentMission, claimAgentMission, listAgentMissions } from "@/lib/game/actions";
import { AGENTS, formatMissionReward, type AgentId } from "@/lib/game/agents";
import type { AgentMissionRow } from "@/lib/game/types";

function coords(row: AgentMissionRow): string | null {
  if (row.dest_galaxy == null || row.dest_system == null || row.dest_slot == null) return null;
  return `[${row.dest_galaxy}:${row.dest_system}:${row.dest_slot}]`;
}

function statusLabel(row: AgentMissionRow): string {
  if (row.status === "offered") return "Available";
  if (row.status === "active") return "In progress";
  if (row.status === "ready") return "Complete";
  return "Collected";
}

export default function MissionsPage() {
  const { error, configured, state, refresh } = useEmpire();
  const [missions, setMissions] = useState<AgentMissionRow[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [pendingAgent, setPendingAgent] = useState<AgentId | null>(null);

  const reload = useCallback(async () => {
    const rows = await listAgentMissions();
    setMissions(rows);
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

  async function run(agentId: AgentId, action: (id: AgentId) => Promise<AgentMissionRow[]>) {
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

  if (!configured) {
    return (
      <AppShell title="Missions">
        <p className="text-sm text-[var(--muted-fg)]">Supabase is not configured.</p>
      </AppShell>
    );
  }

  return (
    <AppShell title="Missions">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      {loadError ? <p className="mb-3 text-sm text-red-300">{loadError}</p> : null}
      {!state ? (
        <p className="text-sm text-[var(--muted-fg)]">Establishing a hold…</p>
      ) : missions == null && !loadError ? (
        <p className="text-sm text-[var(--muted-fg)]">Contacting agents…</p>
      ) : (
        <div className="flex flex-col gap-3">
          <p className="rounded border border-amber-400/40 bg-amber-950/30 px-3 py-2 text-xs font-semibold uppercase tracking-wide text-amber-200">
            WIP · Missions are a work in progress. More contracts are coming.
          </p>
          <p className="text-sm text-[var(--muted-fg)]">
            Agents post contracts. Accept one, fly it from Galaxy, then collect ore, crystal, and deuterium here.
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
                      {row.title} · {statusLabel(row)}
                    </p>
                    <p className="mt-1 text-sm">{row.blurb}</p>
                    {coords(row) ? (
                      <p className="mt-1 font-mono text-xs text-cyan-200">{coords(row)}</p>
                    ) : null}
                    <p className="mt-2 text-xs text-cyan-200">
                      Reward: {formatMissionReward({
                        ore: row.reward_ore,
                        crystal: row.reward_crystal,
                        deuterium: row.reward_deuterium,
                      })}
                    </p>
                    {row.status === "offered" ? (
                      <button
                        type="button"
                        disabled={busy}
                        onClick={() => void run(agent.id, acceptAgentMission)}
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
                        onClick={() => void run(agent.id, claimAgentMission)}
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
        </div>
      )}
    </AppShell>
  );
}
