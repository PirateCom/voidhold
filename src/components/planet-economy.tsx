"use client";

import { useEmpire } from "@/components/empire-provider";
import {
  crystalProductionPerHour,
  crawlerCap,
  crawlerProductionBonus,
  CRAWLER_ENERGY,
  workingCrawlers,
  deuteriumClimate,
  deuteriumProductionPerHour,
  deutEnergyDrain,
  fusionDeuteriumBurnPerHour,
  fusionOutput,
  mineEnergyDrain,
  mineProductionPerHour,
  normalizeEconomySpeed,
  powerOutput,
  solarPlantBase,
  solarSatelliteBaseEnergy,
  solarSatelliteEnergy,
  starLabel,
} from "@/lib/game/catalog";

function Row({
  label,
  value,
  detail,
  last = false,
}: {
  label: string;
  value: string;
  detail?: string;
  last?: boolean;
}) {
  return (
    <div className={`py-3 ${last ? "" : "border-b border-[var(--border)]"}`}>
      <div className="flex items-baseline justify-between gap-4">
        <dt className="text-sm text-[var(--muted-fg)]">{label}</dt>
        <dd className="text-right text-sm font-semibold tabular-nums">{value}</dd>
      </div>
      {detail ? <p className="mt-1 text-xs leading-relaxed text-[var(--muted-fg)]">{detail}</p> : null}
    </div>
  );
}

function fmt(n: number): string {
  return Math.floor(n).toLocaleString();
}

function pct(factor: number): string {
  return `${Math.round(Math.min(1, Math.max(0, factor)) * 100)}%`;
}

