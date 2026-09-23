import { LoginForm } from "@/components/login-form";
import Link from "next/link";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; next?: string }>;
}) {
  const params = await searchParams;
  const error = params.error ? params.error.replace(/\+/g, " ") : null;

  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-[430px] flex-col justify-center bg-[var(--surface)] px-6">
      <p className="text-[10px] uppercase tracking-[0.35em] text-[var(--accent)]">Voidhold</p>
      <h1 className="mt-2 font-[family-name:var(--font-display)] text-3xl">Hold a world in the dark.</h1>
      <p className="mt-3 text-sm text-[var(--muted-fg)]">
        Mine ore and crystal, power the grid, build small cargo, and strip derelicts across nine galaxies.
      </p>
      {error ? (
        <p className="mt-6 rounded-2xl border border-red-500/40 bg-red-950/40 px-4 py-3 text-sm text-red-200">
          {error}
        </p>
      ) : null}
      <div className="mt-8">
        <LoginForm next={params.next} />
      </div>
      <p className="mt-6 text-xs text-[var(--muted-fg)]">
        Sign in with email and password from any browser. If you first used a magic link, tap Forgot password
        once to set one.
      </p>
      <Link href="/privacy" className="mt-8 text-center text-xs text-[var(--muted-fg)] underline">
        Privacy
      </Link>
    </div>
  );
}
