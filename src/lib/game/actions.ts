"use server";

import { createClient } from "@/lib/supabase/server";
import type {
  BuildingId,
  DefenceId,
  EmpireState,
  HighscoreEntry,
  ResearchId,
  SolarSystemView,
} from "@/lib/game/types";

function asState(data: unknown): EmpireState {
  return data as EmpireState;
}

function rpcError(error: { message: string } | null): never {
  throw new Error(error?.message ?? "The void did not answer.");
}

async function rpc(fn: string, args: Record<string, unknown> = {}): Promise<EmpireState> {
  const supabase = await createClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const { data, error } = await supabase.rpc(fn, args);
  if (error) rpcError(error);
  return asState(data);
}

export async function loadEmpireState(): Promise<EmpireState | null> {
  const supabase = await createClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;
  const { data, error } = await supabase.rpc("get_empire_state");
  if (error) rpcError(error);
  return asState(data);
}

export async function upgradeBuilding(building: BuildingId): Promise<EmpireState> {
  return rpc("start_upgrade", { p_building: building });
}

export async function cancelBuildingUpgrade(): Promise<EmpireState> {
  return rpc("cancel_upgrade");
}

export async function resetEmpireProgress(): Promise<EmpireState> {
  return rpc("reset_empire");
}

export async function startResearch(id: ResearchId): Promise<EmpireState> {
  return rpc("start_research", { p_id: id });
}

export async function buildRaiders(count: number): Promise<EmpireState> {
  return rpc("queue_raiders", { p_count: count });
}

export async function queueShip(id: string, count: number): Promise<EmpireState> {
  return rpc("queue_ship", { p_id: id, p_count: count });
}

export async function launchRaid(
  galaxy: number,
  system: number,
  slot: number,
  raiders: number,
): Promise<EmpireState> {
  return rpc("send_raid", { p_galaxy: galaxy, p_system: system, p_slot: slot, p_raiders: raiders });
}

export async function launchAttack(
  galaxy: number,
  system: number,
  slot: number,
  ships: Record<string, number>,
  speed: number,
): Promise<EmpireState> {
  return rpc("send_attack", {
    p_galaxy: galaxy,
    p_system: system,
    p_slot: slot,
    p_ships: ships,
    p_speed: speed,
  });
}

export async function launchSpy(
  galaxy: number,
  system: number,
  slot: number,
  probes: number,
): Promise<EmpireState> {
  return rpc("send_spy", { p_galaxy: galaxy, p_system: system, p_slot: slot, p_probes: probes });
}

export async function launchHarvest(
  galaxy: number,
  system: number,
  slot: number,
  recyclers: number,
): Promise<EmpireState> {
  return rpc("send_harvest", { p_galaxy: galaxy, p_system: system, p_slot: slot, p_recyclers: recyclers });
}

export async function launchColonize(
  galaxy: number,
  system: number,
  slot: number,
  ships: number,
): Promise<EmpireState> {
  return rpc("send_colonize", { p_galaxy: galaxy, p_system: system, p_slot: slot, p_ships: ships });
}

export async function selectPlanet(planetId: number): Promise<EmpireState> {
  return rpc("select_planet", { p_planet_id: planetId });
}

export async function launchExpedition(
  galaxy: number,
  system: number,
  ships: Record<string, number>,
): Promise<EmpireState> {
  return rpc("send_expedition", { p_galaxy: galaxy, p_system: system, p_ships: ships });
}

export async function loadSolarSystem(galaxy: number, system: number): Promise<SolarSystemView> {
  const supabase = await createClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const { data, error } = await supabase.rpc("get_solar_system", {
    p_galaxy: galaxy,
    p_system: system,
  });
  if (error) rpcError(error);
  return data as SolarSystemView;
}

export async function queueDefence(id: DefenceId, count: number): Promise<EmpireState> {
  return rpc("queue_defence", { p_id: id, p_count: count });
}

export async function spawnPirateWave(): Promise<EmpireState> {
  return rpc("spawn_pirates");
}

export async function setPirateRaids(enabled: boolean): Promise<EmpireState> {
  return rpc("set_pirate_raids", { p_enabled: enabled });
}

export async function fillResources(): Promise<EmpireState> {
  return rpc("debug_fill_resources");
}

export async function setEconomySpeed(speed: 1 | 3 | 5): Promise<EmpireState> {
  return rpc("debug_set_economy_speed", { p_speed: speed });
}

export async function claimDirective(id: string): Promise<EmpireState> {
  return rpc("claim_directive", { p_id: id });
}

export async function recallFleet(id: number): Promise<EmpireState> {
  return rpc("recall_fleet", { p_id: id });
}

export async function loadHighscores(): Promise<HighscoreEntry[]> {
  const supabase = await createClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  const { data, error } = await supabase.rpc("get_highscores");
  if (error) rpcError(error);
  return (data ?? []) as HighscoreEntry[];
}

export async function deleteOwnAccount(confirmation: string): Promise<void> {
  const supabase = await createClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const { error } = await supabase.rpc("delete_own_account", { p_confirmation: confirmation });
  if (error) rpcError(error);
  await supabase.auth.signOut();
}
