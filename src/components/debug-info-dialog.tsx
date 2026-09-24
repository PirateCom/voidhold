"use client";

import { DEBUG_INFO } from "@/lib/game/debug-info";

export function DebugInfoDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-40 flex items-end justify-center bg-black/60 p-3">
      <div className="sci-card max-h-[80vh] w-full max-w-md overflow-y-auto p-4">
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 className="font-semibold">{DEBUG_INFO.title}</h2>
            <p className="mt-1 text-xs uppercase tracking-wide text-cyan-300">
              Playable · {DEBUG_INFO.percent}% of a full OGame session
            </p>
          </div>
          <button type="button" className="sci-btn sci-btn-quiet h-11 px-3" onClick={onClose}>
            Close
          </button>
        </div>
        <p className="mt-3 text-sm">{DEBUG_INFO.headline}</p>
        <h3 className="mt-4 text-xs font-semibold tracking-wide text-[var(--muted-fg)] uppercase">In the build</h3>
        <ul className="mt-2 list-disc space-y-2 pl-4 text-xs text-[var(--muted-fg)]">
          {DEBUG_INFO.working.map((line) => (
            <li key={line}>{line}</li>
          ))}
        </ul>
        <h3 className="mt-4 text-xs font-semibold tracking-wide text-[var(--muted-fg)] uppercase">Not built yet</h3>
        <ul className="mt-2 list-disc space-y-2 pl-4 text-xs text-[var(--muted-fg)]">
          {DEBUG_INFO.missing.map((line) => (
            <li key={line}>{line}</li>
          ))}
        </ul>
      </div>
    </div>
  );
}
