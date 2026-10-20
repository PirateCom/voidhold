"use client";

import { useEffect, useState, type ReactNode } from "react";
import { CommandCoreCard } from "@/components/command-core-card";
import { useEmpire } from "@/components/empire-provider";
import { InfoButton } from "@/components/info-button";
import { InfoDialog } from "@/components/info-dialog";
import { SpriteHero } from "@/components/sprite-thumb";
import { FACILITY_HELP } from "@/lib/game/facility-help";
import { Countdown } from "@/components/countdown";
import { StripedProgress, TimedStripedProgress } from "@/components/striped-progress";
import { totalFieldsUsed, planetFieldCapOf } from "@/lib/game/simulate";
import {
  BUILDINGS,
  FACILITIES,
  buildingCost,
  canPayResources,
  buildingTimeSeconds,
  cancelRefund,
  crawlerProductionBonus,
  crystalProductionPerHour,
  deuteriumProductionPerHour,
  deutEnergyDrain,
  facilitySpec,
  formatDuration,
  fusionOutput,
  normalizeMinePct,
  powerOutput,
  progressToward,
  effectiveJobDurationMs,
  researchSpec,
  showsJobProgress,
  storageCap,
  terraformerEnergy,
  mineEnergyDrain,
  mineProductionPerHour,
  unmetFacility,
  workingCrawlers,
  upgradeEnergyDelta,
  upgradeWouldCauseEnergyDeficit,
  type BuildingId,
  type FacilityId,
  type MineThrottleBuildingId,
  type ResearchId,
  type ResourceBuildingId,
} from "@/lib/game/catalog";
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

function pricedResources(
  cost: { ore: number; crystal: number; deuterium: number },
  have: { ore: number; crystal: number; deuterium: number },
) {
  const bits: { label: string; short: boolean }[] = [];
  if (cost.ore > 0) bits.push({ label: `${cost.ore.toLocaleString()} ore`, short: have.ore < cost.ore });
  if (cost.crystal > 0) {
    bits.push({ label: `${cost.crystal.toLocaleString()} crystal`, short: have.crystal < cost.crystal });
  }
  if (cost.deuterium > 0) {
    bits.push({ label: `${cost.deuterium.toLocaleString()} deut`, short: have.deuterium < cost.deuterium });
  }
  return bits;
}

function researchLevelOf(id: ResearchId, empire: EmpireRow): number {
  if (id === "combustion_drive") return empire.propulsion_level ?? 0;
  return empire[id] ?? 0;
}

function planetFacilityLevel(id: FacilityId, planet: PlanetRow): number {
  return planet[id] ?? 0;
}

