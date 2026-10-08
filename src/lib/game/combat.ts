import {
  DEFENCES,
  DEBRIS_RATIO,
  SHIPS,
  defenceSpec,
  emptyDefenceCounts,
  isDefenceId,
  shipSpec,
  type DefenceCounts,
  type DefenceId,
} from "./catalog";

/** OGame attack: at most six rounds, then a draw with no plunder. */
export const COMBAT_ROUNDS = 6;
/** Wiki plunder cap: half of each resource on the planet. */
export const PLUNDER_FRACTION = 0.5;
/** Destroyed defenses are rebuilt at this chance each. Ships are not. */
export const DEFENSE_REBUILD_CHANCE = 0.7;
/** Same-planet attacks on one commander, per 24 hours. Abandoned worlds are exempt. */
export const BASH_LIMIT = 6;
export const BASH_WINDOW_MS = 24 * 60 * 60 * 1000;

const MISSILES = new Set<string>(["antiballistic_missile", "interplanetary_missile"]);

const RAPID: Record<string, Record<string, number>> = {
  heavy_fighter: { small_cargo: 3 },
  cruiser: { light_fighter: 6, rocket_launcher: 10 },
  battleship: { pathfinder: 5 },
  battlecruiser: {
    small_cargo: 3,
    large_cargo: 3,
    heavy_fighter: 4,
    cruiser: 4,
    battleship: 7,
    espionage_probe: 44,
  },
  bomber: {
    rocket_launcher: 20,
    light_laser: 20,
    heavy_laser: 10,
    ion_cannon: 10,
    gauss_cannon: 5,
    plasma_turret: 5,
  },
  destroyer: { battlecruiser: 2, light_laser: 10 },
  deathstar: {
    espionage_probe: 1250,
    solar_satellite: 1250,
    crawler: 1250,
    small_cargo: 250,
    large_cargo: 250,
    colony_ship: 250,
    recycler: 250,
    mining_barge: 250,
    light_fighter: 200,
    rocket_launcher: 200,
    light_laser: 200,
    heavy_fighter: 100,
    heavy_laser: 100,
    ion_cannon: 100,
    gauss_cannon: 50,
    cruiser: 33,
    battleship: 30,
    reaper: 30,
    bomber: 25,
    battlecruiser: 15,
    pathfinder: 10,
    destroyer: 5,
  },
  reaper: { battleship: 7, bomber: 4, destroyer: 3 },
  pathfinder: { cruiser: 3, light_fighter: 3, heavy_fighter: 2 },
  ion_cannon: { reaper: 2 },
};

const PROBE_RAPID = new Set(
  SHIPS.filter((ship) => ship.rapidFireAgainst.some(([name]) => name === "Espionage probe")).map((ship) => ship.id),
);

export type CombatTech = { weapons: number; shielding: number; armour: number };

export type CombatOutcome = "attacker" | "defender" | "draw";

type Stack = { intact: number; wounded: number; woundedHull: number; woundedShield: number };

type Profile = {
  id: string;
  attack: number;
  shield: number;
  hull: number;
  cargo: number;
  ore: number;
  crystal: number;
  defense: boolean;
};

function techScale(level: number): number {
  return 1 + 0.1 * Math.max(0, level);
}

function rapidFire(attacker: string, target: string): number {
  const listed = RAPID[attacker]?.[target];
  if (listed) return listed;
  if (
    (target === "espionage_probe" || target === "solar_satellite" || target === "crawler") &&
    PROBE_RAPID.has(attacker)
  ) {
    return 5;
  }
  return 1;
}

function profile(id: string, tech: CombatTech): Profile | null {
  if (MISSILES.has(id)) return null;
  const ship = shipSpec(id);
  if (ship) {
    return {
      id,
      attack: ship.attack * techScale(tech.weapons),
      shield: ship.shield * techScale(tech.shielding),
      hull: ship.hull * techScale(tech.armour),
      cargo: ship.cargo,
      ore: ship.cost.ore,
      crystal: ship.cost.crystal,
      defense: false,
    };
  }
  if (!isDefenceId(id)) return null;
  const gun = defenceSpec(id);
  return {
    id,
    attack: gun.attack * techScale(tech.weapons),
    shield: gun.shield * techScale(tech.shielding),
    hull: gun.hull * techScale(tech.armour),
    cargo: 0,
    ore: gun.cost.ore,
    crystal: gun.cost.crystal,
    defense: true,
  };
}

