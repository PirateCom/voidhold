"use client";

import { AppShell } from "@/components/app-shell";
import { Countdown } from "@/components/countdown";
import { useEmpire } from "@/components/empire-provider";

export default function FleetsPage() {
  const { state, error, now } = useEmpire();

  return (
    <AppShell title="Fleets">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      {!state ? (
        <p className="text-sm text-[var(--muted-fg)]">No empire loaded.</p>
      ) : (
        <>
          <h2 className="text-sm font-semibold uppercase tracking-wide text-[var(--muted-fg)]">In flight</h2>
          {state.fleets.length === 0 ? (
            <p className="mt-2 text-sm text-[var(--muted-fg)]">No hulls away from dock.</p>
          ) : (
            <ul className="mt-2 flex flex-col gap-2">
              {state.fleets.map((fleet) => (
                <li key={fleet.id} className="rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4">
                  <p className="font-semibold">
                    {fleet.mission === "attack" ? "Raid" : "Return"} · {fleet.raiders} raider
                    {fleet.raiders === 1 ? "" : "s"}
                  </p>
                  <p className="mt-1 text-xs text-[var(--muted-fg)]">
                    {fleet.dest_name ?? "Unknown"} [{fleet.dest_system}:{fleet.dest_slot}]
                  </p>
                  <p className="mt-2 text-sm">
                    ETA <Countdown until={fleet.arrives_at} now={now} />
                  </p>
                  {fleet.mission === "return" ? (
                    <p className="mt-1 text-xs text-[var(--muted-fg)]">
                      Cargo {fleet.cargo_ore.toLocaleString()} ore · {fleet.cargo_crystal.toLocaleString()} crystal
                    </p>
                  ) : null}
                </li>
              ))}
            </ul>
          )}

          <h2 className="mt-6 text-sm font-semibold uppercase tracking-wide text-[var(--muted-fg)]">Reports</h2>
          {state.reports.length === 0 ? (
            <p className="mt-2 text-sm text-[var(--muted-fg)]">No battle reports yet.</p>
          ) : (
            <ul className="mt-2 flex flex-col gap-2">
              {state.reports.map((report) => (
                <li key={report.id} className="rounded-2xl border border-[var(--border)] bg-[var(--card)] p-4">
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
