"use client";

import { useEffect, useState } from "react";
import { useEmpire } from "@/components/empire-provider";

export function RenamePlanets() {
  const { state, pending, error, renamePlanet } = useEmpire();
  const colonies = state?.colonies ?? [];
  const colonyKey = colonies.map((row) => `${row.id}:${row.name}`).join("|");
  const [drafts, setDrafts] = useState<Record<number, string>>({});

  useEffect(() => {
    const next: Record<number, string> = {};
    for (const row of colonies) next[row.id] = row.name;
    setDrafts(next);
  }, [colonyKey]);

  if (colonies.length === 0) return null;

  return (
    <>
      <p className="mb-2 text-xs uppercase tracking-[0.2em] text-[var(--muted-fg)]">Rename planets</p>
      <div className="sci-card mb-4 flex flex-col gap-3 p-4">
        {colonies.map((row) => {
          const draft = drafts[row.id] ?? row.name;
          const dirty = draft.trim() !== row.name;
          return (
            <form
              key={row.id}
              className="flex flex-col gap-2"
              onSubmit={(e) => {
                e.preventDefault();
                void renamePlanet(row.id, draft);
              }}
            >
              <p className="text-xs text-[var(--muted-fg)]">
                [{row.galaxy}:{row.system}:{row.slot}] {row.is_homeworld ? "Homeworld" : "Colony"}
              </p>
              <div className="flex gap-2">
                <input
                  value={draft}
                  maxLength={20}
                  disabled={pending}
                  onChange={(e) => setDrafts((cur) => ({ ...cur, [row.id]: e.target.value }))}
                  className="sci-input h-11 min-w-0 flex-1 px-3 text-sm"
                  aria-label={`Name for [${row.galaxy}:${row.system}:${row.slot}]`}
                />
                <button
                  type="submit"
                  disabled={pending || !dirty || draft.trim() === ""}
                  className="sci-btn h-11 shrink-0 px-3"
                >
                  Save
                </button>
              </div>
            </form>
          );
        })}
        {error ? <p className="text-sm text-red-300">{error}</p> : null}
      </div>
    </>
  );
}