function emptyStack(): Stack {
  return { intact: 0, wounded: 0, woundedHull: 0, woundedShield: 0 };
}

function stackCount(stack: Stack): number {
  return stack.intact + (stack.wounded > 0 ? 1 : 0);
}

function alive(force: Record<string, Stack>): boolean {
  return Object.values(force).some((stack) => stackCount(stack) > 0);
}

function hullPool(stack: Stack, unit: Profile): number {
  return stack.intact * unit.hull + (stack.wounded > 0 ? stack.woundedHull : 0);
}

export function makeRng(seed: number): () => number {
  let state = seed >>> 0;
  if (state === 0) state = 1;
  return () => {
    state = (Math.imul(1664525, state) + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

/** Wiki plunder order: metal third, crystal half of the rest, deuterium, then metal, then crystal. */
export function plunder(
  capacity: number,
  metal: number,
  crystal: number,
  deuterium: number,
): { ore: number; crystal: number; deuterium: number } {
  let m = Math.floor(Math.max(0, metal) * PLUNDER_FRACTION);
  let c = Math.floor(Math.max(0, crystal) * PLUNDER_FRACTION);
  let d = Math.floor(Math.max(0, deuterium) * PLUNDER_FRACTION);
  let cap = Math.max(0, Math.floor(capacity));
  let lootM = 0;
  let lootC = 0;
  let lootD = 0;
  const take = (available: number, want: number) => Math.min(available, Math.max(0, Math.floor(want)));

  let n = take(m, cap / 3);
  lootM += n;
  m -= n;
  cap -= n;
  n = take(c, cap / 2);
  lootC += n;
  c -= n;
  cap -= n;
  n = take(d, cap);
  lootD += n;
  d -= n;
  cap -= n;
  n = take(m, cap / 2);
  lootM += n;
  m -= n;
  cap -= n;
  n = take(c, cap);
  lootC += n;
  c -= n;
  cap -= n;
  n = take(m, cap);
  lootM += n;
  cap -= n;
  n = take(d, cap);
  lootD += n;
  return { ore: lootM, crystal: lootC, deuterium: lootD };
}

function shotsToFinish(attack: number, shield: number, hull: number): number {
  if (attack <= 0 || hull <= 0) return Number.POSITIVE_INFINITY;
  if (shield > 0 && attack < shield * 0.01) return Number.POSITIVE_INFINITY;
  return Math.ceil((shield + hull) / attack);
}

function applyVolley(stack: Stack, shots: number, attack: number, shield: number, maxHull: number): Stack {
  let intact = stack.intact;
  let wounded = stack.wounded > 0 ? 1 : 0;
  let woundedHull = stack.wounded > 0 ? stack.woundedHull : maxHull;
  let woundedShield = stack.wounded > 0 ? stack.woundedShield : shield;
  let left = Math.max(0, Math.floor(shots));
  if (left <= 0 || attack <= 0 || intact + wounded <= 0) return stack;
  if (shield > 0 && attack < shield * 0.01 && (wounded === 0 || attack < woundedShield * 0.01)) {
    return stack;
  }

  if (wounded === 1) {
    const need = shotsToFinish(attack, woundedShield, woundedHull);
    if (!Number.isFinite(need)) {
      left = 0;
    } else if (left >= need) {
      left -= need;
      wounded = 0;
      woundedHull = maxHull;
      woundedShield = shield;
    } else {
      const dealt = left * attack;
      const hullDmg = Math.max(0, dealt - woundedShield);
      woundedShield = Math.max(0, woundedShield - dealt);
      woundedHull = Math.max(0, woundedHull - hullDmg);
      left = 0;
      if (woundedHull <= 0) wounded = 0;
    }
  }

  const needIntact = shotsToFinish(attack, shield, maxHull);
  if (Number.isFinite(needIntact) && needIntact > 0 && left > 0 && intact > 0) {
    const killed = Math.min(intact, Math.floor(left / needIntact));
    intact -= killed;
    left -= killed * needIntact;
    if (left > 0 && intact > 0) {
      intact -= 1;
      const dealt = left * attack;
      const hullDmg = Math.max(0, dealt - shield);
      wounded = 1;
      woundedHull = Math.max(0, maxHull - hullDmg);
      woundedShield = Math.max(0, shield - dealt);
      if (woundedHull <= 0) wounded = 0;
    }
  }

  return {
    intact,
    wounded,
    woundedHull: wounded === 1 ? woundedHull : maxHull,
    woundedShield: wounded === 1 ? woundedShield : shield,
  };
}

function focusTarget(force: Record<string, Stack>, profiles: Map<string, Profile>): string | null {
  let best: string | null = null;
  let bestPool = -1;
  for (const id of Object.keys(force).sort()) {
    const unit = profiles.get(id);
    const stack = force[id];
    if (!unit || !stack || stackCount(stack) <= 0) continue;
    const pool = hullPool(stack, unit);
    if (pool > bestPool) {
      best = id;
      bestPool = pool;
    }
  }
  return best;
}

function shoot(
  from: Record<string, Stack>,
  into: Record<string, Stack>,
  fromProfiles: Map<string, Profile>,
  intoProfiles: Map<string, Profile>,
): Record<string, Stack> {
  const next: Record<string, Stack> = {};
  for (const [id, stack] of Object.entries(into)) next[id] = { ...stack };
  const volleys = new Map<string, { attack: number; shots: number }[]>();
  for (const id of Object.keys(from).sort()) {
    const stack = from[id];
    const unit = fromProfiles.get(id);
    if (!unit || !stack || stackCount(stack) <= 0 || unit.attack <= 0) continue;
    const target = focusTarget(into, intoProfiles);
    if (!target) continue;
    const targetUnit = intoProfiles.get(target);
    if (!targetUnit) continue;
    const shots = stackCount(stack) * rapidFire(id, target);
    const list = volleys.get(target) ?? [];
    list.push({ attack: unit.attack, shots });
    volleys.set(target, list);
  }
  for (const [target, list] of volleys) {
    const unit = intoProfiles.get(target);
    if (!unit || !next[target]) continue;
    for (const volley of list) {
      next[target] = applyVolley(next[target], volley.shots, volley.attack, unit.shield, unit.hull);
    }
  }
  return next;
}

function explode(force: Record<string, Stack>, profiles: Map<string, Profile>, rng: () => number): Record<string, Stack> {
  const next: Record<string, Stack> = {};
  for (const id of Object.keys(force).sort()) {
    const stack = force[id];
    const unit = profiles.get(id);
    if (!stack || !unit) continue;
    if (stack.wounded > 0 && stack.woundedHull < unit.hull * 0.7) {
      const chance = 1 - stack.woundedHull / unit.hull;
      if (rng() < chance) {
        next[id] = { ...stack, wounded: 0, woundedHull: unit.hull, woundedShield: unit.shield };
        continue;
      }
    }
    next[id] = stack;
  }
  return next;
}

function regen(force: Record<string, Stack>, profiles: Map<string, Profile>): Record<string, Stack> {
  const next: Record<string, Stack> = {};
  for (const [id, stack] of Object.entries(force)) {
    const unit = profiles.get(id);
    next[id] = { ...stack, woundedShield: unit?.shield ?? stack.woundedShield };
  }
  return next;
}

function prune(force: Record<string, Stack>): Record<string, Stack> {
  const next: Record<string, Stack> = {};
  for (const [id, stack] of Object.entries(force)) {
    if (stackCount(stack) > 0) next[id] = stack;
  }
  return next;
}

function countsOf(ships: Record<string, number>, defenses: DefenceCounts): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const [id, n] of Object.entries(ships)) {
    if (n > 0 && !MISSILES.has(id)) counts[id] = Math.floor(n);
  }
  for (const def of DEFENCES) {
    if (MISSILES.has(def.id)) continue;
    const n = defenses[def.id] ?? 0;
    if (n > 0) counts[def.id] = Math.floor(n);
  }
  return counts;
}

function toForce(counts: Record<string, number>, tech: CombatTech): { force: Record<string, Stack>; profiles: Map<string, Profile> } {
  const force: Record<string, Stack> = {};
  const profiles = new Map<string, Profile>();
  for (const [id, n] of Object.entries(counts)) {
    if (n <= 0) continue;
    const unit = profile(id, tech);
    if (!unit) continue;
    profiles.set(id, unit);
    const stack = emptyStack();
    stack.intact = n;
    stack.woundedShield = unit.shield;
    stack.woundedHull = unit.hull;
    force[id] = stack;
  }
  return { force, profiles };
}

function survivorsOf(force: Record<string, Stack>): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const [id, stack] of Object.entries(force)) {
    const n = stackCount(stack);
    if (n > 0) counts[id] = n;
  }
  return counts;
}

