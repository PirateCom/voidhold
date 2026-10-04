/** Snapshot of what the live code actually does, vs a full OGame-style session. */

export const PLAYABLE_PERCENT = 68;

export const DEBUG_INFO = {
  title: "Voidhold status",
  playable: true,
  percent: PLAYABLE_PERCENT,
  headline:
    "Yes — you can play a full single-planet loop. About 66% of a wiki OGame session is in the code. The planet-builder slice (mines, deuterium, facilities, research, yard, guns, NPC raids, pirates) is closer to 80%.",
  working: [
    "Login, persistent catch-up clocks. Economy speed is per empire (debug 1× / 3× / 5× on Commander). Switching speed resets that empire. Production, building, ship, and defence time scale; research stays on the short clocks. Fleet travel uses wiki distance and hull base speed with drive bonuses.",
    "Ore, crystal, and deuterium mines. Synthesizer uses wiki temperature. Tanks cap all three. Fusion burns deut and drops out if the tank is empty. Solar satellites add wiki energy from average temperature, then the system star bonus. Crawlers stay docked: working units are min(owned, mine levels × 8, leftover energy after mines / 50); each working unit uses 50 energy and adds 0.02% mine production. Extra units idle and draw no energy.",
    "Facilities, research, and ships spend wiki deuterium costs. Attacks and expeditions pay round-trip fuel.",
    "Facilities with wiki gates and robotics/nanite build-time. Terraformer spends wiki crystal/deuterium/energy and adds floor(5.5 × level) fields. Research runs while other buildings upgrade; the lab itself blocks new techs while it is upgrading.",
    "All listed researches, one empire queue, research-lab gates on the planet you are viewing. Combustion is propulsion and is already available on every colony.",
    "All listed hulls and defences if gates are met. Each planet has its own building, defence, and shipyard queue. Finished hulls dock at that planet. Deploy stations them on another of your worlds (optional cargo, one-way). Build time per unit is (metal + crystal) / 12500 hours, divided by (1 + robotics) × 2^nanite × economy speed.",
    "Galaxy attacks on commanders and abandoned worlds: any flyable hull, speed 10–100%, six combat rounds, plunder up to half of each resource. Bash protection stops a seventh attack on the same commander planet inside 24 hours unless they hit you back. Espionage probes and recall stay available. Galaxy rows show each owner's planet icon.",
    "Fleet page lists outbound and incoming fleets with route, ETA, and an expandable ship and cargo breakdown.",
    "Recyclers harvest debris fields (metal and crystal only, cargo filled in proportion to the field). Instant collect on arrival, then return.",
    "Colony ships colonize empty slots 1–15. Astrophysics 1 is required; planet cap is 1 + round(level/2), and slots stay near position 8 until higher levels. The colony ship is consumed on success.",
    "Expeditions from slot 16 after Astrophysics 1 (small cargo only, wiki flight, 1-minute hold).",
    "Incoming pirate strikes (10 real minutes), simplified simultaneous-fire combat, battle reports. Comms reports can be deleted and expire after 7 days.",
    "Debris after wrecks (30% ship metal/crystal; map icon when the field is over 300). Rank is wiki Scores: 1 point per 1000 resources spent on finished buildings, research, ships, and guns.",
    "42 numbered directives: beginner buildings, then research, ships, and defences. Rewards in ore, crystal, and deuterium. Tracked directives show on the resources, facilities, research, shipyard, and defence pages; the directives page opens on it. No mine-output % sliders.",
    "Missions (WIP): three agents offer harvest, expedition, espionage, and pirate-defence contracts with resource rewards.",
  ],
  missing: [
    "No alliances or depot parking.",
    "Pathfinder expedition fields are unused.",
    "Missiles (fire/silo war), space dock repair, phalanx, jump gate, Collector class crawler bonus, and IRN lab-sharing are catalogued but not functional.",
    "Expeditions still launch small cargo only. Fuel uses wiki distance and the speed setting. Flight time uses wiki distance, hull base speed, and drive bonuses.",
    "Pirate waves stay the simpler gunfight. Officers, merchant, and marketplace are absent.",
  ],
} as const;
