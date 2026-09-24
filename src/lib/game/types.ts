import type { FacilityId } from "./ogame-data";
import type { StarType } from "./catalog";

export type BuildingId =
  | "ore_mine"
  | "crystal_mine"
  | "deuterium_extractor"
  | "power_plant"
  | "fusion_reactor"
  | "ore_storage"
  | "crystal_storage"
  | "deuterium_storage"
  | FacilityId;

export type DefenceId =
  | "small_shield_dome"
  | "large_shield_dome"
  | "rocket_launcher"
  | "light_laser"
  | "heavy_laser"
  | "gauss_cannon"
  | "ion_cannon"
  | "plasma_turret"
  | "antiballistic_missile"
  | "interplanetary_missile";

export type PlanetRow = {
  id: number;
  owner_id: string | null;
  galaxy: number;
  system: number;
  slot: number;
  name: string;
  temp_min: number;
  temp_max: number;
  max_fields: number;
  diameter_km: number;
  ore: number;
  crystal: number;
  deuterium: number;
  last_harvested_at: string;
  ore_mine: number;
  crystal_mine: number;
  deuterium_extractor: number;
  power_plant: number;
  fusion_reactor: number;
  ore_storage: number;
  crystal_storage: number;
  deuterium_storage: number;
  robotics_factory: number;
  shipyard: number;
  research_lab: number;
  alliance_depot: number;
  missile_silo: number;
  nanite_factory: number;
  terraformer: number;
  lunar_base: number;
  phalanx_sensor: number;
  stargate: number;
  space_station: number;
  upgrade_building: BuildingId | null;
  upgrade_completes_at: string | null;
  small_shield_dome: number;
  large_shield_dome: number;
  rocket_launcher: number;
  light_laser: number;
  heavy_laser: number;
  ion_cannon: number;
  gauss_cannon: number;
  plasma_turret: number;
  antiballistic_missile: number;
  interplanetary_missile: number;
  defence_building: DefenceId | null;
  defences_queued: number;
  defence_completes_at: string | null;
};

export type ResearchId =
  | "energy_tech"
  | "laser_tech"
  | "ion_tech"
  | "hyperspace_tech"
  | "plasma_tech"
  | "combustion_drive"
  | "impulse_drive"
  | "hyperspace_drive"
  | "espionage_tech"
  | "computer_tech"
  | "astrophysics"
  | "intergalactic_research_network"
  | "graviton_tech"
  | "weapons_tech"
  | "shielding_tech"
  | "armour_tech";

export type EmpireRow = {
  user_id: string;
  home_planet_id: number;
  propulsion_level: number;
  energy_tech: number;
  laser_tech: number;
  ion_tech: number;
  hyperspace_tech: number;
  plasma_tech: number;
  impulse_drive: number;
  hyperspace_drive: number;
  espionage_tech: number;
  computer_tech: number;
  astrophysics: number;
  intergalactic_research_network: number;
  graviton_tech: number;
  weapons_tech: number;
  shielding_tech: number;
  armour_tech: number;
  raiders: number;
  raiders_queued: number;
  raider_completes_at: string | null;
  ships?: Record<string, number>;
  ship_building?: string | null;
  research_tech: ResearchId | null;
  research_completes_at: string | null;
  next_pirate_at: string | null;
};

export type FleetRow = {
  id: number;
  owner_id: string | null;
  origin_planet_id: number;
  dest_planet_id: number | null;
  dest_name?: string;
  dest_galaxy?: number;
  dest_system?: number;
  dest_slot?: number;
  origin_name?: string | null;
  origin_galaxy?: number;
  origin_system?: number;
  origin_slot?: number;
  created_at?: string;
  raiders: number;
  mission: "attack" | "return" | "expedition" | "expedition_hold" | "expedition_return";
  arrives_at: string;
  cargo_ore: number;
  cargo_crystal: number;
  cargo_deuterium?: number;
  status: "en_route" | "completed";
  report: string | null;
  inbound?: boolean;
  attacker_name?: string | null;
  ship_count?: number;
  composition?: Record<string, number>;
};

export type ReportRow = {
  id: number;
  created_at: string;
  title: string;
  body: string;
  loot_ore: number;
  loot_crystal: number;
};

export type SolarSlot = {
  slot: number;
  kind: "empty" | "home" | "player" | "npc" | "outer";
  planet_id: number | null;
  name: string | null;
  owner_name: string | null;
  debris_ore?: number;
  debris_crystal?: number;
};

export type SolarSystemView = {
  galaxy: number;
  system: number;
  star_type: StarType;
  multiplier: number;
  slots: SolarSlot[];
};

export type EmpireState = {
  profile: { user_id: string; display_name: string };
  planet: PlanetRow;
  empire: EmpireRow;
  star: { type: StarType; multiplier: number };
  rank: { points: number; place: number; total: number };
  fleets: FleetRow[];
  reports: ReportRow[];
  server_now: string;
};
