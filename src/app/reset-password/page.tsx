"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function ResetPasswordPage() {
  const router = useRouter();
  const [password, setPassword] = useState("");
  const [status, setStatus] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    const supabase = createClient();
    if (!supabase) return;
    setPending(true);
    setStatus(null);
    const { error } = await supabase.auth.updateUser({ password });
    setPending(false);
    if (error) {
      setStatus(error.message);
      return;
    }
    router.replace("/");
    router.refresh();
  }

  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-[430px] flex-col justify-center bg-[var(--surface)] px-6">
      <p className="text-[10px] uppercase tracking-[0.35em] text-[var(--accent)]">Voidhold</p>
      <h1 className="mt-2 font-[family-name:var(--font-display)] text-3xl">Choose a password</h1>
      <p className="mt-3 text-sm text-[var(--muted-fg)]">
        This password works on any browser or device. Use at least 6 characters.
      </p>
      <form onSubmit={(e) => void onSubmit(e)} className="mt-8 flex flex-col gap-3">
        <input
          type="password"
          required
          minLength={6}
          autoComplete="new-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="New password"
          className="h-12 rounded-2xl border border-[var(--border)] bg-[var(--background)] px-4 text-sm outline-none ring-[var(--accent)] focus:ring-2"
        />
        <button
          type="submit"
          disabled={pending}
          className="h-12 rounded-2xl bg-[var(--accent)] text-sm font-semibold text-[var(--accent-fg)] disabled:opacity-60"
        >
          {pending ? "Saving…" : "Save password"}
        </button>
        {status ? <p className="text-sm text-red-200">{status}</p> : null}
      </form>
    </div>
  );
}
