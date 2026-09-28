"use client";

import { useState } from "react";
import { DebugInfoDialog } from "@/components/debug-info-dialog";
import { useEmpire } from "@/components/empire-provider";

export function DebugControls() {
  const {
    state,
    pending,
    isDebug,
    resetProgress,
    spawnPirates,
    setPirateRaids,
    fillResources,
    grantDebugFleet,
    setEconomySpeed,
  } = useEmpire();
  const pirateRaidsOn = state?.empire.pirate_raids_enabled !== false;
  const economySpeed =
    state?.empire.economy_speed === 3 || state?.empire.economy_speed === 5 ? state.empire.economy_speed : 1;
  const [infoOpen, setInfoOpen] = useState(false);

  if (!isDebug) return null;

  return (
    <>
      <p className="mb-2 mt-4 text-xs uppercase tracking-[0.2em] text-[var(--muted-fg)]">Debug</p>
      <div className="mt-2">
        <p className="mb-2 text-center text-xs font-semibold tracking-wide text-[#fde68a] uppercase">
          Debug: economy speed ×{economySpeed}
        </p>
        <p className="mb-2 text-center text-[11px] leading-snug text-[var(--muted-fg)]">
          Changing speed wipes this empire (buildings, stockpiles, research, ships, colonies, fleets), then starts a
          fresh world. A 1× save can switch to 3× or 5× that way.
        </p>
        <div className="grid grid-cols-3 gap-2">
          {([1, 3, 5] as const).map((speed) => (
            <button
              key={speed}
              type="button"
              disabled={pending}
              onClick={() => {
                if (
                  !window.confirm(
                    `Switch to ×${speed} and reset this empire? Mines and building times will run at that speed.`,
                  )
                ) {
                  return;
                }
                void setEconomySpeed(speed);
              }}
              className={`sci-btn h-11 w-full ${economySpeed === speed ? "sci-btn-warn" : "sci-btn-muted"}`}
            >
              ×{speed}
            </button>
          ))}
        </div>
      </div>
      <button
        type="button"
        disabled={pending}
        onClick={() => {
          if (
            !window.confirm(
              "Reset this empire to a fresh start? Buildings, stockpiles, research, small cargo, and fleets will wipe.",
            )
          ) {
            return;
          }
          void resetProgress();
        }}
        className="sci-btn sci-btn-danger mt-2 h-11 w-full"
      >
        Debug: reset progress
      </button>
      <button
        type="button"
        disabled={pending}
        onClick={() => void fillResources()}
        className="sci-btn sci-btn-warn mt-2 h-11 w-full"
      >
        Debug: fill resources
      </button>
      <button
        type="button"
        disabled={pending}
        onClick={() => void grantDebugFleet()}
        className="sci-btn sci-btn-warn mt-2 h-11 w-full"
      >
        Debug: grant fleet
      </button>
      <button
        type="button"
        disabled={pending}
        onClick={() => void spawnPirates()}
        className="sci-btn sci-btn-warn mt-2 h-11 w-full"
      >
        Debug: deploy pirates
      </button>
      <div className="mt-2">
        <p className="mb-2 text-center text-xs font-semibold tracking-wide text-[#fde68a] uppercase">
          Debug: pirate raids {pirateRaidsOn ? "on" : "off"}
        </p>
        <div className="grid grid-cols-2 gap-2">
          <button
            type="button"
            disabled={pending || pirateRaidsOn}
            onClick={() => void setPirateRaids(true)}
            className={`sci-btn h-11 w-full ${pirateRaidsOn ? "sci-btn-warn" : "sci-btn-muted"}`}
          >
            On
          </button>
          <button
            type="button"
            disabled={pending || !pirateRaidsOn}
            onClick={() => void setPirateRaids(false)}
            className={`sci-btn h-11 w-full ${!pirateRaidsOn ? "sci-btn-warn" : "sci-btn-muted"}`}
          >
            Off
          </button>
        </div>
      </div>
      <button
        type="button"
        onClick={() => setInfoOpen(true)}
        className="sci-btn sci-btn-warn mt-2 mb-4 h-11 w-full"
      >
        Debug: info
      </button>
      <DebugInfoDialog open={infoOpen} onClose={() => setInfoOpen(false)} />
    </>
  );
}