function MineThrottleControl({
  id,
  level,
  currentPct,
  maxPerHour,
  maxEnergyDrain,
  disabled,
  onCommit,
}: {
  id: MineThrottleBuildingId;
  level: number;
  currentPct: number;
  maxPerHour: number;
  maxEnergyDrain: number;
  disabled: boolean;
  onCommit: (mine: MineThrottleBuildingId, pct: number) => void;
}) {
  const [draft, setDraft] = useState(() => normalizeMinePct(currentPct));

  useEffect(() => {
    setDraft(normalizeMinePct(currentPct));
  }, [currentPct]);

  if (level <= 0) return null;

  const pct = normalizeMinePct(draft);
  const activeProduction = Math.floor((maxPerHour * pct) / 100);
  const activeEnergy = Math.floor((maxEnergyDrain * pct) / 100);

  function choose(next: number) {
    const clean = normalizeMinePct(next);
    setDraft(clean);
    if (clean !== normalizeMinePct(currentPct)) {
      onCommit(id, clean);
    }
  }

  return (
    <div className="mt-3 rounded border border-cyan-500/25 bg-slate-950/70 p-2.5">
      <div className="flex items-center justify-between gap-2 text-xs">
        <span className="font-[family-name:var(--font-display)] text-[10px] font-bold tracking-wider text-cyan-300 uppercase">
          Throttle · {pct}%
        </span>
        <span className="font-mono text-[11px] text-slate-200">
          +{activeProduction.toLocaleString()}/h · <span className="text-amber-300">-{activeEnergy.toLocaleString()} pwr</span>
        </span>
      </div>

      {/* Mobile-first touch control: large −10% / +10% steppers flanking a 10-cell touch slider */}
      <div className="mt-2 flex items-center gap-2">
        <button
          type="button"
          aria-label="Decrease mine output by 10%"
          disabled={disabled || pct <= 0}
          onClick={() => choose(pct - 10)}
          className="sci-btn sci-btn-muted h-10 w-11 shrink-0 px-0 text-sm"
        >
          −
        </button>

        <div className="relative flex h-10 flex-1 items-center">
          <div className="grid h-6 w-full grid-cols-10 gap-1" aria-hidden>
            {Array.from({ length: 10 }, (_, idx) => {
              const cellPct = (idx + 1) * 10;
              const lit = pct >= cellPct;
              return (
                <span
                  key={cellPct}
                  className={`rounded-xs border transition-colors ${
                    lit
                      ? "border-cyan-300/80 bg-cyan-400/75 shadow-[0_0_6px_rgba(0,240,255,0.45)]"
                      : "border-slate-700/70 bg-slate-900/90"
                  }`}
                />
              );
            })}
          </div>
          <input
            type="range"
            min={0}
            max={100}
            step={10}
            disabled={disabled}
            aria-label="Mine production percentage"
            value={pct}
            onChange={(e) => setDraft(normalizeMinePct(Number(e.target.value)))}
            onPointerUp={(e) => choose(Number((e.currentTarget as HTMLInputElement).value))}
            onKeyUp={(e) => choose(Number((e.currentTarget as HTMLInputElement).value))}
            className="absolute inset-0 h-full w-full cursor-pointer opacity-0"
          />
        </div>

        <button
          type="button"
          aria-label="Increase mine output by 10%"
          disabled={disabled || pct >= 100}
          onClick={() => choose(pct + 10)}
          className="sci-btn sci-btn-muted h-10 w-11 shrink-0 px-0 text-sm"
        >
          +
        </button>
      </div>

      {/* Quick one-tap presets for common mobile adjustments */}
      <div className="mt-1.5 grid grid-cols-5 gap-1">
        {([0, 20, 50, 80, 100] as const).map((preset) => (
          <button
            key={preset}
            type="button"
            disabled={disabled}
            onClick={() => choose(preset)}
            className={`rounded border py-1 font-mono text-[10px] transition-colors ${
              pct === preset
                ? "border-cyan-400/70 bg-cyan-950/70 font-bold text-cyan-200"
                : "border-slate-800 bg-slate-900/60 text-[var(--muted-fg)]"
            }`}
          >
            {preset}%
          </button>
        ))}
      </div>
    </div>
  );
}

