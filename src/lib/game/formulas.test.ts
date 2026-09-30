import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  buildingCost,
  canPayResources,
  buildingTimeSeconds,
  crystalProductionPerHour,
  deuteriumProductionPerHour,
  fusionDeuteriumBurnPerHour,
  fleetFuelOneWay,
  fleetFuelRoundTrip,
  attackFlightSeconds,
  wikiFlightDistance,
  diameterKm,
  fieldsFromDiameter,
  HOMEWORLD_DIAMETER_KM,
  energyAfterUpgrade,
  solarSatelliteEnergy,
  solarPlantBase,
  solarSatelliteBaseEnergy,
  deuteriumClimate,
  upgradeWouldCauseEnergyDeficit,
  energyFactor,
  energyNow,
  crawlerCap,
  crawlerProductionBonus,
  workingCrawlers,
  fieldsUsed,
  fleetSpeedMultiplier,
  flightSeconds,
  espionageProbesNeeded,
  counterEspionageChance,
  gameClock,
  GAME_HOUR_SECONDS,
  harvestAmount,
  mineEnergyDrain,
  mineProductionPerHour,
  powerOutput,
  planetTemperature,
  progressToward,
  effectiveJobDurationMs,
  rollMaxFields,
  starMultiplier,
  raidHaul,
  raidLoot,
  RAIDER_CARGO,
  expeditionFleetCap,
  rollExpeditionKind,
  researchCost,
  researchTechCost,
  unmetResearch,
  unmetShipBuild,
  unmetDefenceBuild,
  SHIPS,
  DEFENCES,
  storageCap,
  cancelRefund,
  defenceCost,
  defenceSpec,
  defenceTimeSeconds,
  emptyDefenceCounts,
  pirateCombat,
  debrisFromWrecks,
  debrisVisible,
  harvestDebris,
  maxPlanets,
  colonizeSlotRange,
  canColonizeSlot,
  pirateWaveSize,
  pirateWavesPerHour,
  planetFieldCap,
  terraformerEnergy,
  terraformerExtraFields,
  terraformerFreeFields,
  upgradeEnergyDelta,
  spentOnBuildingLevels,
  spentOnResearchLevels,
  resourcesToScorePoints,
  scoreResources,
  researchRankPoints,
  fleetRankPoints,
} from "./catalog";

describe("resource costs", () => {
  it("blocks robotics L2 when the tank is short of 400 deut", () => {
    const cost = buildingCost("robotics_factory", 1);
    expect(cost.deuterium).toBe(400);
    expect(canPayResources({ ore: 10_000, crystal: 10_000, deuterium: 177 }, cost)).toBe(false);
    expect(canPayResources({ ore: 10_000, crystal: 10_000, deuterium: 400 }, cost)).toBe(true);
  });
});

