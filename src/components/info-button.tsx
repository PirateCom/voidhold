"use client";

export function InfoButton({ label, onClick }: { label: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={label}
      className="absolute top-3 right-3 z-20 flex h-11 w-11 items-center justify-center border border-cyan-400/40 bg-slate-950/85 text-cyan-200"
    >
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden>
        <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2" />
        <path d="M12 10.5V17" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
        <circle cx="12" cy="7.5" r="1.2" fill="currentColor" />
      </svg>
    </button>
  );
}
