"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const items = [
  { href: "/", label: "Planet", icon: PlanetIcon },
  { href: "/yards", label: "Yards", icon: YardsIcon },
  { href: "/galaxy", label: "Galaxy", icon: GalaxyIcon },
  { href: "/fleets", label: "Fleets", icon: FleetIcon },
];

export function BottomNav() {
  const pathname = usePathname();

  return (
    <nav className="fixed bottom-0 left-1/2 z-20 w-full max-w-[430px] -translate-x-1/2 border-t border-[var(--border)] bg-[var(--surface)]/95 pb-[env(safe-area-inset-bottom)] backdrop-blur">
      <ul className="grid grid-cols-4">
        {items.map(({ href, label, icon: Icon }) => {
          const active = href === "/" ? pathname === "/" : pathname === href || pathname.startsWith(`${href}/`);
          return (
            <li key={href}>
              <Link
                href={href}
                className={`flex flex-col items-center gap-0.5 py-2.5 text-[11px] font-medium ${
                  active ? "text-[var(--accent)]" : "text-[var(--muted-fg)]"
                }`}
              >
                <Icon active={active} />
                {label}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}

function PlanetIcon({ active }: { active: boolean }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden>
      <circle cx="12" cy="12" r="7" stroke="currentColor" strokeWidth={active ? 2.2 : 1.8} />
      <path d="M4 13.5c3.5-1 8.5-1 16 1" stroke="currentColor" strokeWidth={active ? 2.2 : 1.8} />
    </svg>
  );
}

function YardsIcon({ active }: { active: boolean }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden>
      <path
        d="M5 19V8l7-4 7 4v11H5Z"
        stroke="currentColor"
        strokeWidth={active ? 2.2 : 1.8}
        strokeLinejoin="round"
      />
      <path d="M9 19v-6h6v6" stroke="currentColor" strokeWidth={active ? 2.2 : 1.8} />
    </svg>
  );
}

function GalaxyIcon({ active }: { active: boolean }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden>
      <circle cx="12" cy="12" r="2" stroke="currentColor" strokeWidth={active ? 2.2 : 1.8} />
      <path
        d="M5 8c2 4 5 6 7 6s5-2 7-6M5 16c2-4 5-6 7-6s5 2 7 6"
        stroke="currentColor"
        strokeWidth={active ? 2.2 : 1.8}
      />
    </svg>
  );
}

function FleetIcon({ active }: { active: boolean }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden>
      <path
        d="M4 16 12 4l8 12-8 4-8-4Z"
        stroke="currentColor"
        strokeWidth={active ? 2.2 : 1.8}
        strokeLinejoin="round"
      />
    </svg>
  );
}