export function PlanetEconomy() {
  const { live, state } = useEmpire();
  if (!live || !state?.star) return null;

  const star = state.star.type;
  const mul = state.star.multiplier;
  const speed = normalizeEconomySpeed(live.economySpeed ?? state.empire.economy_speed);
  const factor = live.energy.factor;
  const tempMin = live.tempMin ?? state.planet.temp_min;
  const tempMax = live.tempMax ?? state.planet.temp_max;
  const avg = (tempMin + tempMax) / 2;
  const climate = deuteriumClimate(tempMax);
  const energyTech = live.energyTech ?? state.empire.energy_tech ?? 0;
  const sats = live.solarSatellites ?? state.empire.ships?.solar_satellite ?? 0;

  const oreBase = mineProductionPerHour(live.oreMine);
  const crystalBase = crystalProductionPerHour(live.crystalMine);
  const deutBase = deuteriumProductionPerHour(live.deuteriumExtractor, tempMax);
  const fusionBurn = fusionDeuteriumBurnPerHour(live.fusionReactor);
  const plantBase = solarPlantBase(live.powerPlant);
  const plant = powerOutput(live.powerPlant, star);
  const fusion = fusionOutput(live.fusionReactor, energyTech);
  const satBase = solarSatelliteBaseEnergy(tempMin, tempMax);
  const satEach = Math.floor(satBase * mul);
  const satTotal = solarSatelliteEnergy(tempMin, tempMax, star, sats);
  const fusionOnline = live.fusionReactor > 0 && live.energy.output === plant + fusion + satTotal;
  const drainOre = mineEnergyDrain(live.oreMine);
  const drainCry = mineEnergyDrain(live.crystalMine);
  const drainDeut = deutEnergyDrain(live.deuteriumExtractor);
  const mineDrain = drainOre + drainCry + drainDeut;
  const crawlersOwned = live.crawlers ?? state.empire.ships?.crawler ?? 0;
  const crawlerLimit = crawlerCap(live.oreMine, live.crystalMine, live.deuteriumExtractor);
  const crawlersWorking = workingCrawlers(
    crawlersOwned,
    live.oreMine,
    live.crystalMine,
    live.deuteriumExtractor,
    live.energy.output,
    mineDrain,
  );
  const crawlerBonus = crawlerProductionBonus(crawlersWorking);
  const crawlerPct = ((crawlerBonus - 1) * 100).toFixed(2);
  const crawlerBit = crawlersWorking > 0 ? ` · crawlers +${crawlerPct}%` : "";

  const speedBit = speed !== 1 ? ` · economy ×${speed}` : "";
  const energyBit = factor < 1 ? ` · energy ${pct(factor)}` : "";
  const starBit = ` · ${starLabel(star)}${mul !== 1 ? ` ×${mul}` : ""}`;

  return (
    <>
      <p className="mb-2 text-xs uppercase tracking-[0.2em] text-[var(--muted-fg)]">Planet economy</p>
      <p className="mb-2 text-xs uppercase tracking-[0.2em] text-[var(--muted-fg)]">Mines</p>
      <dl className="sci-card mb-4 px-4">
        <Row
          label={`Ore mine L${live.oreMine}`}
          value={`${fmt(live.orePerHour)}/h`}
          detail={`Base ${fmt(oreBase)}/h${energyBit}${crawlerBit}${speedBit}`}
        />
        <Row
          label={`Crystal mine L${live.crystalMine}`}
          value={`${fmt(live.crystalPerHour)}/h`}
          detail={`Base ${fmt(crystalBase)}/h${energyBit}${crawlerBit}${speedBit}`}
        />
        <Row
          label={`Deuterium extractor L${live.deuteriumExtractor}`}
          value={`${fmt(live.deuteriumPerHour ?? 0)}/h`}
          detail={`Base ${fmt(deutBase)}/h at Tmax ${tempMax}°C (climate ×${climate.toFixed(3)})${energyBit}${crawlerBit}${
            live.fusionReactor > 0
              ? ` · fusion ${fusionOnline ? "burns" : "idle, would burn"} ${fmt(fusionBurn * speed)}/h`
              : ""
          }${speedBit}`}
          last
        />
      </dl>
      <p className="mb-2 text-xs uppercase tracking-[0.2em] text-[var(--muted-fg)]">Power</p>
      <dl className="sci-card mb-4 px-4">
        <Row
          label={`Solar plant L${live.powerPlant}`}
          value={`${fmt(plant)}`}
          detail={
            live.powerPlant > 0
              ? `Base ${fmt(plantBase)}${starBit}`
              : "No solar plant"
          }
        />
        <Row
          label={`Fusion reactor L${live.fusionReactor}`}
          value={`${fmt(fusion)}`}
          detail={
            live.fusionReactor > 0
              ? `Energy tech ${energyTech}${fusionOnline ? "" : " · offline (no deuterium)"}`
              : "No fusion reactor"
          }
        />
        <Row
          label={sats > 0 ? `Solar satellites ×${sats}` : "Solar satellites"}
          value={sats > 0 ? fmt(satTotal) : "0"}
          detail={`${fmt(satBase)} each from avg ${Math.round(avg)}°C (${tempMin}°C to ${tempMax}°C)${
            mul !== 1 ? ` · ${starLabel(star)} ×${mul} → ${fmt(satEach)} each` : ""
          }${sats > 0 ? ` · ${fmt(satTotal)} total` : ""}`}
        />
        <Row
          label={crawlersOwned > 0 ? `Crawlers ×${crawlersOwned}` : "Crawlers"}
          value={
            crawlersOwned > 0
              ? `${fmt(crawlersWorking)} working`
              : "0"
          }
          detail={`Cap ${fmt(crawlerLimit)} (8 per mine level) · ${CRAWLER_ENERGY} energy each from leftover after mines · +0.02% mines each when working${
            crawlersOwned > crawlersWorking ? ` · ${fmt(crawlersOwned - crawlersWorking)} idle` : ""
          }`}
        />
        <Row
          label="Energy total"
          value={`${fmt(live.energy.output)} / ${fmt(live.energy.drain)} used`}
          detail={`Plant ${fmt(plant)}${fusion > 0 ? ` · fusion ${fmt(fusion)}` : ""}${
            sats > 0 ? ` · satellites ${fmt(satTotal)}` : ""
          } · mines drain ore ${fmt(drainOre)} · crystal ${fmt(drainCry)} · deut ${fmt(drainDeut)}${
            crawlersWorking > 0 ? ` · crawlers ${fmt(crawlersWorking * CRAWLER_ENERGY)}` : ""
          } · factor ${pct(factor)}`}
          last
        />
      </dl>
      <p className="mb-2 text-xs uppercase tracking-[0.2em] text-[var(--muted-fg)]">Storage</p>
      <dl className="sci-card mb-4 px-4">
        <Row
          label={`Ore hold L${live.oreStorage}`}
          value={`${fmt(live.ore)} / ${fmt(live.oreCap)}`}
        />
        <Row
          label={`Crystal hold L${live.crystalStorage}`}
          value={`${fmt(live.crystal)} / ${fmt(live.crystalCap)}`}
        />
        <Row
          label={`Deuterium tank L${live.deuteriumStorage}`}
          value={`${fmt(live.deuterium ?? 0)} / ${fmt(live.deuteriumCap ?? 0)}`}
          last
        />
      </dl>
    </>
  );
}
