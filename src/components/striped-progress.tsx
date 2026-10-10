"use client";

import { effectiveJobDurationMs, progressToward, showsJobProgress } from "@/lib/game/catalog";
import { useEffect, useRef, useState } from "react";

export function StripedProgress({
  value,
  tone = "var(--accent)",
  animated = true,
  disabled = false,
  label,
  className,
  size = "md",
}: {
  value: number;
  tone?: string;
  animated?: boolean;
  disabled?: boolean;
  label?: string;
  className?: string;
  size?: "sm" | "md";
}) {
  const pct = disabled ? 0 : Math.min(100, Math.max(0, value * 100));
  const running = animated && !disabled && pct > 0 && pct < 100;
  return (
    <div
      className={`progress-track overflow-hidden rounded-full ring-1 ring-[var(--border)] ${
        size === "sm" ? "h-2" : "h-3"
      } ${disabled ? "opacity-40" : ""} ${className ?? ""}`}
      role="progressbar"
      aria-disabled={disabled || undefined}
      aria-label={label}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={Math.round(pct)}
    >
      <div
        className={`progress-stripes h-full ${running ? "progress-stripes-animated" : ""}`}
        style={{
          width: `${pct}%`,
          backgroundColor: tone,
        }}
      />
    </div>
  );
}

export function TimedStripedProgress({
  until,
  durationMs,
  now,
  startedAt,
  tone = "var(--accent)",
  label,
  className,
  size,
}: {
  until: number | string | null | undefined;
  durationMs: number;
  now: number;
  startedAt?: number | string | null;
  tone?: string;
  label?: string;
  className?: string;
  size?: "sm" | "md";
}) {
  const untilKey = until == null ? "" : String(until);
  const origin = useRef<{ untilKey: string; base: number; perf: number; span: number } | null>(null);
  const span = effectiveJobDurationMs(until, durationMs, now, startedAt);
  const remaining =
    until == null ? 0 : Math.max(0, (typeof until === "string" ? Date.parse(until) : until) - now);
  const visible = showsJobProgress(durationMs) || showsJobProgress(span) || showsJobProgress(remaining);
  if (!origin.current || origin.current.untilKey !== untilKey) {
    origin.current = {
      untilKey,
      base: now,
      perf: typeof performance !== "undefined" ? performance.now() : 0,
      span,
    };
  } else {
    origin.current.span = span;
  }

  const [clock, setClock] = useState(now);

  useEffect(() => {
    if (!visible) return;
    let raf = 0;
    const loop = (t: number) => {
      const o = origin.current;
      if (o) setClock(o.base + (t - o.perf));
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, [untilKey, visible]);

  if (!visible) return null;

  const value = progressToward(until, origin.current.span, clock);
  return (
    <StripedProgress
      value={value}
      tone={tone}
      animated={value > 0 && value < 1}
      label={label}
      className={className}
      size={size}
    />
  );
}
