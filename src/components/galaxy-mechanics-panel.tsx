"use client";

import { useCallback, useEffect, useState } from "react";
import { Countdown } from "@/components/countdown";
import { useEmpire } from "@/components/empire-provider";
import { StripedProgress } from "@/components/striped-progress";
import { loadMechanicsState, strikePirateStronghold } from "@/lib/game/actions";
import { SHIPS } from "@/lib/game/catalog";
import {
  stellarEventSpec,
  type EmpireMechanicsState,
  type PirateStrongholdRow,
} from "@/lib/game/mechanics";

const COMBAT_SHIP_IDS = [
  "light_fighter",
  "heavy_fighter",
  "cruiser",
  "battleship",
  "battlecruiser",
  "bomber",
  "destroyer",
  "reaper",
] as const;

export function GalaxyMechanicsPanel({
  galaxy,
  system,
  onJump,
  onStrongholdsChange,
}: {
  galaxy: number;
  system: number;
  onJump: (g: number, s: number) => void;
  onStrongholdsChange?: (rows: PirateStrongholdRow[]) => void;
}) {
  const { state, configured, now, refresh } = useEmpire();
  const [mechanics, setMechanics] = useState<EmpireMechanicsState | null>(null);
  const [strikingId, setStrikingId] = useState<number | null>(null);
  const [statusMsg, setStatusMsg] = useState<string | null>(null);

  const reload = useCallback(async () => {
    const next = await loadMechanicsState();
    setMechanics(next);
    onStrongholdsChange?.(next.strongholds.filter((sh) => sh.galaxy === galaxy && sh.system === system));
  }, [galaxy, system, onStrongholdsChange]);

  useEffect(() => {
    if (!configured || !state) return;
    void reload();
  }, [configured, state?.server_now, galaxy, system, reload]);

  if (!state || !mechanics) return null;

  const localEvent = mechanics.stellar_events.find(
    (ev) => ev.galaxy === galaxy && ev.system === system,
  );
  const localSpec = stellarEventSpec(localEvent?.kind);
  const localStrongholds = mechanics.strongholds.filter(
    (sh) => sh.galaxy === galaxy && sh.system === system,
  );

  const dockedCombatShips: Record<string, number> = {};
  let totalCombatShips = 0;
  for (const id of COMBAT_SHIP_IDS) {
    const count = state.empire.ships?.[id] ?? 0;
    if (count > 0) {
      dockedCombatShips[id] = count;
      totalCombatShips += count;
    }
  }

  async function onStrike(sh: PirateStrongholdRow) {
    setStrikingId(sh.id);
    setStatusMsg(null);
    try {
      const next = await strikePirateStronghold(sh.id, dockedCombatShips);
      setMechanics(next);
      onStrongholdsChange?.(next.strongholds.filter((row) => row.galaxy === galaxy && row.system === system));
      await refresh();
      setStatusMsg(`Strike completed against ${sh.name} at [${sh.galaxy}:${sh.system}:${sh.slot}]. Check Comms for your bounty report.`);
    } catch (e) {
      setStatusMsg(e instanceof Error ? e.message : "Could not launch stronghold strike.");
    } finally {
      setStrikingId(null);
    }
  }

  return (
    <div className="mt-3 flex flex-col gap-2">
      {mechanics.stellar_events.length > 0 ? (
        <div className="flex flex-wrap items-center gap-1.5 text-xs">
          <span className="text-[10px] uppercase tracking-wider text-[var(--muted-fg)]">
            Active Star Weather:
          </span>
          {mechanics.stellar_events.map((ev) => {
            const spec = stellarEventSpec(ev.kind);
            const activeHere = ev.galaxy === galaxy && ev.system === system;
            return (
              <button
                key={ev.id}
                type="button"
                onClick={() => onJump(ev.galaxy, ev.system)}
                className={`sci-btn h-7 px-2.5 text-[10px] ${
                  activeHere ? "sci-btn-warn" : "sci-btn-muted"
                }`}
              >
                [{ev.galaxy}:{ev.system}] {spec?.name ?? ev.kind}
              </button>
            );
          })}
        </div>
      ) : null}

      {localEvent && localSpec ? (
        <article className="sci-card sci-card-fleet-amber p-3">
          <div className="flex items-center justify-between gap-2">
            <div>
              <p className="text-[10px] font-semibold tracking-wider text-amber-300 uppercase">
                System Weather Active
              </p>
              <h3 className="font-[family-name:var(--font-display)] text-xs font-bold text-amber-100 uppercase">
                {localSpec.name}
              </h3>
            </div>
            <span className="sci-badge">{localSpec.badge}</span>
          </div>
          <p className="mt-1 text-xs text-[var(--muted-fg)]">{localSpec.blurb}</p>
          <p className="mt-1.5 font-mono text-xs text-amber-200">
            Ends in <Countdown until={localEvent.ends_at} now={now} />
          </p>
        </article>
      ) : null}

      {localStrongholds.map((sh) => {
        const hullFraction = sh.max_hull > 0 ? sh.current_hull / sh.max_hull : 0;
        const shipList = Object.entries(sh.ships)
          .filter(([, n]) => n > 0)
          .map(([id, n]) => `${n} ${SHIPS.find((s) => s.id === id)?.name ?? id}`)
          .join(" · ");
        return (
          <article key={sh.id} className="sci-card sci-card-danger p-3.5">
            <div className="flex items-start justify-between gap-2">
              <div>
                <p className="text-[10px] font-semibold tracking-wider text-rose-300 uppercase">
                  Pirate Stronghold · Slot [{sh.galaxy}:{sh.system}:{sh.slot}]
                </p>
                <h3 className="font-[family-name:var(--font-display)] text-sm font-bold text-rose-100 uppercase">
                  {sh.name} (Tier {sh.tier})
                </h3>
              </div>
              <span className="sci-badge">
                {Math.round(hullFraction * 100)}% HULL
              </span>
            </div>
            <StripedProgress
              className="mt-2"
              value={hullFraction}
              tone="#f43f5e"
              animated={false}
              label={`${sh.name} hull integrity`}
            />
            <p className="mt-2 font-mono text-xs text-slate-200">
              Hull {sh.current_hull.toLocaleString()} / {sh.max_hull.toLocaleString()} · Despawns in{" "}
              <Countdown until={sh.expires_at} now={now} />
            </p>
            {shipList ? (
              <p className="mt-1 text-xs text-[var(--muted-fg)]">Garrison: {shipList}</p>
            ) : null}
            <p className="mt-1 text-xs text-amber-200">
              Vault Jackpot: {sh.vault_ore.toLocaleString()} ore · {sh.vault_crystal.toLocaleString()} crystal ·{" "}
              {sh.vault_deuterium.toLocaleString()} deut + Ancient Relic on final blow
            </p>
            <button
              type="button"
              disabled={strikingId === sh.id || totalCombatShips < 1}
              onClick={() => void onStrike(sh)}
              className="sci-btn sci-btn-danger mt-3 h-11 w-full"
            >
              {strikingId === sh.id
                ? "Engaging stronghold…"
                : totalCombatShips < 1
                  ? "Need docked combat ships"
                  : `Strike stronghold (${totalCombatShips} combat ship${totalCombatShips === 1 ? "" : "s"})`}
            </button>
          </article>
        );
      })}

      {statusMsg ? <p className="text-xs text-cyan-200">{statusMsg}</p> : null}
    </div>
  );
}
