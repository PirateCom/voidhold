"use client";

import type { ReactNode } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { latestReportAt, useCommsSeenAt } from "@/components/comms-seen";
import { useEmpire } from "@/components/empire-provider";
import {
  DIRECTIVES,
  directiveComplete,
  directiveUnlocked,
  isDirectiveClaimed,
  levelsFromHold,
} from "@/lib/game/directives";

const rows = [
  [
    { href: "/", label: "Resources", icon: ResourcesIcon },
    { href: "/buildings", label: "Facilities", icon: FacilitiesIcon },
    { href: "/research", label: "Research", icon: ResearchIcon },
    { href: "/directives", label: "Directives", icon: DirectivesIcon },
    { href: "/missions", label: "Missions", icon: MissionsIcon },
  ],
  [
    { href: "/defences", label: "Defence", icon: DefenceIcon },
    { href: "/shipyard", label: "Shipyard", icon: ShipyardIcon },
    { href: "/fleets", label: "Fleet", icon: FleetIcon },
    { href: "/galaxy", label: "Galaxy", icon: GalaxyIcon },
    { href: "/communications", label: "Comms", icon: CommsIcon },
  ],
];

const ACCENTS: Record<string, { idle: string; active: string }> = {
  "/directives": {
    idle: "border border-transparent bg-[radial-gradient(ellipse_at_center,rgba(59,130,246,0.28),transparent_70%)] text-blue-300",
    active:
      "border border-blue-400/70 bg-blue-900/50 text-blue-200 shadow-[inset_0_0_15px_rgba(59,130,246,0.25),0_0_10px_rgba(59,130,246,0.35)]",
  },
  "/missions": {
    idle: "border border-transparent bg-[radial-gradient(ellipse_at_center,rgba(168,85,247,0.28),transparent_70%)] text-purple-300",
    active:
      "border border-purple-400/70 bg-purple-900/50 text-purple-200 shadow-[inset_0_0_15px_rgba(168,85,247,0.25),0_0_10px_rgba(168,85,247,0.35)]",
  },
};

export function BottomNav() {
  const pathname = usePathname();
  const { state, live } = useEmpire();
  const seenAt = useCommsSeenAt();
  const unread = latestReportAt(state?.reports) > seenAt;
  const collectable = (() => {
    if (!state?.planet || !state.empire) return false;
    const levels = levelsFromHold({
      planet: state.planet,
      empire: state.empire,
      energyOutput: live?.energy.output,
      energyDrain: live?.energy.drain,
      starType: state.star?.type,
    });
    const claimed = state.empire.claimed_directives;
    return DIRECTIVES.some(
      (spec) =>
        !isDirectiveClaimed(claimed, spec.id) &&
        directiveUnlocked(claimed, spec.id) &&
        directiveComplete(spec, levels),
    );
  })();
  const dotFor: Record<string, boolean> = {
    "/communications": unread,
    "/directives": collectable,
  };

  return (
    <footer className="relative z-30 shrink-0 border-t border-cyan-500/30 bg-slate-950/95 px-1 pt-1.5 pb-[max(0.35rem,env(safe-area-inset-bottom))] backdrop-blur-lg">
      <nav className="flex flex-col gap-0.5">
        {rows.map((row) => (
          <ul
            key={row[0].href}
            className="grid gap-0.5"
            style={{ gridTemplateColumns: `repeat(${row.length}, minmax(0, 1fr))` }}
          >
            {row.map(({ href, label, icon: Icon }) => {
              const active = href === "/" ? pathname === "/" : pathname === href || pathname.startsWith(`${href}/`);
              return (
                <li key={href}>
                  <Link
                    href={href}
                    className={`relative flex flex-col items-center justify-center rounded px-0.5 py-1.5 font-[family-name:var(--font-display)] text-[9px] leading-tight tracking-tight uppercase ${
                      ACCENTS[href]
                        ? `${active ? ACCENTS[href].active : ACCENTS[href].idle} ${active ? "font-bold" : "font-medium"}`
                        : active
                          ? "border border-cyan-500/40 bg-cyan-950/40 font-bold text-cyan-300 shadow-[inset_0_0_15px_rgba(0,240,255,0.15),0_0_10px_rgba(0,240,255,0.2)]"
                          : "font-medium text-slate-400"
                    }`}
                  >
                    {dotFor[href] && !active ? (
                      <span
                        aria-label={href === "/directives" ? "Reward ready" : "New reports"}
                        className="absolute top-1 right-2 h-2 w-2 animate-pulse rounded-full bg-emerald-400 shadow-[0_0_6px_rgba(52,211,153,0.9)]"
                      />
                    ) : null}
                    <Icon />
                    <span className="mt-1 text-center">{label}</span>
                  </Link>
                </li>
              );
            })}
          </ul>
        ))}
      </nav>
    </footer>
  );
}

