"use client";

import { useEffect, useState } from "react";
import { useEmpire } from "@/components/empire-provider";

const PLANET_NAME_CHARS = /[^A-Za-z0-9_]/g;

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
          const dirty = draft !== row.name;
          const valid = /^[A-Za-z0-9_]+$/.test(draft);
          return (
            <form
              key={row.id}
              className="flex flex-col gap-2"
              onSubmit={(e) => {
                e.preventDefault();
                if (!valid) return;
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
                  pattern="[A-Za-z0-9_]+"
                  title="Letters, numbers, and underscores only"
                  disabled={pending}
                  onChange={(e) =>
                    setDrafts((cur) => ({
                      ...cur,
                      [row.id]: e.target.value.replace(PLANET_NAME_CHARS, "").slice(0, 20),
                    }))
                  }
                  className="sci-input h-11 min-w-0 flex-1 px-3 text-sm"
                  aria-label={`Name for [${row.galaxy}:${row.system}:${row.slot}]`}
                />
                <button type="submit" disabled={pending || !dirty || !valid} className="sci-btn h-11 shrink-0 px-3">
                  Save
                </button>
              </div>
            </form>
          );
        })}
        <p className="text-[11px] text-[var(--muted-fg)]">Letters, numbers, and _ only. No spaces.</p>
        {error ? <p className="text-sm text-red-300">{error}</p> : null}
      </div>
    </>
  );
}