function UpgradeCard({
  id,
  name,
  blurb,
  level,
  extra,
  locked,
  lockLabel,
  help,
  onHelp,
}: {
  id: BuildingId;
  name: string;
  blurb: string;
  level: number;
  extra?: ReactNode;
  locked?: boolean;
  lockLabel?: string;
  help?: boolean;
  onHelp?: () => void;
}) {
  const { live, state, pending, upgrade, cancelUpgrade, setMinePercent, now } = useEmpire();
  if (!live || !state) return null;
  const speed = state.empire.economy_speed ?? 1;
  const orePct = normalizeMinePct(live.oreMinePct ?? state.planet.ore_mine_pct);
  const crystalPct = normalizeMinePct(live.crystalMinePct ?? state.planet.crystal_mine_pct);
  const deutPct = normalizeMinePct(live.deuteriumExtractorPct ?? state.planet.deuterium_extractor_pct);
  const activeMineDrain =
    Math.floor((mineEnergyDrain(live.oreMine) * orePct) / 100) +
    Math.floor((mineEnergyDrain(live.crystalMine) * crystalPct) / 100) +
    Math.floor((deutEnergyDrain(live.deuteriumExtractor) * deutPct) / 100);
  const crawlerBonus = crawlerProductionBonus(
    workingCrawlers(
      live.crawlers ?? 0,
      live.oreMine,
      live.crystalMine,
      live.deuteriumExtractor,
      live.energy.output,
      activeMineDrain,
    ),
  );
  const incomePerHour = (base: number, pct = 100) =>
    Math.floor(
      ((base * pct) / 100) *
        (live.stellarMineMultiplier ?? 1) *
        live.energy.factor *
        crawlerBonus *
        speed,
    );
  const cost = buildingCost(id as never, level);
  const stores = id === "ore_storage" || id === "crystal_storage" || id === "deuterium_storage";
  const energyDelta = upgradeEnergyDelta(id as never, level, state.star.type, state.empire.energy_tech ?? 0);
  const makesPower = id === "power_plant" || id === "fusion_reactor";
  const usesEnergy = id === "ore_mine" || id === "crystal_mine" || id === "deuterium_extractor";
  const energyGoesShort =
    usesEnergy &&
    upgradeWouldCauseEnergyDeficit(
      id as never,
      live.oreMine,
      live.crystalMine,
      live.powerPlant,
      state.star.type,
      live.deuteriumExtractor,
      live.fusionReactor,
      state.empire.energy_tech ?? 0,
      live.solarSatellites ?? 0,
      live.tempMin ?? 30,
      live.tempMax ?? 30,
      live.crawlers ?? 0,
    );
  const currentPower =
    id === "power_plant"
      ? powerOutput(level, state.star.type)
      : id === "fusion_reactor"
        ? fusionOutput(level, state.empire.energy_tech ?? 0)
        : 0;
  const busy = Boolean(state.planet.upgrade_building);
  const thisBusy = state.planet.upgrade_building === id;
  const durationMs = buildingTimeSeconds(id, level, live.roboticsFactory, live.naniteFactory, speed) * 1000;
  const refund = thisBusy
    ? cancelRefund(
        cost,
        progressToward(
          state.planet.upgrade_completes_at,
          effectiveJobDurationMs(
            state.planet.upgrade_completes_at,
            durationMs,
            now,
            state.planet.upgrade_started_at,
          ),
          now,
        ),
      )
    : null;
  const cap = planetFieldCapOf(live);
  const full = cap != null && totalFieldsUsed(live) >= cap;
  const energyNeed = id === "terraformer" ? terraformerEnergy(level) : 0;
  const energyShort = energyNeed > 0 && live.energy.output < energyNeed;
  const labInUse = id === "research_lab" && Boolean(state.empire.research_completes_at);
  const poor = !canPayResources(live, cost);
  const blocked = pending || busy || full || locked || poor || energyShort || labInUse;
  const actionLabel = lockLabel
    ? lockLabel
    : labInUse
      ? "Research running"
      : energyShort
        ? "Need energy"
        : full
          ? "No free fields"
          : busy
            ? "Yard occupied"
            : poor
              ? "Need resources"
              : "Upgrade";
  return (
    <article className={`sci-card relative overflow-hidden p-0${thisBusy ? " sci-card-active" : ""}`}>
      <SpriteHero id={id} title={name} badge={`LVL ${level}`} />
      {help && onHelp ? <InfoButton label={`About ${name}`} onClick={onHelp} /> : null}
      <div className="px-4 pt-3 pb-4">
      <p className="text-xs text-[var(--muted-fg)]">{blurb}</p>
      <p className="mt-3 text-xs text-[var(--muted-fg)]">
        {id === "ore_mine"
          ? `Produces ${incomePerHour(mineProductionPerHour(level), orePct).toLocaleString()}/h, next ${incomePerHour(mineProductionPerHour(level + 1), orePct).toLocaleString()}/h. `
          : id === "crystal_mine"
            ? `Produces ${incomePerHour(crystalProductionPerHour(level), crystalPct).toLocaleString()}/h, next ${incomePerHour(crystalProductionPerHour(level + 1), crystalPct).toLocaleString()}/h. `
            : id === "deuterium_extractor"
              ? `Produces ${incomePerHour(deuteriumProductionPerHour(level, live.tempMax ?? 30, live.tempMin), deutPct).toLocaleString()}/h, next ${incomePerHour(deuteriumProductionPerHour(level + 1, live.tempMax ?? 30, live.tempMin), deutPct).toLocaleString()}/h. `
              : null}
        {stores ? `Holds ${storageCap(level).toLocaleString()}, next ${storageCap(level + 1).toLocaleString()}. ` : null}
        {pricedResources(cost, live).map((bit, index) => (
          <span key={bit.label}>
            {index > 0 ? " · " : null}
            <span className={bit.short ? "text-red-400" : undefined}>{bit.label}</span>
          </span>
        ))}
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
            <span className={energyGoesShort ? "text-red-400" : undefined}>-{energyDelta} energy</span>
          </>
        ) : energyNeed > 0 ? (
          <>
            {" · "}
            <span className={energyShort ? "text-red-400" : undefined}>
              {energyNeed.toLocaleString()} energy
            </span>
          </>
        ) : null}
        {" · "}
        {formatDuration(buildingTimeSeconds(id, level, live.roboticsFactory, live.naniteFactory, speed))}
      </p>
      {usesEnergy ? (
        <MineThrottleControl
          id={id as MineThrottleBuildingId}
          level={level}
          currentPct={id === "ore_mine" ? orePct : id === "crystal_mine" ? crystalPct : deutPct}
          maxPerHour={
            id === "ore_mine"
              ? incomePerHour(mineProductionPerHour(level), 100)
              : id === "crystal_mine"
                ? incomePerHour(crystalProductionPerHour(level), 100)
                : incomePerHour(deuteriumProductionPerHour(level, live.tempMax ?? 30, live.tempMin), 100)
          }
          maxEnergyDrain={
            id === "deuterium_extractor" ? deutEnergyDrain(level) : mineEnergyDrain(level)
          }
          disabled={pending}
          onCommit={(mine, pct) => void setMinePercent(mine, pct)}
        />
      ) : null}
      {extra}
      {thisBusy ? (
        <>
          <p className="mt-3 text-sm">
            Building… <Countdown until={state.planet.upgrade_completes_at} now={now} />
          </p>
          <p className="mt-1 text-xs text-[var(--muted-fg)]">
            Cancel now for{" "}
            {refund
              ? pricedResources(refund, { ore: 0, crystal: 0, deuterium: 0 })
                  .map((bit) => bit.label)
                  .join(" · ")
              : "nothing"}
          </p>
          <button
            type="button"
            disabled={pending}
            onClick={() => void cancelUpgrade()}
            className="sci-btn sci-btn-muted relative mt-3 h-14 min-h-14 w-full overflow-hidden disabled:opacity-50"
          >
            <TimedStripedProgress
              fill
              until={state.planet.upgrade_completes_at}
              durationMs={durationMs}
              startedAt={state.planet.upgrade_started_at}
              now={now}
              tone="var(--accent)"
              label={`${name} upgrade`}
            />
            <span className="relative z-10 drop-shadow-[0_1px_3px_rgba(0,0,0,0.9)]">Cancel upgrade</span>
          </button>
        </>
      ) : (
        <button
          type="button"
          disabled={blocked}
          onClick={() => void upgrade(id as never)}
          className="sci-btn relative mt-3 h-14 min-h-14 w-full overflow-hidden"
        >
          {showsJobProgress(durationMs) ? (
            <StripedProgress fill value={0} disabled label={name} animated={false} />
          ) : null}
          <span className="relative z-10">{actionLabel}</span>
        </button>
      )}
      </div>
    </article>
  );
}

