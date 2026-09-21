"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import {
  buildRaiders,
  cancelBuildingUpgrade,
  launchRaid,
  loadEmpireState,
  queueDefence as queueDefenceAction,
  researchPropulsion,
  resetEmpireProgress,
  spawnPirateWave,
  upgradeBuilding,
} from "@/lib/game/actions";
import { gameClock } from "@/lib/game/catalog";
import type { BuildingId, DefenceId, EmpireState } from "@/lib/game/types";
import { EMPTY_DEFENCES, livePlanet, type SimPlanet } from "@/lib/game/simulate";

type EmpireContextValue = {
  state: EmpireState | null;
  error: string | null;
  pending: boolean;
  configured: boolean;
  now: number;
  live: ReturnType<typeof livePlanet> | null;
  refresh: () => Promise<void>;
  upgrade: (building: BuildingId) => Promise<void>;
  cancelUpgrade: () => Promise<void>;
  resetProgress: () => Promise<void>;
  research: () => Promise<void>;
  build: (count: number) => Promise<void>;
  buildDefence: (id: DefenceId, count: number) => Promise<void>;
  spawnPirates: () => Promise<void>;
  raid: (system: number, slot: number, raiders: number) => Promise<void>;
};

const EmpireContext = createContext<EmpireContextValue | null>(null);

function nextDueAt(state: EmpireState): number | null {
  const due: number[] = [];
  if (state.planet.upgrade_completes_at) due.push(new Date(state.planet.upgrade_completes_at).getTime());
  if (state.empire.research_completes_at) due.push(new Date(state.empire.research_completes_at).getTime());
  if (state.empire.raider_completes_at) due.push(new Date(state.empire.raider_completes_at).getTime());
  if (state.planet.defence_completes_at) due.push(new Date(state.planet.defence_completes_at).getTime());
  if (state.empire.next_pirate_at) due.push(new Date(state.empire.next_pirate_at).getTime());
  for (const fleet of state.fleets) due.push(new Date(fleet.arrives_at).getTime());
  if (due.length === 0) return null;
  return Math.min(...due);
}

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
    smallShieldDome: planet.small_shield_dome ?? 0,
    largeShieldDome: planet.large_shield_dome ?? 0,
    rocketLauncher: planet.rocket_launcher ?? 0,
    lightLaser: planet.light_laser ?? 0,
    heavyLaser: planet.heavy_laser ?? 0,
    ionCannon: planet.ion_cannon ?? 0,
    gaussCannon: planet.gauss_cannon ?? 0,
    defenceBuilding: planet.defence_building ?? EMPTY_DEFENCES.defenceBuilding,
    defencesQueued: planet.defences_queued ?? 0,
    defenceCompletesAt: planet.defence_completes_at
      ? new Date(planet.defence_completes_at).getTime()
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
  const refreshInFlight = useRef(false);
  const refreshAgain = useRef(false);

  const commitState = useCallback((next: EmpireState | null) => {
    const wall = Date.now();
    setState(next);
    setFetchedAt(next ? wall : 0);
    setNow(wall);
  }, []);

  const refresh = useCallback(async () => {
    if (!configured) return;
    if (refreshInFlight.current) {
      refreshAgain.current = true;
      return;
    }
    refreshInFlight.current = true;
    try {
      let passes = 0;
      do {
        refreshAgain.current = false;
        const next = await loadEmpireState();
        commitState(next);
        setError(null);
        passes += 1;
      } while (refreshAgain.current && passes < 3);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not load the empire.");
    } finally {
      refreshInFlight.current = false;
    }
  }, [commitState, configured]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  useEffect(() => {
    const tick = window.setInterval(() => setNow(Date.now()), 250);
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
    return gameClock(state.server_now, fetchedAt, now);
  }, [state, fetchedAt, now]);

  const live = useMemo(() => {
    if (!state) return null;
    return livePlanet(toSimPlanet(state.planet), gameNow);
  }, [state, gameNow]);

  useEffect(() => {
    if (!state) return;
    const due = nextDueAt(state);
    if (due == null) return;
    const remaining = due - new Date(state.server_now).getTime();
    const id = window.setTimeout(() => void refresh(), Math.max(50, remaining + 100));
    return () => window.clearTimeout(id);
  }, [state, refresh]);

  async function run(mut: () => Promise<EmpireState>) {
    setPending(true);
    setError(null);
    try {
      commitState(await mut());
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
    cancelUpgrade: () => run(() => cancelBuildingUpgrade()),
    resetProgress: () => run(() => resetEmpireProgress()),
    research: () => run(() => researchPropulsion()),
    build: (count) => run(() => buildRaiders(count)),
    buildDefence: (id, count) => run(() => queueDefenceAction(id, count)),
    spawnPirates: () => run(() => spawnPirateWave()),
    raid: (system, slot, raiders) => run(() => launchRaid(system, slot, raiders)),
  };

  return <EmpireContext.Provider value={value}>{children}</EmpireContext.Provider>;
}

export function useEmpire() {
  const ctx = useContext(EmpireContext);
  if (!ctx) throw new Error("useEmpire must be used within EmpireProvider");
  return ctx;
}
