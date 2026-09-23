import { BottomNav } from "@/components/bottom-nav";
import { PlanetHeader } from "@/components/planet-header";
import { ResourceBar } from "@/components/resource-bar";
import { Starfield } from "@/components/starfield";

export function AppShell({
  children,
  title,
}: {
  children: React.ReactNode;
  title: string;
}) {
  return (
    <div className="relative mx-auto flex h-dvh w-full max-w-md flex-col overflow-hidden border-x border-cyan-900/30 bg-[#040814]">
      <Starfield />
      <div className="holo-grid pointer-events-none absolute inset-0 z-0" />
      <div className="scanlines pointer-events-none absolute inset-0 z-10" />
      <header className="relative z-20 shrink-0 border-b border-cyan-500/20 bg-slate-950/90 px-3 pt-2 pb-2.5 backdrop-blur-md">
        <PlanetHeader title={title} />
        <ResourceBar />
      </header>
      <div className="relative z-10 flex-1 overflow-y-auto px-3 py-3">{children}</div>
      <BottomNav />
    </div>
  );
}
