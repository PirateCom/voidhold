/** Snapshot of what the live code actually does, vs a full OGame-style session. */

export const PLAYABLE_PERCENT = 55;

export const DEBUG_INFO = {
  title: "Voidhold status",
  playable: true,
  percent: PLAYABLE_PERCENT,
  headline:
    "Yes — you can play a full single-planet loop. About 55% of a wiki OGame session is in the code. The planet-builder slice (mines, facilities, research, yard, guns, NPC raids, pirates) is closer to 70%.",
  working: [
    "Login, one homeworld, persistent catch-up clocks (1 game-hour = 60 real seconds).",
    "Ore and crystal mines, solar plant, storage, energy shortfall slowing mines.",
    "Facilities with wiki gates and robotics/nanite build-time.",
    "All listed researches, one queue, research-lab gates. Combustion is propulsion.",
    "All listed hulls and defences if gates are met. One yard queue. 15s per hull.",
    "Galaxy map, abandoned-world raids with small cargo, recall on outbound raids/expeditions.",
    "Expeditions from slot 16 after Astrophysics 1 (small cargo only, 30s flight cap, 60s hold).",
    "Incoming pirate strikes (10 real minutes), simplified simultaneous-fire combat, battle reports.",
    "Debris after wrecks (30% ship metal/crystal; map icon when the field is over 300). Rank points.",
  ],
  missing: [
    "Deuterium production stays at +0/h. Costs list deut; buildings, research, and ships do not spend it (except debug fill).",
    "No colonization or extra planets. Astrophysics only caps expeditions.",
    "No player-vs-player combat. Other commanders are protected. No ACS, alliances, or depot parking.",
    "No spy probes or espionage reports. Communications is battle reports only.",
    "Recyclers do not harvest debris. Pathfinder expedition fields are unused. No moon chance from debris.",
    "Colony ship, missiles (fire/silo war), solar-satellite energy, crawlers, space dock repair, phalanx, jump gate, terraformer fields, and IRN lab-sharing are catalogued but not functional.",
    "Raids and expeditions only launch small cargo. Mixed fleets and wiki flight/fuel times are not in.",
    "Combat is not plasma-round OGame. Fusion output exists; fusion does not burn deuterium. Officers, merchant, and marketplace are absent.",
  ],
} as const;
