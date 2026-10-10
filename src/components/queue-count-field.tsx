"use client";

import { UNIT_QUEUE_CAP } from "@/lib/game/catalog";

export function QueueCountField({
  value,
  maxAffordable,
  onChange,
}: {
  value: number;
  maxAffordable: number;
  onChange: (n: number) => void;
}) {
  const room = Math.max(0, Math.min(UNIT_QUEUE_CAP, Math.floor(maxAffordable)));
  const cap = Math.max(1, room);
  return (
    <label className="mt-3 block text-xs text-[var(--muted-fg)]">
      Queue {room > 0 ? `(max ${room.toLocaleString()})` : ""}
      <div className="mt-1 flex gap-2">
        <input
          type="number"
          min={1}
          max={cap}
          value={value}
          onChange={(e) => onChange(Math.max(1, Math.min(cap, Number(e.target.value) || 1)))}
          className="sci-input h-11 min-w-0 flex-1 px-3"
        />
        <button
          type="button"
          disabled={room < 1}
          onClick={() => onChange(room)}
          className="sci-btn sci-btn-muted h-11 shrink-0 px-4"
        >
          Max
        </button>
      </div>
    </label>
  );
}