function cargoOf(counts: Record<string, number>, profiles: Map<string, Profile>): number {
  let cargo = 0;
  for (const [id, n] of Object.entries(counts)) {
    cargo += n * (profiles.get(id)?.cargo ?? 0);
  }
  return cargo;
}

function unitName(id: string): string {
  return shipSpec(id)?.name ?? (isDefenceId(id) ? defenceSpec(id).name : id);
}

function lossLine(initial: Record<string, number>, left: Record<string, number>): string {
  const parts: string[] = [];
  for (const id of Object.keys(initial).sort()) {
    const lost = (initial[id] ?? 0) - (left[id] ?? 0);
    if (lost > 0) parts.push(`${lost} ${unitName(id)}`);
  }
  return parts.length > 0 ? parts.join(", ") : "none";
}

export function resolveCombat(
  attackers: Record<string, number>,
  defenders: Record<string, number>,
  attackerTech: CombatTech,
  defenderTech: CombatTech,
  rng: () => number,
): { outcome: CombatOutcome; rounds: number; attackers: Record<string, number>; defenders: Record<string, number> } {
  let att = toForce(attackers, attackerTech);
  let def = toForce(defenders, defenderTech);
  let rounds = 0;
  if (!alive(att.force) || !alive(def.force)) {
    const outcome: CombatOutcome = alive(att.force) ? "attacker" : alive(def.force) ? "defender" : "draw";
    return { outcome, rounds, attackers: survivorsOf(att.force), defenders: survivorsOf(def.force) };
  }
  while (rounds < COMBAT_ROUNDS && alive(att.force) && alive(def.force)) {
    rounds += 1;
    att = { ...att, force: regen(att.force, att.profiles) };
    def = { ...def, force: regen(def.force, def.profiles) };
    const defendersAfter = shoot(att.force, def.force, att.profiles, def.profiles);
    const attackersAfter = shoot(def.force, att.force, def.profiles, att.profiles);
    att = { ...att, force: prune(explode(attackersAfter, att.profiles, rng)) };
    def = { ...def, force: prune(explode(defendersAfter, def.profiles, rng)) };
  }
  const attackersLeft = survivorsOf(att.force);
  const defendersLeft = survivorsOf(def.force);
  const attAlive = Object.keys(attackersLeft).length > 0;
  const defAlive = Object.keys(defendersLeft).length > 0;
  const outcome: CombatOutcome = attAlive && !defAlive ? "attacker" : defAlive && !attAlive ? "defender" : "draw";
  return { outcome, rounds, attackers: attackersLeft, defenders: defendersLeft };
}

