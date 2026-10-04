"use client";

import Link from "next/link";
import { useEmpire } from "@/components/empire-provider";
import { PlanetAvatar } from "@/components/planet-avatar";
import { isInboundFleet } from "@/lib/game/catalog";
import { planetFieldCapOf, totalFieldsUsed } from "@/lib/game/simulate";

export function PlanetHeader({ title }: { title: string }) {
  const { state, live, pending, selectPlanet } = useEmpire();
  const planet = state?.planet;
  const colonies = state?.colonies ?? [];
  const name = (planet?.name ?? title).toUpperCase();
  const strained = Boolean(live && live.energy.factor < 1);
  const used = live ? totalFieldsUsed(live) : 0;
  const max = live ? planetFieldCapOf(live) : planet?.max_fields;
  const underAttack = Boolean(
    state?.fleets.some(
      (fleet) => isInboundFleet(fleet, state.empire.user_id, state.planet.id) && fleet.mission === "attack",
    ),
  );

  return (
    <div className="relative mb-2 flex items-start justify-between gap-2 overflow-hidden">
      {underAttack ? (
        <div className="pointer-events-none absolute top-1/2 left-[66%] z-0 flex h-28 w-28 -translate-x-1/2 -translate-y-1/2 items-center justify-center" aria-hidden>
          <span className="absolute -inset-8 animate-pulse rounded-full bg-[radial-gradient(ellipse_at_center,rgba(239,68,68,0.5),transparent_72%)]" />
          <svg viewBox="0 0 64 56" className="relative h-8 w-8 text-red-400">
            <path
              d="M32 4 62 54H2L32 4Z"
              fill="rgba(127,29,29,0.55)"
              stroke="currentColor"
              strokeWidth="4"
              strokeLinejoin="round"
            />
            <path d="M32 22v14" stroke="rgb(254 226 226)" strokeWidth="4" strokeLinecap="round" />
            <circle cx="32" cy="44" r="2.4" fill="rgb(254 226 226)" />
          </svg>
        </div>
      ) : null}
      <div className="relative z-10 flex shrink-0 items-center gap-2">
        <Link
          href="/profile"
          aria-label="Profile"
          className="flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden rounded-full border border-cyan-400/50 bg-black shadow-[0_0_15px_rgba(0,240,255,0.35)]"
        >
          <PlanetAvatar seed={String(planet?.id ?? "")} size={46} />
        </Link>
        <div>
          <span className="block font-[family-name:var(--font-display)] text-sm font-bold tracking-wider text-cyan-400">
            {name}
          </span>
          {colonies.length > 1 ? (
            <label className="sr-only" htmlFor="planet-switcher">
              Switch planet
            </label>
          ) : null}
          {colonies.length > 1 ? (
            <select
              id="planet-switcher"
              className="mt-0.5 max-w-[11rem] truncate rounded border border-cyan-500/30 bg-slate-950/80 px-1 py-0.5 font-mono text-[10px] text-cyan-100"
              disabled={pending}
              value={planet?.id ?? ""}
              onChange={(e) => void selectPlanet(Number(e.target.value))}
            >
              {colonies.map((row) => (
                <option key={row.id} value={row.id}>
                  [{row.galaxy}:{row.system}:{row.slot}] {row.name}
                  {row.is_homeworld ? " ★" : ""}
                </option>
              ))}
            </select>
          ) : null}
          {colonies.length > 1 ? (
            <Link href="/colony" className="mt-0.5 block font-mono text-[10px] text-cyan-300 underline-offset-2 hover:underline">
              Deploy ships
            </Link>
          ) : null}
          <div className="flex items-center gap-1 font-mono text-xs text-slate-300">
            <span className={`inline-block h-1.5 w-1.5 rounded-full ${strained ? "bg-amber-400" : "bg-emerald-400"} animate-pulse`} />
            <span>{strained ? "POWER: STRAINED" : "HOLD: NOMINAL"}</span>
          </div>
        </div>
      </div>
      {planet && live ? (
        <div className="relative z-10 pt-0.5 text-right font-mono text-xs leading-tight text-slate-300">
          Fields {used}/{max}
        </div>
      ) : null}
    </div>
  );
}
