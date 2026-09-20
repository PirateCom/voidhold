"use client";

import { FormEvent, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { isSupabaseConfigured } from "@/lib/supabase/config";

export function LoginForm() {
  const configured = isSupabaseConfigured();
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  const [sent, setSent] = useState(false);

  async function onSignIn(e: FormEvent) {
    e.preventDefault();
    const supabase = createClient();
    if (!supabase) return;
    setPending(true);
    setStatus(null);
    const origin = process.env.NEXT_PUBLIC_SITE_URL || window.location.origin;
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: {
        emailRedirectTo: `${origin}/auth/callback?next=/`,
      },
    });
    setPending(false);
    if (error) {
      setStatus(error.message);
      return;
    }
    setSent(true);
    setStatus(
      "Check your inbox. Open the newest email in this same Chrome window. Ignore older Confirm / magic-link messages.",
    );
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
    <form onSubmit={(e) => void onSignIn(e)} className="flex flex-col gap-3">
      <input
        type="email"
        required
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="you@email.com"
        className="h-12 rounded-2xl border border-[var(--border)] bg-[var(--background)] px-4 text-sm outline-none ring-[var(--accent)] focus:ring-2"
      />
      <button
        type="submit"
        disabled={pending || sent}
        className="h-12 rounded-2xl bg-[var(--accent)] text-sm font-semibold text-[var(--accent-fg)] disabled:opacity-60"
      >
        {pending ? "Sending…" : sent ? "Link sent" : "Send magic link"}
      </button>
      {status ? <p className="text-sm text-[var(--muted-fg)]">{status}</p> : null}
    </form>
  );
}
