"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { readKeepLoggedInBrowser, writeKeepLoggedInBrowser } from "@/lib/session";
import { createClient } from "@/lib/supabase/client";
import { isSupabaseConfigured } from "@/lib/supabase/config";

const fieldClass =
  "sci-input h-12 px-4 text-sm outline-none ring-[var(--accent)] focus:ring-2";

function safeNext(path: string | null | undefined) {
  return path && path.startsWith("/") && !path.startsWith("//") ? path : "/";
}

function signupErrorMessage(message: string): string {
  if (/REGISTRATION_CAP|commander slots/i.test(message)) {
    return "All 20 commander slots are taken. Registration is closed.";
  }
  return message;
}

export function LoginForm({ next }: { next?: string }) {
  const configured = isSupabaseConfigured();
  const router = useRouter();
  const [mode, setMode] = useState<"signin" | "signup" | "reset">("signin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [keepLoggedIn, setKeepLoggedIn] = useState(true);
  const [status, setStatus] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  const [signupOpen, setSignupOpen] = useState(true);

  useEffect(() => {
    setKeepLoggedIn(readKeepLoggedInBrowser());
  }, []);

  useEffect(() => {
    const supabase = createClient();
    if (!supabase || !configured) return;
    void supabase.rpc("registration_open").then(({ data, error }) => {
      if (error || data !== false) return;
      setSignupOpen(false);
      setMode((m) => (m === "signup" ? "signin" : m));
    });
  }, [configured]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    writeKeepLoggedInBrowser(keepLoggedIn);
    const supabase = createClient(keepLoggedIn);
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
        setStatus(signupErrorMessage(error.message));
        if (/REGISTRATION_CAP|commander slots/i.test(error.message)) setSignupOpen(false);
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
        <>
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
          <button
            type="button"
            role="switch"
            aria-checked={keepLoggedIn}
            onClick={() => {
              const nextValue = !keepLoggedIn;
              setKeepLoggedIn(nextValue);
              writeKeepLoggedInBrowser(nextValue);
            }}
            className="flex items-center justify-between border border-[var(--border)] bg-slate-950/60 px-3.5 py-2.5 text-left text-xs text-[var(--foreground)]"
          >
            <span>Keep me logged in</span>
            <span
              className={`relative inline-flex h-5 w-9 shrink-0 items-center rounded-full border transition-colors ${
                keepLoggedIn
                  ? "border-cyan-400/70 bg-cyan-500/30"
                  : "border-slate-700 bg-slate-900"
              }`}
            >
              <span
                className={`inline-block h-3.5 w-3.5 rounded-full transition-transform ${
                  keepLoggedIn
                    ? "translate-x-4 bg-[var(--accent)] shadow-[0_0_8px_var(--accent)]"
                    : "translate-x-0.5 bg-slate-500"
                }`}
              />
            </span>
          </button>
        </>
      ) : null}
      <button
        type="submit"
        disabled={pending}
        className="sci-btn h-14 min-h-14 w-full"
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
          <button
            type="button"
            className="sci-btn sci-btn-muted h-11 w-full"
            onClick={() => setMode("signin")}
          >
            Sign in with password
          </button>
        ) : null}
        {mode !== "signup" && signupOpen ? (
          <button
            type="button"
            className="sci-btn sci-btn-muted h-11 w-full"
            onClick={() => setMode("signup")}
          >
            Create an account
          </button>
        ) : null}
        {!signupOpen ? (
          <p className="text-amber-200/90">All 20 commander slots are taken. New registration is closed.</p>
        ) : null}
        {mode !== "reset" ? (
          <button
            type="button"
            className="sci-btn sci-btn-quiet h-11 w-full"
            onClick={() => setMode("reset")}
          >
            Forgot password
          </button>
        ) : null}
      </div>
    </form>
  );
}
