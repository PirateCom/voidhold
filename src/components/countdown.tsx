"use client";

import { formatDuration } from "@/lib/game/catalog";
import { useEffect, useState } from "react";

export function Countdown({ until, now }: { until: number | string | null; now: number }) {
  const [label, setLabel] = useState("—");

  useEffect(() => {
    if (!until) {
      setLabel("—");
      return;
    }
    const t = typeof until === "string" ? new Date(until).getTime() : until;
    const seconds = Math.max(0, (t - now) / 1000);
    setLabel(formatDuration(seconds));
  }, [until, now]);

  return <span className="font-mono text-[var(--accent)]">{label}</span>;
}
