"use client";

import { SheetPortal } from "@/components/sheet-portal";

export function InfoDialog({
  open,
  title,
  paragraphs,
  onClose,
}: {
  open: boolean;
  title: string;
  paragraphs: string[];
  onClose: () => void;
}) {
  if (!open) return null;
  return (
    <SheetPortal>
      <button type="button" className="absolute inset-0 cursor-default" aria-label="Dismiss" onClick={onClose} />
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="info-dialog-title"
        className="sci-card relative z-10 max-h-full w-full max-w-md overflow-y-auto p-4"
      >
        <h2 id="info-dialog-title" className="font-semibold">
          {title}
        </h2>
        <div className="mt-3 space-y-3 text-sm leading-relaxed text-[var(--muted-fg)]">
          {paragraphs.map((line) => (
            <p key={line}>{line}</p>
          ))}
        </div>
        <button type="button" className="sci-btn mt-4 h-14 min-h-14 w-full" onClick={onClose}>
          Close
        </button>
      </div>
    </SheetPortal>
  );
}
