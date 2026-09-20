"use server";

import { createClient } from "@/lib/supabase/server";
import type { BuildingId, EmpireState } from "@/lib/game/types";

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

export async function researchPropulsion(): Promise<EmpireState> {
  return rpc("start_research");
}

export async function buildRaiders(count: number): Promise<EmpireState> {
  return rpc("queue_raiders", { p_count: count });
}

export async function launchRaid(system: number, slot: number, raiders: number): Promise<EmpireState> {
  return rpc("send_raid", { p_system: system, p_slot: slot, p_raiders: raiders });
}
