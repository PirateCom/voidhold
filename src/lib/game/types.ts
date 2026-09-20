export type BuildingId = "ore_mine" | "crystal_mine" | "power_plant";

export type PlanetRow = {
  id: number;
  owner_id: string | null;
  galaxy: number;
  system: number;
  slot: number;
  name: string;
  ore: number;
  crystal: number;
  last_harvested_at: string;
  ore_mine: number;
  crystal_mine: number;
  power_plant: number;
  upgrade_building: BuildingId | null;
  upgrade_completes_at: string | null;
};

export type EmpireRow = {
  user_id: string;
  home_planet_id: number;
  propulsion_level: number;
  raiders: number;
  raiders_queued: number;
  raider_completes_at: string | null;
  research_completes_at: string | null;
};

export type FleetRow = {
  id: number;
  owner_id: string;
  origin_planet_id: number;
  dest_planet_id: number;
  dest_name?: string;
  dest_system?: number;
  dest_slot?: number;
  raiders: number;
  mission: "attack" | "return";
  arrives_at: string;
  cargo_ore: number;
  cargo_crystal: number;
  status: "en_route" | "completed";
  report: string | null;
};

export type ReportRow = {
  id: number;
  created_at: string;
  title: string;
  body: string;
  loot_ore: number;
  loot_crystal: number;
};

export type GalaxyCell = {
  system: number;
  slot: number;
  kind: "empty" | "home" | "player" | "npc";
  planet_id: number | null;
  name: string | null;
  owner_name: string | null;
};

export type EmpireState = {
  profile: { user_id: string; display_name: string };
  planet: PlanetRow;
  empire: EmpireRow;
  fleets: FleetRow[];
  galaxy: GalaxyCell[];
  reports: ReportRow[];
  server_now: string;
};
