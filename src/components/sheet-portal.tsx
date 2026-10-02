"use client";

import { useEffect, useState, type ReactNode } from "react";
import { createPortal } from "react-dom";

const DOCK_HEIGHT = "3.75rem";

function useSheetRoot() {
  const [target, setTarget] = useState<HTMLElement | null>(null);
  useEffect(() => setTarget(document.getElementById("sheet-root") ?? document.body), []);
  return target;
}

/** Renders a bottom sheet in the area between the header and the bottom menu, above the action dock. */
export function SheetPortal({ children }: { children: ReactNode }) {
  const target = useSheetRoot();
  if (!target) return null;
  return createPortal(
    <div
      className="absolute inset-x-0 top-0 z-10 flex items-end justify-center bg-black/60 p-3"
      style={{ bottom: DOCK_HEIGHT }}
    >
      {children}
    </div>,
    target,
  );
}

/** A row pinned to the bottom of the content area, just above the bottom menu. */
export function SheetDock({ children }: { children: ReactNode }) {
  const target = useSheetRoot();
  if (!target) return null;
  return createPortal(
    <div
      className="absolute inset-x-0 bottom-0 z-20 flex items-center border-t border-cyan-500/30 bg-slate-950/95 px-3 backdrop-blur-md"
      style={{ height: DOCK_HEIGHT }}
    >
      <div className="w-full">{children}</div>
    </div>,
    target,
  );
}
