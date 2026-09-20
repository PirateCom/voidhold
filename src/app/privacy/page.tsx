export default function PrivacyPage() {
  return (
    <main className="mx-auto min-h-dvh max-w-[430px] bg-[var(--surface)] px-5 py-8">
      <h1 className="font-[family-name:var(--font-display)] text-2xl">Privacy</h1>
      <p className="mt-4 text-sm text-[var(--muted-fg)]">
        Voidhold stores your account email (via Supabase Auth) and game progress: planet, buildings, fleets,
        and battle reports. We do not sell data. Deleting your account removes your empire from the live
        universe.
      </p>
      <p className="mt-4 text-sm text-[var(--muted-fg)]">
        Magic-link emails are sent so you can sign in. Resource timers and combat are resolved on the
        server; your device clock is not trusted.
      </p>
    </main>
  );
}
