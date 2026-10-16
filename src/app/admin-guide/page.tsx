"use client";

import { useState } from "react";
import Link from "next/link";
import { AppShell } from "@/components/app-shell";
import { useEmpire } from "@/components/empire-provider";
import { debugGrantRelics, debugSpawnStellarEvent } from "@/lib/game/actions";
import { DEBUG_INFO } from "@/lib/game/debug-info";
import {
  MECHANICS_GUIDE_SECTIONS,
  RELICS,
  STELLAR_EVENTS,
  type StellarEventKind,
} from "@/lib/game/mechanics";

export default function AdminGuidePage() {
  const { state, isDebug, refresh } = useEmpire();
  const [busy, setBusy] = useState(false);
  const [feedback, setFeedback] = useState<string | null>(null);

  if (!state) {
    return (
      <AppShell title="Admin · Status & Guide">
        <p className="text-sm text-[var(--muted-fg)]">Loading empire…</p>
      </AppShell>
    );
  }

  if (!isDebug) {
    return (
      <AppShell title="Restricted">
        <div className="sci-card p-4">
          <p className="text-sm text-rose-200">Admin access only. This page is restricted to universe operators.</p>
          <Link href="/" className="sci-btn sci-btn-muted mt-3 h-11 w-full">
            Return to hold
          </Link>
        </div>
      </AppShell>
    );
  }

  const g = state.planet.galaxy;
  const s = state.planet.system;

  async function triggerEvent(kind: StellarEventKind) {
    setBusy(true);
    setFeedback(null);
    try {
      await debugSpawnStellarEvent(g, s, kind);
      await refresh();
      setFeedback(`Spawned ${kind} in system [${g}:${s}] for 3 hours.`);
    } catch (e) {
      setFeedback(e instanceof Error ? e.message : "Failed to spawn stellar event. Run migration 084 first.");
    } finally {
      setBusy(false);
    }
  }

  async function grantRelics() {
    setBusy(true);
    setFeedback(null);
    try {
      await debugGrantRelics();
      await refresh();
      setFeedback("Granted +1 of each Ancient Relic to your inventory.");
    } catch (e) {
      setFeedback(e instanceof Error ? e.message : "Failed to grant relics. Run migration 084 first.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <AppShell title="Admin · Status & Guide">
      <div className="flex flex-col gap-3">
        <article className="sci-card p-4">
          <p className="text-[10px] uppercase tracking-[0.2em] text-cyan-300">Operator Reference (Admin Only)</p>
          <h2 className="mt-1 font-[family-name:var(--font-display)] text-base font-bold uppercase">
            Voidhold Expansion Mechanics
          </h2>
          <p className="mt-1 text-xs text-[var(--muted-fg)]">
            Visible only to admin operators. Combines live build status with the expansion mechanics guide and quick
            operator test triggers.
          </p>
          <div className="mt-3 grid grid-cols-2 gap-2">
            <button
              type="button"
              disabled={busy}
              onClick={() => void triggerEvent("solar_flare")}
              className="sci-btn sci-btn-warn h-10 px-2 text-[10px]"
            >
              Flare [{g}:{s}]
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={() => void triggerEvent("ion_storm")}
              className="sci-btn sci-btn-warn h-10 px-2 text-[10px]"
            >
              Ion Storm [{g}:{s}]
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={() => void triggerEvent("meteor_shower")}
              className="sci-btn sci-btn-warn h-10 px-2 text-[10px]"
            >
              Meteors [{g}:{s}]
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={() => void grantRelics()}
              className="sci-btn h-10 px-2 text-[10px]"
            >
              Grant +1 All Relics
            </button>
          </div>
          {feedback ? <p className="mt-2 text-xs text-cyan-200">{feedback}</p> : null}
        </article>

        {MECHANICS_GUIDE_SECTIONS.map((section) => (
          <article key={section.id} className="sci-card p-4">
            <h3 className="font-[family-name:var(--font-display)] text-sm font-bold text-cyan-300 uppercase">
              {section.title}
            </h3>
            <p className="mt-1.5 text-xs text-slate-200">{section.summary}</p>
            <ul className="mt-2.5 list-disc space-y-1.5 pl-4 text-xs text-[var(--muted-fg)]">
              {section.details.map((line) => (
                <li key={line}>{line}</li>
              ))}
            </ul>
          </article>
        ))}

        <article className="sci-card p-4">
          <h3 className="font-[family-name:var(--font-display)] text-sm font-bold text-amber-300 uppercase">
            Stellar Weather Catalog
          </h3>
          <div className="mt-2 space-y-2">
            {STELLAR_EVENTS.map((ev) => (
              <div key={ev.id} className="rounded border border-slate-800 bg-slate-950/60 p-2.5">
                <div className="flex items-center justify-between gap-2">
                  <span className="text-xs font-semibold">{ev.name}</span>
                  <span className="font-mono text-[10px] text-amber-300">{ev.badge}</span>
                </div>
                <p className="mt-1 text-xs text-[var(--muted-fg)]">{ev.blurb}</p>
              </div>
            ))}
          </div>
        </article>

        <article className="sci-card p-4">
          <h3 className="font-[family-name:var(--font-display)] text-sm font-bold text-cyan-300 uppercase">
            Ancient Relics Catalog (Command Core)
          </h3>
          <div className="mt-2 space-y-2">
            {RELICS.map((r) => (
              <div key={r.id} className="rounded border border-slate-800 bg-slate-950/60 p-2.5">
                <div className="flex items-center justify-between gap-2">
                  <span className="text-xs font-semibold">{r.name}</span>
                  <span className="font-mono text-[10px] text-cyan-300">{r.badge}</span>
                </div>
                <p className="mt-1 text-xs text-[var(--muted-fg)]">{r.blurb}</p>
              </div>
            ))}
          </div>
        </article>

        <article className="sci-card p-4">
          <div className="flex items-start justify-between gap-3">
            <div>
              <h3 className="font-[family-name:var(--font-display)] text-sm font-bold text-cyan-300 uppercase">
                {DEBUG_INFO.title}
              </h3>
              <p className="mt-0.5 text-xs uppercase tracking-wide text-emerald-300">
                Playable · {DEBUG_INFO.percent}% of full Voidhold design
              </p>
            </div>
          </div>
          <p className="mt-2 text-xs text-slate-200">{DEBUG_INFO.headline}</p>
          <h4 className="mt-4 text-xs font-semibold tracking-wide text-[var(--muted-fg)] uppercase">
            In the build
          </h4>
          <ul className="mt-2 list-disc space-y-1.5 pl-4 text-xs text-[var(--muted-fg)]">
            {DEBUG_INFO.working.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
          <h4 className="mt-4 text-xs font-semibold tracking-wide text-[var(--muted-fg)] uppercase">
            Not built yet
          </h4>
          <ul className="mt-2 list-disc space-y-1.5 pl-4 text-xs text-[var(--muted-fg)]">
            {DEBUG_INFO.missing.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
        </article>

        <Link href="/profile" className="sci-btn sci-btn-muted mb-4 h-11 w-full">
          Back to Commander
        </Link>
      </div>
    </AppShell>
  );
}
