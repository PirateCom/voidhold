"use client";

import { useEffect, useMemo, useState } from "react";
import { AppShell } from "@/components/app-shell";
import {
  latestNoticeAt,
  latestReportAt,
  markCommsTabSeen,
  useCommsSeen,
  type CommsTab,
} from "@/components/comms-seen";
import { useEmpire } from "@/components/empire-provider";
import { REPORT_TTL_DAYS } from "@/lib/game/catalog";
import type { CommsNoticeChannel, CommsNoticeRow, ReportRow } from "@/lib/game/types";

const TABS: { id: CommsTab; label: string }[] = [
  { id: "fleets", label: "Fleets" },
  { id: "news", label: "News" },
  { id: "admin", label: "Admin" },
];

export default function CommunicationsPage() {
  const { state, error, pending, deleteReport, postNotice, deleteNotice, isDebug } = useEmpire();
  const seen = useCommsSeen();
  const [tab, setTab] = useState<CommsTab>("fleets");
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const notices = state?.notices ?? [];
  const reports = state?.reports ?? [];
  const channel: CommsNoticeChannel | null = tab === "fleets" ? null : tab;
  const latest = tab === "fleets" ? latestReportAt(reports) : latestNoticeAt(notices, tab);

  useEffect(() => {
    if (latest > 0) markCommsTabSeen(tab, latest);
  }, [latest, tab]);

  const list = useMemo(() => {
    if (tab === "fleets") return reports;
    return notices.filter((n) => n.channel === tab);
  }, [tab, reports, notices]);

  const unread = {
    fleets: latestReportAt(reports) > seen.fleets,
    news: latestNoticeAt(notices, "news") > seen.news,
    admin: latestNoticeAt(notices, "admin") > seen.admin,
  };

  return (
    <AppShell title="Comms">
      {error ? <p className="mb-3 text-sm text-red-300">{error}</p> : null}
      {!state ? (
        <p className="text-sm text-[var(--muted-fg)]">No empire loaded.</p>
      ) : (
        <>
          <div className="grid grid-cols-3 gap-1">
            {TABS.map((item) => {
              const active = tab === item.id;
              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => setTab(item.id)}
                  className={`relative rounded px-1 py-2 font-[family-name:var(--font-display)] text-[10px] font-bold tracking-wide uppercase ${
                    active
                      ? "border border-cyan-500/40 bg-cyan-950/40 text-cyan-300"
                      : "border border-transparent bg-slate-900/60 text-slate-400"
                  }`}
                >
                  {unread[item.id] && !active ? (
                    <span className="absolute top-1 right-2 h-1.5 w-1.5 rounded-full bg-emerald-400" />
                  ) : null}
                  {item.label}
                </button>
              );
            })}
          </div>

          {tab === "fleets" ? (
            <p className="mt-3 text-xs text-[var(--muted-fg)]">
              Combat, spy, harvest, and other fleet mail. Reports stay for {REPORT_TTL_DAYS} days.
            </p>
          ) : tab === "news" ? (
            <p className="mt-3 text-xs text-[var(--muted-fg)]">
              Universe-wide notices. Every commander sees the same board.
            </p>
          ) : (
            <p className="mt-3 text-xs text-[var(--muted-fg)]">
              Operator messages for every commander.
            </p>
          )}

          {isDebug && channel ? (
            <form
              className="sci-card mt-3 flex flex-col gap-2 p-3"
              onSubmit={(event) => {
                event.preventDefault();
                const nextTitle = title.trim();
                const nextBody = body.trim();
                if (!nextTitle || !nextBody) return;
                void postNotice(channel, nextTitle, nextBody).then((ok) => {
                  if (ok) {
                    setTitle("");
                    setBody("");
                  }
                });
              }}
            >
              <p className="font-[family-name:var(--font-display)] text-[10px] font-bold tracking-wide text-cyan-300 uppercase">
                Post {tab}
              </p>
              <input
                className="sci-input h-9 rounded px-2 text-sm"
                maxLength={80}
                placeholder="Title"
                value={title}
                onChange={(event) => setTitle(event.target.value)}
              />
              <textarea
                className="sci-input min-h-[5.5rem] rounded px-2 py-2 text-sm"
                maxLength={4000}
                placeholder="Message for every commander"
                value={body}
                onChange={(event) => setBody(event.target.value)}
              />
              <button type="submit" className="sci-btn h-9 px-3" disabled={pending || !title.trim() || !body.trim()}>
                Send to all
              </button>
            </form>
          ) : null}

          {list.length === 0 ? (
            <p className="mt-3 text-sm text-[var(--muted-fg)]">
              {tab === "fleets" ? "No fleet reports yet." : tab === "news" ? "No news yet." : "No admin messages yet."}
            </p>
          ) : tab === "fleets" ? (
            <ul className="mt-3 flex flex-col gap-2">
              {(list as ReportRow[]).map((report) => (
                <li key={report.id} className="sci-card p-4">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="font-semibold">{report.title}</p>
                      <p className="mt-0.5 font-mono text-xs text-[var(--muted-fg)]">
                        {new Date(report.created_at).toLocaleString()}
                      </p>
                    </div>
                    <button
                      type="button"
                      className="sci-btn sci-btn-muted h-9 shrink-0 px-3"
                      disabled={pending}
                      onClick={() => void deleteReport(report.id)}
                    >
                      Delete
                    </button>
                  </div>
                  <p className="mt-2 whitespace-pre-wrap text-sm text-[var(--muted-fg)]">{report.body}</p>
                </li>
              ))}
            </ul>
          ) : (
            <ul className="mt-3 flex flex-col gap-2">
              {(list as CommsNoticeRow[]).map((notice) => (
                <li key={notice.id} className="sci-card p-4">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="font-semibold">{notice.title}</p>
                      <p className="mt-0.5 font-mono text-xs text-[var(--muted-fg)]">
                        {new Date(notice.created_at).toLocaleString()}
                      </p>
                    </div>
                    {isDebug ? (
                      <button
                        type="button"
                        className="sci-btn sci-btn-muted h-9 shrink-0 px-3"
                        disabled={pending}
                        onClick={() => void deleteNotice(notice.id)}
                      >
                        Delete
                      </button>
                    ) : null}
                  </div>
                  <p className="mt-2 whitespace-pre-wrap text-sm text-[var(--muted-fg)]">{notice.body}</p>
                </li>
              ))}
            </ul>
          )}
        </>
      )}
    </AppShell>
  );
}
