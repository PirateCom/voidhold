export type AdminMessagePreset = {
  id: string;
  label: string;
  title: string;
  body: string;
};

/**
 * Operator presets for common player issues and game mechanics questions.
 * Selecting a preset fills the Comms notice composer so the operator can tweak or send immediately.
 */
export const ADMIN_MESSAGE_PRESETS: readonly AdminMessagePreset[] = [
  {
    id: "timer_desync",
    label: "Timer stuck at 0:00",
    title: "Timer or Queue Stuck at 0:00",
    body: "If a building upgrade, research, shipyard job, or fleet countdown stays at 0:00, refresh the page or switch tabs once to sync with the server. All timers run on server clocks — no progress or resources are lost.",
  },
  {
    id: "production_drop",
    label: "Production dropped / stopped",
    title: "Resource Production Slowed or Stopped",
    body: "If your mines are producing less than expected or have stopped:\n1. Check Energy in the top bar — when energy is negative, mines run below 100% efficiency. Upgrade your Solar Plant, Fusion Reactor, or build Solar Satellites.\n2. Check Storage capacity — production stops when Ore, Crystal, or Deuterium Storage is full.",
  },
  {
    id: "fusion_outage",
    label: "Fusion reactor offline",
    title: "Fusion Reactor Offline (Empty Deuterium Tank)",
    body: "Fusion Reactors burn deuterium every hour to generate power. If a planet's deuterium tank hits 0, its Fusion Reactor drops offline and mine efficiency falls. Keep a deuterium buffer in storage or upgrade your Solar Plant.",
  },
  {
    id: "research_blocked",
    label: "Can't start research",
    title: "Why Research Is Locked or Unavailable",
    body: "Only one technology can be researched at a time across your empire. Also keep in mind:\n• You cannot start research on a planet while its Research Lab is upgrading.\n• The planet you launch research from must meet that technology's required Research Lab level.",
  },
  {
    id: "no_free_fields",
    label: "No free planet fields",
    title: "Planet Out of Building Fields",
    body: "Every building level uses 1 planet field. When your planet reaches its field cap, upgrades show \"No free fields\". Build or upgrade a Terraformer in Facilities to add more buildable fields to your planet.",
  },
  {
    id: "fleet_blocked",
    label: "Can't launch fleet / attack",
    title: "Fleet Launch Blocked (Slots, Fuel, or Bash Rule)",
    body: "If you cannot dispatch a fleet mission, check:\n• Fleet slots: Upgrade Computer Technology to fly more fleets at once.\n• Deuterium fuel: Fleets need round-trip deuterium on the origin planet.\n• Bash protection: You can attack the same commander planet at most 6 times within 24 hours unless they attack you back.",
  },
  {
    id: "mining_barges",
    label: "Mining barges returned early",
    title: "Why Mining Barges Returned From Asteroid Belts",
    body: "Mining Barges stationed on asteroid belts (slots 17 and 18) automatically return to base when their cargo holds fill up or when the belt is depleted by miners. Empty asteroid belts refill 24 hours after depletion.",
  },
  {
    id: "hotfix_reload",
    label: "Hotfix / reload notice",
    title: "Update Deployed — Please Refresh",
    body: "We have deployed a fix for reported game issues. Please refresh or reopen Voidhold to load the latest build. All active upgrades, research, and fleet missions continued running normally on the server.",
  },
  {
    id: "universe_reset",
    label: "Universe reset to 0",
    title: "Universe Reset — Fresh Start",
    body: "The universe has been reset to 0 for a fresh cycle. All empires, planets, buildings, research, fleets, and highscores have been wiped back to starting conditions. Claim your new homeworld, fire up your mines, and good luck out in the dark, Commanders!",
  },
];
