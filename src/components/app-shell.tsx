import { BottomNav } from "@/components/bottom-nav";
import { ResourceBar } from "@/components/resource-bar";

export function AppShell({
  children,
  title,
}: {
  children: React.ReactNode;
  title: string;
}) {
  return (
    <div className="mx-auto min-h-dvh w-full max-w-[430px] bg-[var(--surface)] shadow-[0_0_80px_rgba(0,0,0,0.45)]">
      <header className="sticky top-0 z-10 border-b border-[var(--border)] bg-[var(--surface)]/95 px-5 py-3 backdrop-blur">
        <div className="flex items-center justify-between gap-3">
          <h1 className="truncate font-[family-name:var(--font-display)] text-lg tracking-wide">{title}</h1>
          <span className="text-[10px] uppercase tracking-[0.2em] text-[var(--muted-fg)]">Voidhold</span>
        </div>
        <ResourceBar />
      </header>
      <div className="px-5 pt-4 pb-28">{children}</div>
      <BottomNav />
    </div>
  );
}
