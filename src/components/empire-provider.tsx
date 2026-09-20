"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import {
  buildRaiders,
  launchRaid,
  loadEmpireState,
  researchPropulsion,
  upgradeBuilding,
} from "@/lib/game/actions";
import type { BuildingId, EmpireState } from "@/lib/game/types";
import { livePlanet, type SimPlanet } from "@/lib/game/simulate";

type EmpireContextValue = {
  state: EmpireState | null;
  error: string | null;
  pending: boolean;
  configured: boolean;
  now: number;
  live: ReturnType<typeof livePlanet> | null;
  refresh: () => Promise<void>;
  upgrade: (building: BuildingId) => Promise<void>;
  research: () => Promise<void>;
  build: (count: number) => Promise<void>;
  raid: (system: number, slot: number, raiders: number) => Promise<void>;
};

const EmpireContext = createContext<EmpireContextValue | null>(null);

function toSimPlanet(planet: EmpireState["planet"]): SimPlanet {
  return {
    id: planet.id,
    ownerId: planet.owner_id,
    system: planet.system,
    slot: planet.slot,
    name: planet.name,
    ore: Number(planet.ore),
    crystal: Number(planet.crystal),
    lastHarvestedAt: new Date(planet.last_harvested_at).getTime(),
    oreMine: planet.ore_mine,
    crystalMine: planet.crystal_mine,
    powerPlant: planet.power_plant,
    upgradeBuilding: planet.upgrade_building,
    upgradeCompletesAt: planet.upgrade_completes_at
      ? new Date(planet.upgrade_completes_at).getTime()
      : null,
  };
}

export function EmpireProvider({
  configured,
  children,
}: {
  configured: boolean;
  children: ReactNode;
}) {
  const [state, setState] = useState<EmpireState | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  const [fetchedAt, setFetchedAt] = useState(0);
  const [now, setNow] = useState(() => Date.now());

  const refresh = useCallback(async () => {
    if (!configured) return;
    try {
      const next = await loadEmpireState();
      setState(next);
      setFetchedAt(next ? Date.now() : 0);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not load the empire.");
    }
  }, [configured]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  useEffect(() => {
    const tick = window.setInterval(() => setNow(Date.now()), 1000);
    const poll = window.setInterval(() => void refresh(), 8000);
    const onVis = () => {
      if (document.visibilityState === "visible") void refresh();
    };
    document.addEventListener("visibilitychange", onVis);
    return () => {
      window.clearInterval(tick);
      window.clearInterval(poll);
      document.removeEventListener("visibilitychange", onVis);
    };
  }, [refresh]);

  const gameNow = useMemo(() => {
    if (!state || !fetchedAt) return now;
    return new Date(state.server_now).getTime() + (now - fetchedAt);
  }, [state, fetchedAt, now]);

  const live = useMemo(() => {
    if (!state) return null;
    return livePlanet(toSimPlanet(state.planet), gameNow);
  }, [state, gameNow]);

  useEffect(() => {
    if (!state) return;
    const due: number[] = [];
    if (state.planet.upgrade_completes_at) due.push(new Date(state.planet.upgrade_completes_at).getTime());
    if (state.empire.research_completes_at) due.push(new Date(state.empire.research_completes_at).getTime());
    if (state.empire.raider_completes_at) due.push(new Date(state.empire.raider_completes_at).getTime());
    for (const fleet of state.fleets) due.push(new Date(fleet.arrives_at).getTime());
    if (due.some((t) => t <= gameNow && t > gameNow - 2000)) {
      void refresh();
    }
  }, [state, gameNow, refresh]);

  async function run(mut: () => Promise<EmpireState>) {
    setPending(true);
    setError(null);
    try {
      const next = await mut();
      setState(next);
      setFetchedAt(Date.now());
    } catch (err) {
      setError(err instanceof Error ? err.message : "Action failed.");
    } finally {
      setPending(false);
    }
  }

  const value: EmpireContextValue = {
    state,
    error,
    pending,
    configured,
    now: gameNow,
    live,
    refresh,
    upgrade: (building) => run(() => upgradeBuilding(building)),
    research: () => run(() => researchPropulsion()),
    build: (count) => run(() => buildRaiders(count)),
    raid: (system, slot, raiders) => run(() => launchRaid(system, slot, raiders)),
  };

  return <EmpireContext.Provider value={value}>{children}</EmpireContext.Provider>;
}

export function useEmpire() {
  const ctx = useContext(EmpireContext);
  if (!ctx) throw new Error("useEmpire must be used within EmpireProvider");
  return ctx;
}
