/** Snapshot of what the live code actually does, vs a full OGame-style session. */

export const PLAYABLE_PERCENT = 62;

export const DEBUG_INFO = {
  title: "Voidhold status",
  playable: true,
  percent: PLAYABLE_PERCENT,
  headline:
    "Yes — you can play a full single-planet loop. About 62% of a wiki OGame session is in the code. The planet-builder slice (mines, deuterium, facilities, research, yard, guns, NPC raids, pirates) is closer to 75%.",
  working: [
    "Login, one homeworld, persistent catch-up clocks (1 game-hour = 60 real seconds).",
    "Ore, crystal, and deuterium mines. Synthesizer uses wiki temperature. Tanks cap all three. Fusion burns deut and drops out if the tank is empty. Solar satellites add wiki energy from average temperature, then the system star bonus.",
    "Facilities, research, and ships spend wiki deuterium costs. Small-cargo raids and expeditions pay round-trip fuel.",
    "Facilities with wiki gates and robotics/nanite build-time. Terraformer spends wiki crystal/deuterium/energy and adds floor(5.5 × level) fields. Research runs while other buildings upgrade; the lab itself blocks new techs while it is upgrading.",
    "All listed researches, one queue, research-lab gates. Combustion is propulsion.",
    "All listed hulls and defences if gates are met. One yard queue. 15s per hull.",
    "Galaxy map, abandoned-world raids with small cargo, recall on outbound raids/expeditions.",
    "Expeditions from slot 16 after Astrophysics 1 (small cargo only, 30s flight cap, 60s hold).",
    "Incoming pirate strikes (10 real minutes), simplified simultaneous-fire combat, battle reports.",
    "Debris after wrecks (30% ship metal/crystal; map icon when the field is over 300). Rank is wiki Scores: 1 point per 1000 resources spent on finished buildings, research, ships, and guns.",
  ],
  missing: [
    "No colonization or extra planets. Astrophysics only caps expeditions.",
    "No player-vs-player combat. Other commanders are protected. No ACS, alliances, or depot parking.",
    "No spy probes or espionage reports. Communications is battle reports only.",
    "Recyclers do not harvest debris. Pathfinder expedition fields are unused. No moon chance from debris.",
    "Colony ship, missiles (fire/silo war), crawlers, space dock repair, phalanx, jump gate, and IRN lab-sharing are catalogued but not functional.",
    "Raids and expeditions only launch small cargo. Flight clocks stay short; fuel uses wiki distance.",
    "Combat is not plasma-round OGame. Officers, merchant, and marketplace are absent.",
  ],
} as const;
