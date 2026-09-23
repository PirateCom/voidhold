"use client";

import { AppShell } from "@/components/app-shell";
import { useEmpire } from "@/components/empire-provider";

export default function CommunicationsPage() {
  const { state, error } = useEmpire();

  return (
    <AppShell title="Communications">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      {!state ? (
        <p className="text-sm text-[var(--muted-fg)]">No empire loaded.</p>
      ) : (
        <>
          <h2 className="font-[family-name:var(--font-display)] text-xs font-semibold tracking-wide text-cyan-300 uppercase">
            Reports
          </h2>
          {state.reports.length === 0 ? (
            <p className="mt-2 text-sm text-[var(--muted-fg)]">No battle reports yet.</p>
          ) : (
            <ul className="mt-2 flex flex-col gap-2">
              {state.reports.map((report) => (
                <li key={report.id} className="sci-card p-4">
                  <p className="font-semibold">{report.title}</p>
                  <p className="mt-1 text-sm text-[var(--muted-fg)]">{report.body}</p>
                </li>
              ))}
            </ul>
          )}
        </>
      )}
    </AppShell>
  );
}
