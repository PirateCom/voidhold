/** Snapshot of what the live code actually does across the current Voidhold build. */

export const PLAYABLE_PERCENT = 85;

export const DEBUG_INFO = {
  title: "Voidhold build status",
  playable: true,
  percent: PLAYABLE_PERCENT,
  headline:
    "Full multi-planet loop is live (~85% complete). Resource mines with 0–100% output throttles, colonies, facilities, empire-wide research with IRN, shipyard, defences, galaxy combat, IPMs, asteroid belt mining, daily + agent missions, Stellar Events, Pirate Strongholds, and Command Core Ancient Relics are all active.",
  working: [
    "Authentication with 'Keep me logged in' toggle (400-day persistent cookies when enabled, browser-session cookies when disabled) and persistent server catch-up clocks. Economy speed is per empire (debug 1× / 3× / 5× on Commander).",
    "Ore, crystal, and deuterium mines with mobile-first 0–100% output throttles (10% steps) that scale both production and energy consumption. Synthesizer output scales with planet temperature. Storage tanks cap all three resources.",
    "Solar plant, Fusion reactor (burns deuterium; drops offline if the tank hits 0), and Solar satellites (temperature + system star multiplier). Docked Crawlers draw 50 leftover energy each (up to 8 per mine level) and add +0.02% mine production per working unit.",
    "Facilities with prerequisite gates and Robotics / Nanite build-time scaling. Terraformer spends crystal, deuterium, and energy check to add floor(5.5 × level) planet fields. Upgrading the Research Lab blocks starting new research on that world while other buildings can upgrade freely.",
    "All listed researches in one empire-wide queue. Intergalactic Research Network (IRN) automatically links your highest qualifying colony labs to speed up research duration.",
    "Per-planet building, defence, and shipyard queues (capped at 999 units) with embedded progress bars inside the action buttons. Building upgrades can be cancelled for a partial refund; defence queues can be cancelled for a full refund of remaining units.",
    "Multi-planet colonization (Slots 1–15 via Colony Ships and Astronomy), planet renaming, planet abandonment, one-way fleet Deploy, and two-way resource Transport between colonies.",
    "Galaxy combat against commanders and abandoned worlds: 6-round combat, rapid fire, shield regeneration, 50% plunder cap, 30% ship debris fields (with 2h decay delay), 70% defence rebuild (85% with Repair Nanites relic), and 6-attack/24h bash protection.",
    "Interplanetary Missiles (IPMs) launched from the attack sheet (Impulse range 5×level−1 systems) with 1:1 Anti-Ballistic Missile interception.",
    "Expeditions (slot 16 or empty slots after Astronomy 1): any flyable docked ship can launch. Including a Pathfinder grants a ×2 expedition resource find bonus and boosts Ancient Relic discovery.",
    "Recyclers harvest orbital debris fields; Mining Barges sit on shared Asteroid Belts (slots 17/18) and auto-return when full or when the belt empties (24h belt refill; spy probes report belt stock and active miners).",
    "42 numbered Directives, 4 UTC Daily Missions (belt mining, espionage, pirate wave/guns, transport/expedition), and 3 Agent Mission chains.",
    "Comms split into Fleets / News / Admin with unread indicators, 7-day report retention, and operator quick-fill presets for common player issues and universe resets.",
    "Expansion mechanics: System-Wide Stellar Events (Solar Flare, Ion Storm, Micrometeorite Shower), co-op/competitive Pirate Strongholds with hull bounties and vault jackpots, and 4 socketable Command Core Ancient Relics (max 2 per planet).",
  ],
  missing: [
    "No player alliances, ACS joint attacks, or Alliance Depot fuel holding.",
    "Moon creation from battle debris and moon-only facilities (Lunar Base, Sensor Phalanx, Jump Gate) and Space Dock wreck recovery remain disabled.",
    "No NPC merchant or player marketplace.",
  ],
} as const;