const RESOURCE_GROUPS: { title: string; ids: ResourceBuildingId[] }[] = [
  { title: "Mines", ids: ["ore_mine", "crystal_mine", "deuterium_extractor"] },
  { title: "Power", ids: ["power_plant", "fusion_reactor"] },
  { title: "Storage", ids: ["ore_storage", "crystal_storage", "deuterium_storage"] },
];

export function ResourceBuildings() {
  const { live, state } = useEmpire();
  if (!live || !state) return null;
  const fusionMissing = [
    researchLevelOf("energy_tech", state.empire) < 3 ? "Energy technology 3" : null,
    live.deuteriumExtractor < 5 ? "Deuterium extractor 5" : null,
  ].filter(Boolean) as string[];
  const byId = Object.fromEntries(BUILDINGS.map((b) => [b.id, b]));
  return (
    <div className="flex flex-col gap-3">
      {RESOURCE_GROUPS.map((group) => (
        <section key={group.title}>
          <p className="mb-2 text-xs uppercase tracking-[0.2em] text-[var(--muted-fg)]">{group.title}</p>
          <div className="card-grid">
            {group.ids.map((id) => {
              const b = byId[id];
              if (!b) return null;
              return (
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
              );
            })}
          </div>
        </section>
      ))}
    </div>
  );
}

export function BuildingList() {
  const { live, state } = useEmpire();
  const [helpId, setHelpId] = useState<FacilityId | null>(null);
  if (!live || !state) return null;
  const helpSpec = helpId ? FACILITIES.find((facility) => facility.id === helpId) : null;
  return (
    <div className="flex flex-col gap-3">
      <CommandCoreCard />
      <p className="text-xs text-[var(--muted-fg)]">
        Deuterium is taken from the tank.
      </p>
      <div className="card-grid">
      {FACILITIES.filter((facility) => !facility.disabled).map((facility) => {
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
            help
            onHelp={() => setHelpId(facility.id)}
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
      <InfoDialog
        open={helpId != null}
        title={helpSpec?.name ?? "Facility"}
        paragraphs={helpId ? FACILITY_HELP[helpId] : []}
        onClose={() => setHelpId(null)}
      />
    </div>
  );
}
