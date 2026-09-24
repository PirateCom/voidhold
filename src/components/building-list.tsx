"use client";

import type { ReactNode } from "react";
import { useEmpire } from "@/components/empire-provider";
import { SpriteThumb } from "@/components/sprite-thumb";
import { Countdown } from "@/components/countdown";
import { StripedProgress, TimedStripedProgress } from "@/components/striped-progress";
import {
  BUILDINGS,
  FACILITIES,
  buildingCost,
  buildingTimeSeconds,
  cancelRefund,
  facilitySpec,
  formatDuration,
  fusionOutput,
  powerOutput,
  progressToward,
  researchSpec,
  storageCap,
  unmetFacility,
  upgradeEnergyDelta,
  type FacilityId,
  type ResearchId,
  type ResourceBuildingId,
} from "@/lib/game/catalog";
import { totalFieldsUsed } from "@/lib/game/simulate";
import type { EmpireRow, PlanetRow } from "@/lib/game/types";

function resourceLevel(id: ResourceBuildingId, live: {
  oreMine: number;
  crystalMine: number;
  deuteriumExtractor: number;
  powerPlant: number;
  fusionReactor: number;
  oreStorage: number;
  crystalStorage: number;
  deuteriumStorage: number;
}) {
  if (id === "ore_mine") return live.oreMine;
  if (id === "crystal_mine") return live.crystalMine;
  if (id === "deuterium_extractor") return live.deuteriumExtractor;
  if (id === "power_plant") return live.powerPlant;
  if (id === "fusion_reactor") return live.fusionReactor;
  if (id === "ore_storage") return live.oreStorage;
  if (id === "crystal_storage") return live.crystalStorage;
  return live.deuteriumStorage;
}

function researchLevelOf(id: ResearchId, empire: EmpireRow): number {
  if (id === "combustion_drive") return empire.propulsion_level ?? 0;
  return empire[id] ?? 0;
}

function planetFacilityLevel(id: FacilityId, planet: PlanetRow): number {
  return planet[id] ?? 0;
}

function UpgradeCard({
  id,
  name,
  blurb,
  level,
  extra,
  locked,
  lockLabel,
}: {
  id: string;
  name: string;
  blurb: string;
  level: number;
  extra?: ReactNode;
  locked?: boolean;
  lockLabel?: string;
}) {
  const { live, state, pending, upgrade, cancelUpgrade, now } = useEmpire();
  if (!live || !state) return null;
  const cost = buildingCost(id as never, level);
  const stores = id === "ore_storage" || id === "crystal_storage" || id === "deuterium_storage";
  const energyDelta = upgradeEnergyDelta(id as never, level, state.star.type, state.empire.energy_tech ?? 0);
  const makesPower = id === "power_plant" || id === "fusion_reactor";
  const usesEnergy = id === "ore_mine" || id === "crystal_mine" || id === "deuterium_extractor";
  const currentPower =
    id === "power_plant"
      ? powerOutput(level, state.star.type)
      : id === "fusion_reactor"
        ? fusionOutput(level, state.empire.energy_tech ?? 0)
        : 0;
  const busy = Boolean(state.planet.upgrade_building);
  const thisBusy = state.planet.upgrade_building === id;
  const durationMs = buildingTimeSeconds(level, live.roboticsFactory, live.naniteFactory) * 1000;
  const refund = thisBusy
    ? cancelRefund(cost, progressToward(state.planet.upgrade_completes_at, durationMs, now))
    : null;
  const full = totalFieldsUsed(live) >= state.planet.max_fields;
  return (
    <article className="sci-card p-4">
      <div className="flex items-start gap-3">
        <SpriteThumb id={id} />
        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-3">
            <h2 className="font-semibold">{name}</h2>
            <span className="sci-badge">L{level}</span>
          </div>
          <p className="mt-1 text-xs text-[var(--muted-fg)]">{blurb}</p>
        </div>
      </div>
      {thisBusy ? (
        <TimedStripedProgress
          className="mt-3"
          until={state.planet.upgrade_completes_at}
          durationMs={durationMs}
          now={now}
          tone="var(--accent)"
          label={`${name} upgrade`}
        />
      ) : (
        <StripedProgress className="mt-3" value={0} disabled label={name} animated={false} />
      )}
      <p className="mt-3 text-xs text-[var(--muted-fg)]">
        {stores ? `Holds ${storageCap(level).toLocaleString()}, next ${storageCap(level + 1).toLocaleString()}. ` : null}
        {cost.ore.toLocaleString()} ore · {cost.crystal.toLocaleString()} crystal
        {cost.deuterium > 0 ? ` · ${cost.deuterium.toLocaleString()} deut` : ""}
        {makesPower ? (
          <>
            {" · "}
            <span className="text-emerald-400">
              {currentPower} energy
              {energyDelta > 0 ? ` · next +${energyDelta}` : ""}
            </span>
          </>
        ) : usesEnergy ? (
          <>
            {" · "}
            <span className="text-red-400">-{energyDelta} energy</span>
          </>
        ) : null}
        {" · "}
        {formatDuration(buildingTimeSeconds(level, live.roboticsFactory, live.naniteFactory))}
      </p>
      {extra}
      {thisBusy ? (
        <>
          <p className="mt-3 text-sm">
            Building… <Countdown until={state.planet.upgrade_completes_at} now={now} />
          </p>
          <p className="mt-1 text-xs text-[var(--muted-fg)]">
            Cancel now for {refund?.ore.toLocaleString()} ore · {refund?.crystal.toLocaleString()} crystal
          </p>
          <button
            type="button"
            disabled={pending}
            onClick={() => void cancelUpgrade()}
            className="sci-btn sci-btn-muted mt-3 h-11 w-full disabled:opacity-50"
          >
            Cancel upgrade
          </button>
        </>
      ) : (
        <button
          type="button"
          disabled={pending || busy || full || locked}
          onClick={() => void upgrade(id as never)}
          className="sci-btn mt-3 h-11 w-full"
        >
          {lockLabel ?? (full ? "No free fields" : busy ? "Yard occupied" : "Upgrade")}
        </button>
      )}
    </article>
  );
}

