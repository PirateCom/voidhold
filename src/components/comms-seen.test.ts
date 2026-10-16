import { describe, expect, it } from "vitest";
import { commsHasUnread, latestNoticeAt, latestReportAt } from "@/components/comms-seen";
import { ADMIN_MESSAGE_PRESETS } from "@/lib/game/admin-presets";

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

  it("keeps admin message presets within comms notice constraints", () => {
    expect(ADMIN_MESSAGE_PRESETS.length).toBeGreaterThan(0);
    const ids = new Set<string>();
    for (const preset of ADMIN_MESSAGE_PRESETS) {
      expect(ids.has(preset.id)).toBe(false);
      ids.add(preset.id);
      expect(preset.label.trim().length).toBeGreaterThan(0);
      expect(preset.title.trim().length).toBeGreaterThanOrEqual(1);
      expect(preset.title.trim().length).toBeLessThanOrEqual(80);
      expect(preset.body.trim().length).toBeGreaterThanOrEqual(1);
      expect(preset.body.trim().length).toBeLessThanOrEqual(4000);
    }
  });
});