export function settleAttack(args: {
  attackers: Record<string, number>;
  defenderShips: Record<string, number>;
  defenderDefenses: DefenceCounts;
  attackerTech: CombatTech;
  defenderTech: CombatTech;
  ore: number;
  crystal: number;
  deuterium: number;
  seed: number;
}): {
  outcome: CombatOutcome;
  rounds: number;
  survivors: Record<string, number>;
  defenderShips: Record<string, number>;
  defenses: DefenceCounts;
  plunder: { ore: number; crystal: number; deuterium: number };
  debris: { ore: number; crystal: number };
  report: string;
} {
  const rng = makeRng(args.seed);
  const initialDef = countsOf(args.defenderShips, args.defenderDefenses);
  const initialAtt: Record<string, number> = {};
  for (const [id, n] of Object.entries(args.attackers)) {
    const ship = shipSpec(id);
    if (n > 0 && ship && ship.speed > 0) initialAtt[id] = Math.floor(n);
  }
  const fought = resolveCombat(initialAtt, initialDef, args.attackerTech, args.defenderTech, rng);
  const attProfiles = toForce(initialAtt, args.attackerTech).profiles;
  const defProfiles = toForce(initialDef, args.defenderTech).profiles;

  let debrisOre = 0;
  let debrisCrystal = 0;
  const addDebris = (id: string, lost: number, profiles: Map<string, Profile>) => {
    if (lost <= 0) return;
    const unit = profiles.get(id);
    if (!unit) return;
    debrisOre += Math.floor(unit.ore * DEBRIS_RATIO) * lost;
    debrisCrystal += Math.floor(unit.crystal * DEBRIS_RATIO) * lost;
  };
  for (const id of Object.keys(initialAtt)) addDebris(id, (initialAtt[id] ?? 0) - (fought.attackers[id] ?? 0), attProfiles);
  for (const id of Object.keys(initialDef)) addDebris(id, (initialDef[id] ?? 0) - (fought.defenders[id] ?? 0), defProfiles);

  const defenses = emptyDefenceCounts();
  for (const def of DEFENCES) defenses[def.id] = args.defenderDefenses[def.id] ?? 0;
  const defenderShips: Record<string, number> = { ...args.defenderShips };
  for (const id of Object.keys(initialDef)) {
    const lost = (initialDef[id] ?? 0) - (fought.defenders[id] ?? 0);
    let restored = 0;
    const unit = defProfiles.get(id);
    if (unit?.defense) {
      for (let i = 0; i < lost; i += 1) {
        if (rng() < DEFENSE_REBUILD_CHANCE) restored += 1;
      }
      defenses[id as DefenceId] = (fought.defenders[id] ?? 0) + restored;
    } else {
      defenderShips[id] = fought.defenders[id] ?? 0;
    }
  }

  const cargo = cargoOf(fought.attackers, attProfiles);
  const haul =
    fought.outcome === "attacker" ? plunder(cargo, args.ore, args.crystal, args.deuterium) : { ore: 0, crystal: 0, deuterium: 0 };
  const result =
    fought.outcome === "attacker" ? "Attacker wins" : fought.outcome === "defender" ? "Defender holds" : "Draw";
  const empty = Object.keys(initialDef).length === 0;
  const report = [
    empty ? "The hold had no fleet or defenses." : `${result} after ${fought.rounds} round${fought.rounds === 1 ? "" : "s"}.`,
    `Attacker losses: ${lossLine(initialAtt, fought.attackers)}.`,
    `Defender losses: ${lossLine(initialDef, fought.defenders)}.`,
    `Plunder ${haul.ore} ore, ${haul.crystal} crystal, ${haul.deuterium} deuterium.`,
    debrisOre + debrisCrystal > 0 ? `Debris ${debrisOre} ore, ${debrisCrystal} crystal.` : "No debris.",
  ].join(" ");

  return {
    outcome: fought.outcome,
    rounds: fought.rounds,
    survivors: fought.attackers,
    defenderShips,
    defenses,
    plunder: haul,
    debris: { ore: debrisOre, crystal: debrisCrystal },
    report,
  };
}

export function normalizeAttackSpeed(speed: number): number {
  const step = Math.round(speed / 10) * 10;
  if (!Number.isFinite(speed) || step < 10 || step > 100 || step !== speed) {
    throw new Error("Speed must be 10 to 100 percent.");
  }
  return step;
}

export function cleanFleet(ships: Record<string, number>): Record<string, number> {
  const next: Record<string, number> = {};
  for (const [id, n] of Object.entries(ships)) {
    const count = Math.floor(n);
    if (count > 0) next[id] = count;
  }
  return next;
}
