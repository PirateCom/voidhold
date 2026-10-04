"use client";

import { useMemo, useState } from "react";
import { AppShell } from "@/components/app-shell";
import { DeployForm } from "@/components/deploy-sheet";
import { useEmpire } from "@/components/empire-provider";

export default function ColonyPage() {
  const { state, error } = useEmpire();
  const others = useMemo(
    () => (state?.colonies ?? []).filter((row) => row.id !== state?.planet.id),
    [state?.colonies, state?.planet.id],
  );
  const [destId, setDestId] = useState<number | "">("");
  const selected = others.find((row) => row.id === destId) ?? others[0] ?? null;

  return (
    <AppShell title="Colony">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      {!state ? (
        <p className="text-sm text-[var(--muted-fg)]">No empire loaded.</p>
      ) : others.length === 0 ? (
        <p className="text-sm text-[var(--muted-fg)]">
          Found a second planet to station hulls there. Colonize an empty slot from the galaxy map first.
        </p>
      ) : (
        <>
          <p className="mb-3 text-sm text-[var(--muted-fg)]">
            Move ships from {state.planet.name} to another of your worlds. They stay at the destination.
          </p>
          <label className="mb-4 block text-xs text-[var(--muted-fg)]">
            Destination
            <select
              className="sci-input mt-1 h-11 w-full px-3"
              value={selected?.id ?? ""}
              onChange={(e) => setDestId(Number(e.target.value))}
            >
              {others.map((row) => (
                <option key={row.id} value={row.id}>
                  [{row.galaxy}:{row.system}:{row.slot}] {row.name}
                  {row.is_homeworld ? " ★" : ""}
                </option>
              ))}
            </select>
          </label>
          {selected ? (
            <div className="sci-card p-4">
              <DeployForm
                galaxy={selected.galaxy}
                system={selected.system}
                slot={selected.slot}
                targetName={selected.name}
              />
            </div>
          ) : null}
        </>
      )}
    </AppShell>
  );
}
