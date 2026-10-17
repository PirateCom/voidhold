import type { ResearchId } from "./voidhold-data";

export const RESEARCH_HELP: Record<ResearchId, string[]> = {
  energy_tech: [
    "Energy technology makes fusion reactors produce more energy.",
    "Later drives and weapon theories also need it, so it is worth keeping a few levels ahead of what you are unlocking.",
  ],
  laser_tech: [
    "Laser technology unlocks laser guns and is a stepping stone to ion and plasma research.",
    "Raise it when you want light lasers, heavy lasers, or the next weapon theories.",
  ],
  ion_tech: [
    "Ion technology unlocks ion weapons and is required for cruisers and plasma technology.",
    "It does not make existing guns stronger by itself — weapons technology does that.",
  ],
  hyperspace_tech: [
    "Hyperspace technology opens hyperspace drives and the biggest hulls: battlecruisers, destroyers, and the deathstar.",
    "It is a gate, not a combat bonus. Combat bonuses come from weapons, shields, and armour.",
  ],
  plasma_tech: [
    "Plasma technology unlocks plasma weapons and is required for bombers.",
    "It is a gate. Attack power still comes from weapons technology.",
  ],
  combustion_drive: [
    "Combustion drive makes ships that use this engine 10% faster per level.",
    "Small cargos, light fighters, recyclers, and probes use it until a later drive takes over.",
  ],
  impulse_drive: [
    "Impulse drive makes impulse ships 20% faster per level.",
    "At level 5 the small cargo switches to impulse drive and gets a large speed jump. Cruisers and some other hulls use impulse from the start.",
  ],
  hyperspace_drive: [
    "Hyperspace drive makes hyperspace ships 30% faster per level.",
    "At level 8 the bomber switches to this drive. Battlecruisers, destroyers, and the deathstar use it too.",
  ],
  espionage_tech: [
    "Espionage technology makes probe reports show more as you pull ahead of the target.",
    "You also need it to build probes and to start Astronomy.",
  ],
  computer_tech: [
    "Computer technology adds one fleet slot per level, so you can send more fleets at the same time.",
    "It is also required for Intergalactic Research Network.",
  ],
  astrophysics: [
    "Astronomy lets you own more colonies. You get one extra colony slot every two levels.",
    "Its cost rises by 1.75 each level instead of doubling, so it stays expensive but not as steep as other techs.",
  ],
  intergalactic_research_network: [
    "IRN makes research faster by using labs on your other planets.",
    "Research is already shared across the empire. What IRN adds is extra speed: when you start a tech on one planet, higher-level labs on colonies can help finish it.",
    "Level 1 lets one other lab join. Level 2 lets two join, and so on.",
    "The game picks the strongest labs that can actually run that tech. A lab that is too low for the tech is skipped.",
    "Always start from your best lab if you can. That planet’s lab always counts, and the resources come from there.",
    "Without IRN, only the planet you are on researches. With IRN, several labs work on the same job at once, so the wait is shorter.",
  ],
  graviton_tech: [
    "Graviton technology is the gate for the deathstar.",
    "Only level 1 is useful. It costs 300,000 energy on the planet where you start it, and no resources.",
  ],
  weapons_tech: [
    "Weapons technology adds 10% attack per level to every ship and defence you already have.",
    "It does not unlock new guns. Laser, ion, and plasma technology do that.",
  ],
  shielding_tech: [
    "Shielding technology adds 10% shield strength per level to ships and defences.",
    "It is also a gate for hyperspace technology and some hulls.",
  ],
  armour_tech: [
    "Armour technology adds 10% hull per level to ships and defences, so they survive more hits.",
  ],
};
