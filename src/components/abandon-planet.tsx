"use client";

import { useState } from "react";
import { useEmpire } from "@/components/empire-provider";
import { SheetPortal } from "@/components/sheet-portal";

export function AbandonPlanet() {
  const { state, pending, error, abandonPlanet } = useEmpire();
  const [open, setOpen] = useState(false);
  const [typed, setTyped] = useState("");

  const planet = state?.planet;
  if (!planet) return null;

  const owned = state.colonies?.length ?? 1;
  const canAbandon = owned > 1;
  const coords = `[${planet.galaxy}:${planet.system}:${planet.slot}]`;
  const typedOk = typed.trim() === planet.name;

  return (
    <>
      <p className="mt-4 mb-2 text-xs uppercase tracking-[0.2em] text-[var(--muted-fg)]">Abandon planet</p>
      <div className="sci-card mb-4 p-4">
        <p className="text-sm">
          {coords} {planet.name}
        </p>
        <p className="mt-1 text-xs text-[var(--muted-fg)]">
          {canAbandon
            ? "Leaves this world empty in the galaxy. Buildings, ships, defences and resources on it are lost."
            : "You need at least one colony before you can abandon your only planet."}
        </p>
        <button
          type="button"
          disabled={!canAbandon || pending}
          onClick={() => {
            setTyped("");
            setOpen(true);
          }}
          className="sci-btn sci-btn-danger mt-3 h-11 w-full"
        >
          Abandon {planet.name}
        </button>
      </div>

      {open ? (
        <SheetPortal>
          <form
            className="sci-card w-full max-w-md p-4"
            onSubmit={(e) => {
              e.preventDefault();
              if (!typedOk) return;
              void abandonPlanet(planet.id).then((ok) => {
                if (ok) setOpen(false);
              });
            }}
          >
            <h2 className="font-semibold text-rose-200">Abandon {planet.name}?</h2>
            <p className="mt-2 text-sm text-[var(--muted-fg)]">
              {coords} becomes an empty slot. Everything on this planet is lost. Type{" "}
              <span className="font-mono text-rose-200">{planet.name}</span> to confirm.
            </p>
            <input
              autoFocus
              value={typed}
              onChange={(ev) => setTyped(ev.target.value)}
              autoComplete="off"
              placeholder={planet.name}
              className="sci-input mt-4 h-12 w-full px-4 text-sm"
            />
            {error ? <p className="mt-2 text-sm text-red-300">{error}</p> : null}
            <div className="mt-4 grid grid-cols-2 gap-2">
              <button
                type="button"
                className="sci-btn sci-btn-muted h-11 w-full"
                disabled={pending}
                onClick={() => setOpen(false)}
              >
                Cancel
              </button>
              <button type="submit" className="sci-btn sci-btn-danger h-11 w-full" disabled={!typedOk || pending}>
                {pending ? "Abandoning…" : "Abandon forever"}
              </button>
            </div>
          </form>
        </SheetPortal>
      ) : null}
    </>
  );
}
