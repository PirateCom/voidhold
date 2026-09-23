"use client";

import type { ReactNode } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";

const rows = [
  [
    { href: "/", label: "Resources", icon: ResourcesIcon },
    { href: "/buildings", label: "Facilities", icon: FacilitiesIcon },
    { href: "/research", label: "Research", icon: ResearchIcon },
    { href: "/shipyard", label: "Shipyard", icon: ShipyardIcon },
  ],
  [
    { href: "/defences", label: "Defence", icon: DefenceIcon },
    { href: "/fleets", label: "Fleet", icon: FleetIcon },
    { href: "/galaxy", label: "Galaxy", icon: GalaxyIcon },
    { href: "/communications", label: "Communications", icon: CommsIcon },
  ],
];

export function BottomNav() {
  const pathname = usePathname();

  return (
    <footer className="relative z-30 shrink-0 border-t border-cyan-500/30 bg-slate-950/95 px-1 pt-1.5 pb-[max(0.35rem,env(safe-area-inset-bottom))] backdrop-blur-lg">
      <nav className="flex flex-col gap-0.5">
        {rows.map((row) => (
          <ul key={row[0].href} className="grid grid-cols-4 gap-0.5">
            {row.map(({ href, label, icon: Icon }) => {
              const active = href === "/" ? pathname === "/" : pathname === href || pathname.startsWith(`${href}/`);
              return (
                <li key={href}>
                  <Link
                    href={href}
                    className={`flex flex-col items-center justify-center rounded px-0.5 py-1.5 text-[9px] leading-tight tracking-tight uppercase ${
                      active
                        ? "border border-cyan-500/40 bg-cyan-950/40 font-[family-name:var(--font-display)] font-bold text-cyan-300 shadow-[inset_0_0_15px_rgba(0,240,255,0.15),0_0_10px_rgba(0,240,255,0.2)]"
                        : "font-[family-name:var(--font-display)] font-medium text-slate-400"
                    }`}
                  >
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
