"use client";

import { AppShell } from "@/components/app-shell";
import { useEmpire } from "@/components/empire-provider";
import { REPORT_TTL_DAYS } from "@/lib/game/catalog";

export default function CommunicationsPage() {
  const { state, error, pending, deleteReport } = useEmpire();

  return (
    <AppShell title="Comms">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      {!state ? (
        <p className="text-sm text-[var(--muted-fg)]">No empire loaded.</p>
      ) : (
        <>
          <h2 className="font-[family-name:var(--font-display)] text-xs font-semibold tracking-wide text-cyan-300 uppercase">
            Reports
          </h2>
          <p className="mt-1 text-xs text-[var(--muted-fg)]">
            Reports stay for {REPORT_TTL_DAYS} days, then they are deleted. You can delete one sooner.
          </p>
          {state.reports.length === 0 ? (
            <p className="mt-2 text-sm text-[var(--muted-fg)]">No reports yet.</p>
          ) : (
            <ul className="mt-2 flex flex-col gap-2">
              {state.reports.map((report) => (
                <li key={report.id} className="sci-card p-4">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="font-semibold">{report.title}</p>
                      <p className="mt-0.5 font-mono text-xs text-[var(--muted-fg)]">
                        {new Date(report.created_at).toLocaleString()}
                      </p>
                    </div>
                    <button
                      type="button"
                      className="sci-btn sci-btn-muted h-9 shrink-0 px-3"
                      disabled={pending}
                      onClick={() => void deleteReport(report.id)}
                    >
                      Delete
                    </button>
                  </div>
                  <p className="mt-2 whitespace-pre-wrap text-sm text-[var(--muted-fg)]">{report.body}</p>
                </li>
              ))}
            </ul>
          )}
        </>
      )}
    </AppShell>
  );
}
