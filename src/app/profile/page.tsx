"use client";

import { FormEvent, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { useEmpire } from "@/components/empire-provider";
import { deleteOwnAccount, loadHighscores } from "@/lib/game/actions";
import type { HighscoreEntry } from "@/lib/game/types";
import { createClient } from "@/lib/supabase/client";

type ProfileTab = "commander" | "highscores";

function Fact({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between gap-4 border-b border-[var(--border)] py-3 last:border-b-0">
      <dt className="text-sm text-[var(--muted-fg)]">{label}</dt>
      <dd className="text-right text-sm font-semibold break-all">{value}</dd>
    </div>
  );
}

function TabButton({
  active,
  label,
  onClick,
}: {
  active: boolean;
  label: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`sci-btn h-10 flex-1 ${active ? "" : "sci-btn-muted"}`}
    >
      {label}
    </button>
  );
}

export default function ProfilePage() {
  const { state, error, configured, pending } = useEmpire();
  const router = useRouter();
  const [tab, setTab] = useState<ProfileTab>("commander");
  const [email, setEmail] = useState<string | null>(null);
  const [createdAt, setCreatedAt] = useState<string | null>(null);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [typed, setTyped] = useState("");
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<string | null>(null);
  const [highscores, setHighscores] = useState<HighscoreEntry[] | null>(null);
  const [highscoresError, setHighscoresError] = useState<string | null>(null);
  const [highscoresLoading, setHighscoresLoading] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    if (!supabase) return;
    void supabase.auth.getUser().then(({ data }) => {
      setEmail(data.user?.email ?? null);
      setCreatedAt(data.user?.created_at ?? null);
    });
  }, []);

  useEffect(() => {
    if (tab !== "highscores" || !configured) return;
    let cancelled = false;
    setHighscoresLoading(true);
    setHighscoresError(null);
    void loadHighscores()
      .then((rows) => {
        if (!cancelled) setHighscores(rows);
      })
      .catch((err) => {
        if (!cancelled) {
          setHighscores(null);
          setHighscoresError(err instanceof Error ? err.message : "Could not load highscores.");
        }
      })
      .finally(() => {
        if (!cancelled) setHighscoresLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [tab, configured]);

  async function signOut() {
    const supabase = createClient();
    if (supabase) await supabase.auth.signOut();
    router.push("/login");
    router.refresh();
  }

  async function onDelete(e: FormEvent) {
    e.preventDefault();
    const confirmation = typed.trim();
    if (confirmation.toLowerCase() !== "delete") return;
    setBusy(true);
    setStatus(null);
    try {
      await deleteOwnAccount(confirmation);
      router.push("/login");
      router.refresh();
    } catch (err) {
      setBusy(false);
      setStatus(err instanceof Error ? err.message : "Could not delete the account.");
    }
  }

  if (!configured) {
    return (
      <AppShell title="Commander">
        <p className="text-sm text-[var(--muted-fg)]">
          Supabase is not configured. Copy <code>.env.local.example</code> after creating the voidhold
          project.
        </p>
      </AppShell>
    );
  }

  const planet = state?.planet;
  const typedOk = typed.trim().toLowerCase() === "delete";
  const myId = state?.profile.user_id;

  return (
    <AppShell title="Commander">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      {status ? <p className="mb-3 text-sm text-red-300">{status}</p> : null}

      <div className="mb-4 grid grid-cols-2 gap-2">
        <TabButton active={tab === "commander"} label="Commander" onClick={() => setTab("commander")} />
        <TabButton active={tab === "highscores"} label="Highscores" onClick={() => setTab("highscores")} />
      </div>

      {tab === "commander" ? (
        state ? (
          <>
            <dl className="sci-card mb-4 px-4">
              <Fact label="Name" value={state.profile.display_name} />
              <Fact label="Email" value={email ?? "…"} />
              <Fact
                label="Joined"
                value={
                  createdAt
                    ? new Date(createdAt).toLocaleString(undefined, {
                        dateStyle: "medium",
                        timeStyle: "short",
                      })
                    : "…"
                }
              />
              <Fact label="Account id" value={state.profile.user_id} />
              {planet ? (
                <Fact label="Homeworld" value={`[${planet.galaxy}:${planet.system}:${planet.slot}] ${planet.name}`} />
              ) : null}
              <Fact
                label="Score"
                value={`${state.rank.points.toLocaleString()} pts · place ${state.rank.place.toLocaleString()} of ${state.rank.total.toLocaleString()}`}
              />
              <Fact label="Research" value={`${(state.rank.research ?? 0).toLocaleString()} tech levels`} />
              <Fact label="Fleet" value={`${(state.rank.fleet ?? 0).toLocaleString()} ships`} />
            </dl>
            <button
              type="button"
              onClick={() => void signOut()}
              className="sci-btn sci-btn-muted h-11 w-full"
            >
              Sign out
            </button>
            <button
              type="button"
              disabled={pending || busy}
              onClick={() => {
                setTyped("");
                setStatus(null);
                setConfirmOpen(true);
              }}
              className="sci-btn sci-btn-danger mt-2 h-11 w-full"
            >
              Delete account
            </button>
            <p className="mt-2 text-center text-xs text-[var(--muted-fg)]">
              Deletes your login and empire from the live universe. This cannot be undone.
            </p>
          </>
        ) : (
          <p className="text-sm text-[var(--muted-fg)]">Establishing a hold…</p>
        )
      ) : highscoresLoading ? (
        <p className="text-sm text-[var(--muted-fg)]">Loading universe standings…</p>
      ) : highscoresError ? (
        <p className="text-sm text-red-300">{highscoresError}</p>
      ) : highscores && highscores.length > 0 ? (
        <div className="sci-card overflow-hidden">
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="border-b border-cyan-500/20 text-xs tracking-wide text-[var(--muted-fg)] uppercase">
                <th className="px-3 py-2 font-medium">#</th>
                <th className="px-3 py-2 font-medium">Commander</th>
                <th className="px-3 py-2 text-right font-medium">Score</th>
              </tr>
            </thead>
            <tbody>
              {highscores.map((row, index) => {
                const place = index + 1;
                const mine = row.user_id === myId;
                return (
                  <tr
                    key={row.user_id}
                    className={`border-b border-cyan-500/10 last:border-b-0 ${mine ? "bg-cyan-950/40" : ""}`}
                  >
                    <td className="px-3 py-2.5 font-mono text-cyan-300">{place}</td>
                    <td className="px-3 py-2.5 font-semibold">{row.display_name}</td>
                    <td className="px-3 py-2.5 text-right font-mono tabular-nums">
                      {row.points.toLocaleString()}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      ) : (
        <p className="text-sm text-[var(--muted-fg)]">No commanders in the universe yet.</p>
      )}

      {confirmOpen ? (
        <div className="fixed inset-0 z-40 flex items-end justify-center bg-black/70 p-3">
          <form className="sci-card w-full max-w-md p-4" onSubmit={(e) => void onDelete(e)}>
            <h2 className="font-semibold text-rose-200">Delete this account?</h2>
            <p className="mt-2 text-sm text-[var(--muted-fg)]">
              Your commander, planet, fleets, reports, and Supabase login will be removed. Type{" "}
              <span className="font-mono text-rose-200">delete</span> to confirm.
            </p>
            <label className="mt-4 block text-xs uppercase tracking-wide text-[var(--muted-fg)]">
              Confirmation
              <input
                autoFocus
                value={typed}
                onChange={(ev) => setTyped(ev.target.value)}
                autoComplete="off"
                className="mt-1 h-12 w-full rounded-2xl border border-[var(--border)] bg-[var(--background)] px-4 text-sm outline-none ring-[var(--accent)] focus:ring-2"
                placeholder="delete"
              />
            </label>
            <div className="mt-4 grid grid-cols-2 gap-2">
              <button
                type="button"
                className="sci-btn sci-btn-muted h-11 w-full"
                disabled={busy}
                onClick={() => setConfirmOpen(false)}
              >
                Cancel
              </button>
              <button
                type="submit"
                className="sci-btn sci-btn-danger h-11 w-full"
                disabled={!typedOk || busy}
              >
                {busy ? "Deleting…" : "Delete forever"}
              </button>
            </div>
          </form>
        </div>
      ) : null}

      <Link href="/privacy" className="mt-6 block text-center text-xs text-[var(--muted-fg)] underline">
        Privacy
      </Link>
    </AppShell>
  );
}
