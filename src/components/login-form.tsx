"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { isSupabaseConfigured } from "@/lib/supabase/config";

const fieldClass =
  "h-12 rounded-2xl border border-[var(--border)] bg-[var(--background)] px-4 text-sm outline-none ring-[var(--accent)] focus:ring-2";

function safeNext(path: string | null | undefined) {
  return path && path.startsWith("/") && !path.startsWith("//") ? path : "/";
}

export function LoginForm({ next }: { next?: string }) {
  const configured = isSupabaseConfigured();
  const router = useRouter();
  const [mode, setMode] = useState<"signin" | "signup" | "reset">("signin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [status, setStatus] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    const supabase = createClient();
    if (!supabase) return;
    setPending(true);
    setStatus(null);
    const origin = process.env.NEXT_PUBLIC_SITE_URL || window.location.origin;
    const destination = safeNext(next);

    if (mode === "reset") {
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${origin}/auth/callback?next=/reset-password`,
      });
      setPending(false);
      setStatus(
        error
          ? error.message
          : "If that email has an account, a reset link is on the way. Open it on this device.",
      );
      return;
    }

    if (mode === "signup") {
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          emailRedirectTo: `${origin}/auth/callback?next=${encodeURIComponent(destination)}`,
        },
      });
      setPending(false);
      if (error) {
        setStatus(error.message);
        return;
      }
      if (!data.session) {
        setStatus("Check your email to confirm the account, then sign in with your password.");
        return;
      }
      router.replace(destination);
      router.refresh();
      return;
    }

    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setPending(false);
    if (error) {
      setStatus(error.message);
      return;
    }
    router.replace(destination);
    router.refresh();
  }

  if (!configured) {
    return (
      <p className="text-sm text-[var(--muted-fg)]">
        Create a dedicated Supabase project named <strong>voidhold</strong>, run the migration, then copy{" "}
        <code>.env.local.example</code> to <code>.env.local</code>.
      </p>
    );
  }

  return (
    <form onSubmit={(e) => void onSubmit(e)} className="flex flex-col gap-3">
      <input
        type="email"
        required
        autoComplete="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="you@email.com"
        className={fieldClass}
      />
      {mode !== "reset" ? (
        <input
          type="password"
          required
          minLength={6}
          autoComplete={mode === "signup" ? "new-password" : "current-password"}
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="Password"
          className={fieldClass}
        />
      ) : null}
      <button
        type="submit"
        disabled={pending}
        className="h-12 rounded-2xl bg-[var(--accent)] text-sm font-semibold text-[var(--accent-fg)] disabled:opacity-60"
      >
        {pending
          ? "Working…"
          : mode === "signup"
            ? "Create account"
            : mode === "reset"
              ? "Send reset email"
              : "Sign in"}
      </button>
      {status ? <p className="text-sm text-[var(--muted-fg)]">{status}</p> : null}
      <div className="flex flex-col gap-2 pt-1 text-xs text-[var(--muted-fg)]">
        {mode !== "signin" ? (
          <button type="button" className="text-left underline" onClick={() => setMode("signin")}>
            Sign in with password
          </button>
        ) : null}
        {mode !== "signup" ? (
          <button type="button" className="text-left underline" onClick={() => setMode("signup")}>
            Create an account
          </button>
        ) : null}
        {mode !== "reset" ? (
          <button type="button" className="text-left underline" onClick={() => setMode("reset")}>
            Forgot password
          </button>
        ) : null}
      </div>
    </form>
  );
}
