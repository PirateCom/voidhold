/** Snapshot of what the live code actually does, vs a full OGame-style session. */

export const PLAYABLE_PERCENT = 62;

export const DEBUG_INFO = {
  title: "Voidhold status",
  playable: true,
  percent: PLAYABLE_PERCENT,
  headline:
    "Yes — you can play a full single-planet loop. About 62% of a wiki OGame session is in the code. The planet-builder slice (mines, deuterium, facilities, research, yard, guns, NPC raids, pirates) is closer to 75%.",
  working: [
    "Login, persistent catch-up clocks. Economy speed is per empire (debug 1× / 3× / 5× on Facilities). Switching speed resets that empire. Production and building time scale; research, yard, and flights stay on the short clocks.",
    "Ore, crystal, and deuterium mines. Synthesizer uses wiki temperature. Tanks cap all three. Fusion burns deut and drops out if the tank is empty. Solar satellites add wiki energy from average temperature, then the system star bonus.",
    "Facilities, research, and ships spend wiki deuterium costs. Attacks and expeditions pay round-trip fuel.",
    "Facilities with wiki gates and robotics/nanite build-time. Terraformer spends wiki crystal/deuterium/energy and adds floor(5.5 × level) fields. Research runs while other buildings upgrade; the lab itself blocks new techs while it is upgrading.",
    "All listed researches, one empire queue, research-lab gates on the planet you are viewing. Combustion is propulsion and is already available on every colony.",
    "All listed hulls and defences if gates are met. Each planet has its own building, defence, and shipyard queue. Finished hulls dock in the empire hangar. 15s per hull.",
    "Galaxy attacks on commanders and abandoned worlds: any flyable hull, speed 10–100%, six combat rounds, plunder up to half of each resource. Espionage probes and recall stay available. NPC garrisons can sit on an ownerless world later.",
    "Recyclers harvest debris fields (metal and crystal only, cargo filled in proportion to the field). Instant collect on arrival, then return.",
    "Colony ships colonize empty slots 1–15. Astrophysics 1 is required; planet cap is 1 + round(level/2), and slots stay near position 8 until higher levels. The colony ship is consumed on success.",
    "Expeditions from slot 16 after Astrophysics 1 (small cargo only, 30s flight cap, 1-minute hold).",
    "Incoming pirate strikes (10 real minutes), simplified simultaneous-fire combat, battle reports.",
    "Debris after wrecks (30% ship metal/crystal; map icon when the field is over 300). Rank is wiki Scores: 1 point per 1000 resources spent on finished buildings, research, ships, and guns.",
    "Beginner directives with collectable ore/crystal rewards. No mine-output % sliders.",
  ],
  missing: [
    "No ACS, alliances, or depot parking. Bash protection stops a seventh attack on the same commander planet inside 24 hours unless they hit you back.",
    "Pathfinder expedition fields are unused. No moon chance from debris.",
    "Missiles (fire/silo war), crawlers, space dock repair, phalanx, jump gate, and IRN lab-sharing are catalogued but not functional.",
    "Expeditions still launch small cargo only. Flight clocks stay short; fuel uses wiki distance and the speed setting.",
    "Pirate waves stay the simpler gunfight. Officers, merchant, and marketplace are absent.",
  ],
} as const;