export function ResourceBuildings() {
  const { live, state } = useEmpire();
  if (!live || !state) return null;
  const fusionMissing = [
    researchLevelOf("energy_tech", state.empire) < 3 ? "Energy technology 3" : null,
    live.deuteriumExtractor < 5 ? "Deuterium extractor 5" : null,
  ].filter(Boolean) as string[];
  return (
    <div className="flex flex-col gap-3">
      {BUILDINGS.map((b) => (
        <UpgradeCard
          key={b.id}
          id={b.id}
          name={b.name}
          blurb={b.blurb}
          level={resourceLevel(b.id, live)}
          locked={b.id === "fusion_reactor" && fusionMissing.length > 0}
          lockLabel={
            b.id === "fusion_reactor" && fusionMissing.length > 0 ? "Research locked" : undefined
          }
          extra={
            b.id === "fusion_reactor" && fusionMissing.length > 0 ? (
              <p className="mt-1 text-xs text-amber-200">Needs {fusionMissing.join(", ")}.</p>
            ) : null
          }
        />
      ))}
    </div>
  );
}

export function BuildingList() {
  const { live, state } = useEmpire();
  if (!live || !state) return null;
  return (
    <div className="flex flex-col gap-3">
      <p className="text-xs text-[var(--muted-fg)]">
        Costs follow the OGame wiki. Deuterium is listed and is not taken from the planet. Moon buildings stay locked.
      </p>
      {FACILITIES.map((facility) => {
        const missing = unmetFacility(
          facility.id,
          (id) => planetFacilityLevel(id, state.planet),
          (id) => researchLevelOf(id, state.empire),
        );
        const locked = facility.moon || missing.length > 0;
        return (
          <UpgradeCard
            key={facility.id}
            id={facility.id}
            name={facility.name}
            blurb={facility.blurb}
            level={planetFacilityLevel(facility.id, state.planet)}
            locked={locked}
            lockLabel={
              facility.moon
                ? "Moon only"
                : missing.length > 0
                  ? "Research locked"
                  : undefined
            }
            extra={
              <>
                {facility.requires.length > 0 ? (
                  <ul className="mt-1 space-y-0.5 text-xs">
                    {facility.requires.map((req) => {
                      const name =
                        req.kind === "facility" ? facilitySpec(req.id).name : researchSpec(req.id).name;
                      const met =
                        req.kind === "facility"
                          ? planetFacilityLevel(req.id, state.planet) >= req.level
                          : researchLevelOf(req.id, state.empire) >= req.level;
                      return (
                        <li
                          key={`${req.kind}-${req.id}-${req.level}`}
                          className={met ? "text-emerald-300" : "text-amber-200"}
                        >
                          {met ? "Ready" : "Needs"} {name} {req.level}
                        </li>
                      );
                    })}
                  </ul>
                ) : null}
                {facility.moon ? <p className="mt-1 text-xs text-amber-200">Moon only.</p> : null}
                {facility.note ? <p className="mt-1 text-xs text-[var(--muted-fg)]">{facility.note}</p> : null}
              </>
            }
          />
        );
      })}
    </div>
  );
}