describe("production formulas", () => {
  it("scales solar output by the system star", () => {
    expect(starMultiplier("medium")).toBe(1);
    expect(starMultiplier("young_hot")).toBe(1.5);
    expect(starMultiplier("old_cold")).toBe(0.75);
    expect(starMultiplier("pulsar")).toBe(3);
    expect(powerOutput(1, "pulsar")).toBe(66);
    expect(solarPlantBase(1)).toBe(22);
    expect(powerOutput(1)).toBe(22);
    expect(energyFactor(1, 1, 1, "old_cold")).toBeLessThan(1);
  });

  it("keeps a slot temperature span and shifts both ends together", () => {
    expect(planetTemperature(10, 0)).toEqual({ min: -10, max: 30 });
    expect(planetTemperature(10, -3)).toEqual({ min: -13, max: 27 });
    expect(planetTemperature(1, 4).max - planetTemperature(1, 4).min).toBe(60);
    expect(planetTemperature(15, -10).max - planetTemperature(15, -10).min).toBe(70);
  });

  it("rolls most planets inside the slot field band", () => {
    expect(rollMaxFields(2, 0.1, 0)).toBe(40);
    expect(rollMaxFields(2, 0.1, 1)).toBe(70);
    expect(rollMaxFields(8, 0.95, 0)).toBe(256);
    expect(rollMaxFields(8, 0.85, 0)).toBe(20);
    expect(diameterKm(173)).toBe(13153);
    expect(fieldsFromDiameter(HOMEWORLD_DIAMETER_KM, 0)).toBe(163);
    expect(fieldsFromDiameter(HOMEWORLD_DIAMETER_KM)).toBe(173);
    expect(fieldsUsed(1, 1, 1)).toBe(3);
    expect(fieldsUsed(1, 1, 1, 2, 1)).toBe(6);
    expect(fieldsUsed(1, 1, 1, 0, 0, 4)).toBe(7);
    expect(buildingCost("robotics_factory", 0)).toEqual({ ore: 400, crystal: 120, deuterium: 200 });
    expect(buildingCost("shipyard", 0)).toEqual({ ore: 400, crystal: 200, deuterium: 100 });
    expect(buildingCost("space_station", 1)).toEqual({ ore: 1000, crystal: 0, deuterium: 250 });
  });

  it("gives L1 mines a balanced energy grid", () => {
    expect(powerOutput(1)).toBe(22);
    expect(mineEnergyDrain(1)).toBe(11);
    expect(energyFactor(1, 1, 1)).toBe(1);
    expect(energyNow(2, 2, 1).factor).toBeLessThan(1);
  });

  it("shows ore mine L3 draining more than a L1 plant produces", () => {
    expect(mineEnergyDrain(3)).toBe(39);
    expect(energyNow(3, 1, 1)).toEqual({ output: 22, drain: 50, factor: 22 / 50 });
  });

  it("lists extra energy on the next upgrade", () => {
    expect(upgradeEnergyDelta("crystal_mine", 3)).toBe(mineEnergyDrain(4) - mineEnergyDrain(3));
    expect(upgradeEnergyDelta("power_plant", 1)).toBe(powerOutput(2) - powerOutput(1));
    expect(energyAfterUpgrade("crystal_mine", 3, 1, 1).drain).toBe(mineEnergyDrain(3) + mineEnergyDrain(2));
    expect(upgradeWouldCauseEnergyDeficit("ore_mine", 1, 1, 1)).toBe(true);
    expect(upgradeWouldCauseEnergyDeficit("ore_mine", 1, 1, 8)).toBe(false);
    expect(solarSatelliteEnergy(20, 20)).toBe(30);
    expect(solarSatelliteEnergy(204, 264)).toBe(65);
    expect(solarSatelliteBaseEnergy(204, 264)).toBe(65);
    expect(solarSatelliteEnergy(204, 264, "pulsar", 1)).toBe(195);
    expect(deuteriumClimate(30)).toBeCloseTo(1.24);
    expect(energyNow(3, 1, 1, "medium", 0, 0, 0, 1, 20, 20).output).toBe(52);
  });

  it("caps working crawlers by mine levels then leftover energy", () => {
    expect(crawlerCap(1, 1, 1)).toBe(24);
    expect(crawlerProductionBonus(10)).toBe(1.002);
    expect(workingCrawlers(100, 1, 1, 0, 22, 22)).toBe(0);
    expect(workingCrawlers(100, 1, 1, 0, 522, 22)).toBe(10);
    expect(workingCrawlers(3, 1, 1, 0, 522, 22)).toBe(3);
    const grid = energyNow(1, 1, 20, "medium", 0, 0, 0, 0, 30, 30, 10);
    expect(grid.drain).toBe(mineEnergyDrain(1) + mineEnergyDrain(1) + 10 * 50);
    expect(grid.factor).toBe(1);
  });

  it("produces 33 ore per real hour at ore mine L1", () => {
    expect(GAME_HOUR_SECONDS).toBe(3600);
    expect(mineProductionPerHour(1)).toBe(33);
    expect(crystalProductionPerHour(1)).toBe(22);
    expect(harvestAmount(0, 30, GAME_HOUR_SECONDS, 10000)).toBe(30);
    expect(harvestAmount(0, 30, GAME_HOUR_SECONDS * 2, 10000)).toBe(60);
  });

  it("makes deuterium from the synthesizer, burns fusion, and charges wiki fleet fuel", () => {
    expect(deuteriumProductionPerHour(1, 30)).toBe(17);
    expect(fusionDeuteriumBurnPerHour(1)).toBe(11);
    expect(wikiFlightDistance(1, 1, 1, 1, 2, 1)).toBe(2795);
    expect(fleetFuelOneWay(1, 10, 2795)).toBe(3);
    expect(fleetFuelRoundTrip(1, 1, 1, 1, 1, 2, 1)).toBe(6);
  });

  it("caps storage with the exponential hold", () => {
    expect(storageCap(0)).toBe(10000);
    expect(storageCap(1)).toBe(20000);
    expect(storageCap(2)).toBe(40000);
    expect(storageCap(12)).toBe(18005000);
    expect(harvestAmount(9990, 30, GAME_HOUR_SECONDS, storageCap(0))).toBe(10000);
  });

  it("scales upgrade cost and time", () => {
    expect(buildingCost("deuterium_extractor", 0)).toEqual({ ore: 225, crystal: 75, deuterium: 0 });
    expect(buildingCost("deuterium_storage", 0)).toEqual({ ore: 1000, crystal: 1000, deuterium: 0 });
    expect(buildingCost("fusion_reactor", 0)).toEqual({ ore: 900, crystal: 360, deuterium: 180 });
    expect(buildingCost("ore_mine", 1).ore).toBeGreaterThan(60);
    expect(buildingCost("ore_storage", 0)).toEqual({ ore: 1000, crystal: 0, deuterium: 0 });
    expect(buildingCost("crystal_storage", 0)).toEqual({ ore: 1000, crystal: 500, deuterium: 0 });
    expect(buildingCost("ore_storage", 1)).toEqual({ ore: 2000, crystal: 0, deuterium: 0 });
    expect(buildingCost("terraformer", 0)).toEqual({ ore: 0, crystal: 50000, deuterium: 100000 });
    expect(buildingCost("terraformer", 1)).toEqual({ ore: 0, crystal: 100000, deuterium: 200000 });
    expect(buildingCost("terraformer", 9)).toEqual({ ore: 0, crystal: 25600000, deuterium: 51200000 });
    expect(terraformerEnergy(0)).toBe(1000);
    expect(terraformerEnergy(1)).toBe(2000);
    expect(terraformerEnergy(9)).toBe(512000);
    expect(terraformerExtraFields(1)).toBe(5);
    expect(terraformerExtraFields(2)).toBe(11);
    expect(terraformerExtraFields(10)).toBe(55);
    expect(terraformerFreeFields(1)).toBe(4);
    expect(terraformerFreeFields(2)).toBe(9);
    expect(terraformerFreeFields(10)).toBe(45);
    expect(planetFieldCap(173, 1)).toBe(178);
    expect(buildingTimeSeconds("ore_mine", 1)).toBeGreaterThan(buildingTimeSeconds("ore_mine", 0));
    expect(buildingTimeSeconds("ore_mine", 0)).toBe(108);
    expect(buildingTimeSeconds("ore_mine", 0, 1)).toBe(54);
    expect(buildingTimeSeconds("ore_mine", 0, 2)).toBe(36);
    expect(buildingTimeSeconds("ore_mine", 1, 1)).toBe(80);
    expect(buildingTimeSeconds("ore_mine", 0, 0, 1)).toBe(54);
    expect(buildingTimeSeconds("ore_mine", 0, 1, 1)).toBe(27);
    expect(buildingTimeSeconds("ore_mine", 0, 0, 0, 3)).toBe(36);
    expect(buildingTimeSeconds("ore_mine", 0, 0, 0, 5)).toBe(21);
    expect(researchCost(1).crystal).toBe(researchCost(0).crystal * 2);
    expect(researchTechCost("energy_tech", 0)).toEqual({ ore: 0, crystal: 800, deuterium: 400 });
    expect(researchTechCost("armour_tech", 1)).toEqual({ ore: 2000, crystal: 0, deuterium: 0 });
    expect(researchTechCost("combustion_drive", 0)).toEqual({ ore: 400, crystal: 0, deuterium: 600 });
    expect(researchTechCost("astrophysics", 1).ore).toBe(Math.floor(4000 * 1.75));
    expect(unmetResearch("energy_tech", () => 0, 0).map((need) => need.name)).toEqual(["Research lab"]);
    expect(unmetResearch("weapons_tech", () => 0, 3)[0]).toMatchObject({ name: "Research lab", level: 4 });
    expect(unmetResearch("shielding_tech", () => 0, 6).map((need) => `${need.name} ${need.level}`)).toEqual([
      "Energy technology 3",
    ]);
    expect(unmetResearch("graviton_tech", () => 0, 12)).toEqual([]);
    expect(unmetShipBuild(SHIPS.find((ship) => ship.id === "small_cargo")!, 0, () => 2).map((need) => need.name)).toEqual([
      "Shipyard",
      "Impulse drive",
    ]);
    expect(
      unmetShipBuild(SHIPS.find((ship) => ship.id === "small_cargo")!, 2, (id) =>
        id === "combustion_drive" ? 2 : 0,
      ).map((need) => `${need.name} ${need.level}`),
    ).toEqual(["Impulse drive 5"]);
    expect(
      unmetShipBuild(SHIPS.find((ship) => ship.id === "small_cargo")!, 2, (id) =>
        id === "combustion_drive" ? 2 : id === "impulse_drive" ? 5 : 0,
      ),
    ).toEqual([]);
    expect(unmetShipBuild(SHIPS.find((ship) => ship.id === "light_fighter")!, 1, (id) => (id === "combustion_drive" ? 1 : 0))).toEqual(
      [],
    );
    expect(unmetShipBuild(SHIPS.find((ship) => ship.id === "light_fighter")!, 0, () => 1)[0]).toMatchObject({
      name: "Shipyard",
      level: 1,
    });
    expect(unmetShipBuild(SHIPS.find((ship) => ship.id === "deathstar")!, 12, () => 0)[0]).toMatchObject({
      name: "Hyperspace drive",
      level: 7,
    });
    expect(SHIPS.find((ship) => ship.id === "reaper")?.research.map((req) => req.id)).toEqual([
      "hyperspace_drive",
      "hyperspace_tech",
      "shielding_tech",
    ]);
    expect(SHIPS.find((ship) => ship.id === "pathfinder")?.research.map((req) => req.id)).toEqual(["hyperspace_drive"]);
    expect(
      unmetShipBuild(SHIPS.find((ship) => ship.id === "bomber")!, 8, (id) =>
        id === "impulse_drive" ? 6 : id === "plasma_tech" ? 5 : 0,
      ).map((need) => `${need.name} ${need.level}`),
    ).toEqual(["Hyperspace drive 8"]);
    const shipBlockSql = readFileSync(
      path.join(process.cwd(), "supabase/migrations/036_small_cargo_impulse_gate.sql"),
      "utf8",
    );
    const shipyardInSql: Record<string, number> = {};
    for (const line of shipBlockSql.split("\n")) {
      const m = line.match(/^\s+when '([^']+)' then (\d+)/);
      if (m) shipyardInSql[m[1]] = Number(m[2]);
    }
    const researchInSql: Record<string, { id: string; level: number }[]> = {};
    for (const line of shipBlockSql.split("\n")) {
      const m = line.match(
        /(?:els)?if id = '([^']+)' and private\.research_level\(e, '([^']+)'\) < (\d+)/,
      );
      if (!m) continue;
      const [, shipId, techId, level] = m;
      (researchInSql[shipId] ??= []).push({ id: techId, level: Number(level) });
    }
    const sortReq = (a: { id: string; level: number }, b: { id: string; level: number }) =>
      a.id.localeCompare(b.id) || a.level - b.level;
    for (const ship of SHIPS) {
      expect(shipyardInSql[ship.id], `${ship.id} shipyard in SQL`).toBe(ship.shipyard);
      const fromCatalog = ship.research.map((req) => ({ id: req.id, level: req.level })).sort(sortReq);
      const fromSql = [...(researchInSql[ship.id] ?? [])].sort(sortReq);
      expect(fromSql, `${ship.id} research gates in SQL`).toEqual(fromCatalog);
    }
    expect(unmetDefenceBuild(DEFENCES.find((d) => d.id === "rocket_launcher")!, 0, 0, () => 0)[0]).toMatchObject({
      name: "Shipyard",
      level: 1,
    });
    expect(unmetDefenceBuild(DEFENCES.find((d) => d.id === "light_laser")!, 2, 0, () => 0).map((n) => n.name)).toEqual([
      "Energy technology",
      "Laser technology",
    ]);
    expect(unmetDefenceBuild(DEFENCES.find((d) => d.id === "antiballistic_missile")!, 1, 0, () => 0)[0]).toMatchObject({
      name: "Missile silo",
      level: 2,
    });
    expect(
      unmetDefenceBuild(DEFENCES.find((d) => d.id === "plasma_turret")!, 8, 0, (id) => (id === "plasma_tech" ? 7 : 0)),
    ).toEqual([]);
  });

  it("shortens flights with propulsion and caps raid loot by cargo", () => {
    expect(fleetSpeedMultiplier(0)).toBe(1);
    expect(flightSeconds(1, 1, 1, 2, 10)).toBeLessThan(flightSeconds(1, 1, 1, 2, 0));
    expect(flightSeconds(1, 1, 1, 2, 0, 1, 2)).toBeGreaterThan(flightSeconds(1, 1, 1, 2, 0, 1, 1));
    expect(attackFlightSeconds(1, 1, 1, 2, 0, 1, 1, 5000, 50)).toBeGreaterThan(
      attackFlightSeconds(1, 1, 1, 2, 0, 1, 1, 5000, 100),
    );
    expect(raidLoot(1000, 200, 1)).toBe(200);
    expect(raidLoot(1000, 10_000, 0)).toBe(250);
    expect(raidLoot(1000, 10_000, 1)).toBe(750);
    expect(raidHaul(1000, 1000, 100, 1, 1)).toEqual({ ore: 50, crystal: 50 });
    expect(RAIDER_CARGO).toBe(5000);
    expect(expeditionFleetCap(0)).toBe(0);
    expect(expeditionFleetCap(1)).toBe(1);
    expect(expeditionFleetCap(4)).toBe(2);
    expect(expeditionFleetCap(9)).toBe(3);
    expect(rollExpeditionKind(0)).toBe("nothing");
    expect(rollExpeditionKind(0.4)).toBe("resources");
    expect(rollExpeditionKind(0.75)).toBe("aliens");
    expect(rollExpeditionKind(0.78)).toBe("lost");
  });

  it("keeps the game clock aligned with the wall clock after a fetch", () => {
    expect(gameClock(1000, 5000, 5000)).toBe(1000);
    expect(gameClock(1000, 5000, 5500)).toBe(1500);
    expect(gameClock(1000, 0, 9000)).toBe(9000);
  });

  it("maps a timed job onto a 0–1 progress bar", () => {
    expect(progressToward(1000, 1000, 0)).toBe(0);
    expect(progressToward(1000, 1000, 500)).toBe(0.5);
    expect(progressToward(1000, 1000, 1000)).toBe(1);
    expect(progressToward(null, 1000, 500)).toBe(0);
  });

  it("keeps mid-job progress when another device opens with remaining time", () => {
    const started = 1_000_000;
    const now = started + 15 * 60 * 1000;
    const completes = started + 30 * 60 * 1000;
    const span = effectiveJobDurationMs(completes, 30 * 60 * 1000, now, started);
    expect(span).toBe(30 * 60 * 1000);
    expect(progressToward(completes, span, now)).toBeCloseTo(0.5);
    expect(effectiveJobDurationMs(completes, 30 * 60 * 1000, now)).toBe(30 * 60 * 1000);
    expect(progressToward(completes, 30 * 60 * 1000, now)).toBeCloseTo(0.5);
  });

  it("reads start/end from ISO timestamps the way empire_state_json returns them", () => {
    const startedAt = "2026-09-30T18:00:00.000Z";
    const completesAt = "2026-09-30T18:30:00.000Z";
    const now = Date.parse("2026-09-30T18:15:00.000Z");
    const remainingAsSpan = Date.parse(completesAt) - now;
    const span = effectiveJobDurationMs(completesAt, 30 * 60 * 1000, now, startedAt);
    expect(remainingAsSpan).toBe(15 * 60 * 1000);
    expect(progressToward(completesAt, remainingAsSpan, now)).toBe(0);
    expect(span).toBe(30 * 60 * 1000);
    expect(progressToward(completesAt, span, now)).toBeCloseTo(0.5);
  });

  it("refunds the remaining share of an upgrade cost", () => {
    expect(cancelRefund({ ore: 90, crystal: 22 }, 0)).toEqual({ ore: 90, crystal: 22, deuterium: 0 });
    expect(cancelRefund({ ore: 90, crystal: 22 }, 0.5)).toEqual({ ore: 45, crystal: 11, deuterium: 0 });
    expect(cancelRefund({ ore: 90, crystal: 22 }, 1)).toEqual({ ore: 0, crystal: 0, deuterium: 0 });
    expect(cancelRefund({ ore: 400, crystal: 120, deuterium: 200 }, 0.5)).toEqual({
      ore: 200,
      crystal: 60,
      deuterium: 100,
    });
  });

  it("prices defences from the wiki tables", () => {
    expect(defenceCost("rocket_launcher")).toEqual({ ore: 2000, crystal: 0, deuterium: 0 });
    expect(defenceCost("light_laser")).toEqual({ ore: 1500, crystal: 500, deuterium: 0 });
    expect(defenceCost("heavy_laser")).toEqual({ ore: 6000, crystal: 2000, deuterium: 0 });
    expect(defenceCost("ion_cannon")).toEqual({ ore: 5000, crystal: 3000, deuterium: 0 });
    expect(defenceCost("gauss_cannon")).toEqual({ ore: 20000, crystal: 15000, deuterium: 2000 });
    expect(defenceCost("plasma_turret")).toEqual({ ore: 50000, crystal: 50000, deuterium: 30000 });
    expect(defenceCost("small_shield_dome")).toEqual({ ore: 10000, crystal: 10000, deuterium: 0 });
    expect(defenceCost("large_shield_dome")).toEqual({ ore: 50000, crystal: 50000, deuterium: 0 });
    expect(defenceCost("antiballistic_missile")).toEqual({ ore: 8000, crystal: 0, deuterium: 2000 });
    expect(defenceCost("interplanetary_missile")).toEqual({ ore: 12500, crystal: 2500, deuterium: 10000 });
    expect(defenceSpec("small_shield_dome").unique).toBe(true);
    expect(defenceTimeSeconds("gauss_cannon")).toBeGreaterThan(defenceTimeSeconds("rocket_launcher"));
    expect(defenceSpec("rocket_launcher")).toMatchObject({ hull: 2000, shield: 20, attack: 80 });
    expect(defenceSpec("light_laser")).toMatchObject({ hull: 2000, shield: 25, attack: 100 });
    expect(defenceSpec("heavy_laser")).toMatchObject({ hull: 8000, shield: 100, attack: 250 });
    expect(defenceSpec("ion_cannon")).toMatchObject({ hull: 8000, shield: 500, attack: 150 });
    expect(defenceSpec("gauss_cannon")).toMatchObject({ hull: 35000, shield: 200, attack: 1100 });
    expect(defenceSpec("plasma_turret")).toMatchObject({ hull: 100000, shield: 300, attack: 3000 });
    expect(defenceSpec("small_shield_dome")).toMatchObject({ hull: 20000, shield: 2000, attack: 1 });
    expect(defenceSpec("large_shield_dome")).toMatchObject({ hull: 100000, shield: 10000, attack: 1 });
    expect(defenceSpec("antiballistic_missile")).toMatchObject({ hull: 8000, shield: 1, attack: 1 });
    expect(defenceSpec("interplanetary_missile")).toMatchObject({ hull: 15000, shield: 1, attack: 12000 });
  });

  it("scales pirate waves with guns and resolves simultaneous fire", () => {
    expect(pirateWavesPerHour(0)).toBe(1);
    expect(pirateWavesPerHour(8)).toBe(2);
    expect(pirateWaveSize(3, 0)).toBe(3);
    expect(pirateWaveSize(3, 1)).toBe(4);
    const counts = { ...emptyDefenceCounts(), rocket_launcher: 5 };
    const fight = pirateCombat(counts, 3, 1000, 1000, 0, 0);
    expect(fight.planetAtk).toBe(400);
    expect(fight.piratesLost).toBe(3);
    expect(fight.piratesLeft).toBe(0);
    expect(fight.counts.rocket_launcher).toBe(4);
    expect(fight.loot).toEqual({ ore: 0, crystal: 0 });
  });

  it("turns 30% of wrecked hull metal and crystal into debris", () => {
    expect(debrisFromWrecks(1, 3000, 1000)).toEqual({ ore: 900, crystal: 300 });
    expect(debrisFromWrecks(0, 3000, 1000)).toEqual({ ore: 0, crystal: 300 });
    expect(debrisVisible(0, 300)).toBe(false);
    expect(debrisVisible(900, 300)).toBe(true);
    expect(harvestDebris(1000, 1000, 20000)).toEqual({ ore: 1000, crystal: 1000 });
    expect(harvestDebris(30000, 10000, 20000)).toEqual({ ore: 15000, crystal: 5000 });
    expect(harvestDebris(0, 0, 20000)).toEqual({ ore: 0, crystal: 0 });
    expect(maxPlanets(0)).toBe(1);
    expect(maxPlanets(1)).toBe(2);
    expect(maxPlanets(2)).toBe(2);
    expect(maxPlanets(3)).toBe(3);
    expect(colonizeSlotRange(1)).toEqual({ min: 7, max: 9 });
    expect(colonizeSlotRange(4)).toEqual({ min: 6, max: 10 });
    expect(colonizeSlotRange(15)).toEqual({ min: 1, max: 15 });
    expect(canColonizeSlot(8, 1)).toBe(true);
    expect(canColonizeSlot(3, 1)).toBe(false);
  });
});

