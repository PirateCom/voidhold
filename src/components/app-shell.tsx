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
    <div className="fixed inset-0 z-0 mx-auto flex w-full max-w-md min-h-0 flex-col overflow-hidden overscroll-none border-x border-cyan-900/30 bg-[#040814]">
      <Starfield />
      <div className="holo-grid pointer-events-none absolute inset-0 z-0" />
      <div className="scanlines pointer-events-none absolute inset-0 z-10" />
      <header className="relative z-20 shrink-0 border-b border-cyan-500/20 bg-slate-950/90 px-3 pt-[max(0.5rem,env(safe-area-inset-top))] pb-2.5 backdrop-blur-md">
        <PlanetHeader title={title} />
        <ResourceBar />
      </header>
      <div className="relative z-10 flex min-h-0 flex-1 flex-col">
        <div className="min-h-0 flex-1 overflow-y-auto overscroll-y-contain px-3 py-3">{children}</div>
        <div id="sheet-root" className="pointer-events-none absolute inset-0 z-40 [&>*]:pointer-events-auto" />
      </div>
      <BottomNav />
    </div>
  );
}
