import type { FacilityId } from "./voidhold-data";

export const FACILITY_HELP: Record<FacilityId, string[]> = {
  robotics_factory: [
    "The robotics factory makes buildings finish faster. Time is divided by 1 plus this level, so level 1 halves the wait and level 2 cuts it to a third.",
    "You need robotics factory 2 before you can build a shipyard.",
  ],
  shipyard: [
    "The shipyard builds ships and defences. Each hull and gun still lists the shipyard level it needs.",
    "Only one ship or defence job can run on a planet at a time. Raise the yard to unlock bigger hulls and stronger guns.",
  ],
  research_lab: [
    "Each technology lists the lab level you need on this planet to start it. A higher lab also makes research finish faster.",
    "Research is empire-wide: a tech you finish here is finished on every colony. Upgrading this lab blocks new research on this planet until the upgrade is done.",
    "Intergalactic Research Network can add labs from your other planets to speed the same job. Start from your best lab when you can.",
  ],
  alliance_depot: [
    "The alliance depot can feed deuterium to an allied fleet parked here.",
    "It is only useful in universes with alliance combat, and it is not available in this session.",
  ],
  missile_silo: [
    "The missile silo stores anti-ballistic missiles and interplanetary missiles.",
    "Each level holds 10 anti-ballistic missiles and 5 interplanetary missiles. You need silo 2 to load anti-ballistic missiles and silo 4 to load interplanetary missiles.",
  ],
  nanite_factory: [
    "Each nanite level halves construction time again for buildings, ships, and defences.",
    "It does not speed research. That still depends on your labs and Intergalactic Research Network.",
  ],
  terraformer: [
    "The terraformer adds extra building fields so the planet can hold more structures.",
    "It costs crystal, deuterium, and a large amount of energy — not ore. You need a nanite factory and Energy technology 12.",
  ],
  lunar_base: [
    "The lunar base adds moon fields. It can only be built on a moon.",
    "Moons are not in this session yet.",
  ],
  phalanx_sensor: [
    "The sensor phalanx can scan another planet for fleets heading to or from it. Each scan costs deuterium.",
    "It is moon-only, and moons are not in this session yet.",
  ],
  stargate: [
    "A jump gate can send a fleet instantly to another of your jump gates. After a jump it needs time to cool down.",
    "It is moon-only, and moons are not in this session yet.",
  ],
  space_station: [
    "The space dock can recover wreckage after a large battle over this planet.",
    "It is not available in this session.",
  ],
};