describe("wiki rank scores", () => {
  it("awards 1 score point per 1000 resources spent on finished assets", () => {
    expect(spentOnBuildingLevels("ore_mine", 1) + spentOnBuildingLevels("crystal_mine", 1) + spentOnBuildingLevels("power_plant", 1)).toBe(252);
    expect(resourcesToScorePoints(252)).toBe(0);
    expect(resourcesToScorePoints(2000)).toBe(2);
    expect(
      scoreResources({
        buildings: {},
        research: {},
        defences: { rocket_launcher: 10 },
        ships: {},
      }),
    ).toBe(20_000);
    expect(resourcesToScorePoints(20_000)).toBe(20);
  });

  it("counts deuterium on research and ships still in flight", () => {
    expect(spentOnResearchLevels("energy_tech", 1)).toBe(1200);
    expect(researchRankPoints({ energy_tech: 2, laser_tech: 1 })).toBe(3);
    expect(
      scoreResources({
        buildings: {},
        research: {},
        defences: {},
        ships: { small_cargo: 1 },
        fleets: [{ composition: { small_cargo: 2 } }],
      }),
    ).toBe(3 * (2000 + 2000));
    expect(fleetRankPoints({ solar_satellite: 4 }, [{ raiders: 3 }])).toBe(7);
  });
});

describe("espionage", () => {
  it("matches the wiki probe counts for a research view", () => {
    const needed = (delta: number) => espionageProbesNeeded("research", 10, 10 + delta);
    expect(needed(-3)).toBe(1);
    expect(needed(-2)).toBe(3);
    expect(needed(-1)).toBe(6);
    expect(needed(0)).toBe(7);
    expect(needed(1)).toBe(8);
    expect(needed(2)).toBe(11);
    expect(needed(3)).toBe(16);
  });

  it("raises counter-espionage odds with more probes", () => {
    expect(counterEspionageChance(2, 2, 1)).toBeCloseTo(3 / 9);
    expect(counterEspionageChance(2, 2, 3)).toBeCloseTo(9 / 9);
    expect(counterEspionageChance(2, 0, 1)).toBeCloseTo(1 / 9);
  });
});
