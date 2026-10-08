import { describe, expect, it } from "vitest";
import { commsHasUnread, latestNoticeAt, latestReportAt } from "@/components/comms-seen";

describe("comms unread", () => {
  it("treats newer fleet reports and notices as unread", () => {
    const reports = [{ created_at: "2026-10-08T10:00:00.000Z" }];
    const notices = [
      { channel: "news", created_at: "2026-10-08T12:00:00.000Z" },
      { channel: "admin", created_at: "2026-10-08T09:00:00.000Z" },
    ];
    expect(latestReportAt(reports)).toBe(Date.parse("2026-10-08T10:00:00.000Z"));
    expect(latestNoticeAt(notices, "news")).toBe(Date.parse("2026-10-08T12:00:00.000Z"));
    expect(
      commsHasUnread(reports, notices, {
        fleets: Date.parse("2026-10-08T10:00:00.000Z"),
        news: Date.parse("2026-10-08T11:00:00.000Z"),
        admin: Date.parse("2026-10-08T09:00:00.000Z"),
      }),
    ).toBe(true);
    expect(
      commsHasUnread(reports, notices, {
        fleets: Date.parse("2026-10-08T10:00:00.000Z"),
        news: Date.parse("2026-10-08T12:00:00.000Z"),
        admin: Date.parse("2026-10-08T09:00:00.000Z"),
      }),
    ).toBe(false);
  });
});
