"use client";

export function QueueCountField({
  value,
  maxAffordable,
  onChange,
}: {
  value: number;
  maxAffordable: number;
  onChange: (n: number) => void;
}) {
  const cap = Math.max(1, maxAffordable);
  return (
    <label className="mt-3 block text-xs text-[var(--muted-fg)]">
      Queue
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
          disabled={maxAffordable < 1}
          onClick={() => onChange(maxAffordable)}
          className="sci-btn sci-btn-muted h-11 shrink-0 px-4"
        >
          Max
        </button>
      </div>
    </label>
  );
}
