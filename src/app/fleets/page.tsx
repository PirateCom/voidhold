"use client";

import { AppShell } from "@/components/app-shell";
import { Countdown } from "@/components/countdown";
import { useEmpire } from "@/components/empire-provider";
import { TimedStripedProgress } from "@/components/striped-progress";
import { flightSeconds } from "@/lib/game/catalog";

export default function FleetsPage() {
  const { state, error, now } = useEmpire();

  return (
    <AppShell title="Fleet">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      {!state ? (
        <p className="text-sm text-[var(--muted-fg)]">No empire loaded.</p>
      ) : (
        <>
          <h2 className="font-[family-name:var(--font-display)] text-xs font-semibold tracking-wide text-cyan-300 uppercase">In flight</h2>
          {state.fleets.length === 0 ? (
            <p className="mt-2 text-sm text-[var(--muted-fg)]">No hulls away from dock.</p>
          ) : (
            <ul className="mt-2 flex flex-col gap-2">
              {state.fleets.map((fleet) => (
                <li key={fleet.id} className="sci-card p-4">
                  <p className="font-semibold">
                    {fleet.mission === "attack" ? "Raid" : "Return"} · {fleet.raiders} small cargo
                  </p>
                  <p className="mt-1 text-xs text-[var(--muted-fg)]">
                    {fleet.dest_name ?? "Unknown"} [
                    {fleet.dest_galaxy ?? state.planet.galaxy}:{fleet.dest_system}:{fleet.dest_slot}]
                  </p>
                  {fleet.dest_system != null && fleet.dest_slot != null ? (
                    <TimedStripedProgress
                      className="mt-3"
                      until={fleet.arrives_at}
                      durationMs={
                        flightSeconds(
                          state.planet.system,
                          state.planet.slot,
                          fleet.dest_system,
                          fleet.dest_slot,
                          state.empire.propulsion_level,
                          state.planet.galaxy,
                          fleet.dest_galaxy ?? state.planet.galaxy,
                        ) * 1000
                      }
                      now={now}
                      label={`${fleet.mission} fleet`}
                    />
                  ) : null}
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

        </>
      )}
    </AppShell>
  );
}