function IconWrap({ children }: { children: ReactNode }) {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden>
      {children}
    </svg>
  );
}

function DirectivesIcon() {
  return (
    <IconWrap>
      <path d="M8 4h10v16H8z" stroke="currentColor" strokeWidth="1.8" />
      <path d="M6 7h2M6 12h2M6 17h2M10 8h6M10 12h6M10 16h4" stroke="currentColor" strokeWidth="1.8" />
    </IconWrap>
  );
}

function ResourcesIcon() {
  return (
    <IconWrap>
      <path d="M4 10.5 12 4l8 6.5V20H4v-9.5Z" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
      <path d="M9 20v-6h6v6" stroke="currentColor" strokeWidth="1.8" />
    </IconWrap>
  );
}

function FacilitiesIcon() {
  return (
    <IconWrap>
      <path d="M3 20h18M5 20V10l5 3V8l5 3V6l6 4v10" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
    </IconWrap>
  );
}

function ResearchIcon() {
  return (
    <IconWrap>
      <path d="M9 3h6M10 3v5.5L6.2 15A3.8 3.8 0 0 0 9.5 21h5a3.8 3.8 0 0 0 3.3-6L14 8.5V3" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
    </IconWrap>
  );
}

function ShipyardIcon() {
  return (
    <IconWrap>
      <path d="M12 3 5 19h14L12 3Z" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
      <path d="M12 10v6" stroke="currentColor" strokeWidth="1.8" />
    </IconWrap>
  );
}

function DefenceIcon() {
  return (
    <IconWrap>
      <path d="M12 3 5 6v6c0 4.6 2.9 7.8 7 9 4.1-1.2 7-4.4 7-9V6l-7-3Z" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
    </IconWrap>
  );
}

function FleetIcon() {
  return (
    <IconWrap>
      <path d="M3 12h13l4-4M16 12l4 4M5 8l4 4-4 4" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
    </IconWrap>
  );
}

function MissionsIcon() {
  return (
    <IconWrap>
      <circle cx="8" cy="8" r="2.2" stroke="currentColor" strokeWidth="1.8" />
      <circle cx="16" cy="11" r="2.2" stroke="currentColor" strokeWidth="1.8" />
      <circle cx="10" cy="17" r="2.2" stroke="currentColor" strokeWidth="1.8" />
      <path d="M10 9.5 14 10.2M9.2 10.2 9.8 15M14.2 12.8 11.6 16" stroke="currentColor" strokeWidth="1.8" />
    </IconWrap>
  );
}

function GalaxyIcon() {
  return (
    <IconWrap>
      <circle cx="12" cy="12" r="2" stroke="currentColor" strokeWidth="1.8" />
      <path d="M5 8c2 4 5 6 7 6s5-2 7-6M5 16c2-4 5-6 7-6s5 2 7 6" stroke="currentColor" strokeWidth="1.8" />
    </IconWrap>
  );
}

function CommsIcon() {
  return (
    <IconWrap>
      <path d="M5 6h14v9H8l-3 3V6Z" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
    </IconWrap>
  );
}
