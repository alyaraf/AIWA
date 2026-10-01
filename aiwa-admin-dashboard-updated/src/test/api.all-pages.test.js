import { describe, it, expect, afterEach, vi } from "vitest";
import { api } from "../api.js";

/**
 * OPS-8: moderation queues asked for one page of 500 and silently dropped the
 * rest. They now walk every page until the server says it was the last.
 */
function pagedServer(total, seen) {
  return vi.spyOn(globalThis, "fetch").mockImplementation(async (url) => {
    const u = new URL(url);
    seen.push(u.pathname + u.search);
    const page = Number(u.searchParams.get("page"));
    const size = Number(u.searchParams.get("size"));
    const content = Array.from({ length: Math.max(0, Math.min(size, total - page * size)) },
      (_, i) => ({ id: page * size + i + 1, status: "OPEN", subject: "x" }));
    return new Response(JSON.stringify({ success: true, data: { content, totalPages: Math.ceil(total / size), number: page } }),
      { status: 200, headers: { "Content-Type": "application/json" } });
  });
}

describe("paged admin lists", () => {
  afterEach(() => vi.restoreAllMocks());

  it("collects every complaint past the old 500-row cutoff", async () => {
    const seen = [];
    pagedServer(450, seen);
    const all = await api.complaints();
    expect(all).toHaveLength(450);
    expect(new Set(all.map((c) => c.id)).size).toBe(450);
    expect(seen).toEqual([
      "/api/admin/complaints?page=0&size=200",
      "/api/admin/complaints?page=1&size=200",
      "/api/admin/complaints?page=2&size=200"
    ]);
  });

  it("stops after one request when everything fits on the first page", async () => {
    const seen = [];
    pagedServer(3, seen);
    expect(await api.reviews()).toHaveLength(3);
    expect(seen).toHaveLength(1);
  });

  it("the SOS queue walks every page instead of stopping at 100 (DR-006)", async () => {
    const page = (n, total) => ({
      ok: true, status: 200,
      text: async () => JSON.stringify({ data: {
        content: Array.from({ length: n }, (_, i) => ({ id: total + i, bookingId: 1, actorName: "x", createdAt: null })),
        totalPages: 2, totalElements: 101 } })
    });
    const spy = vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(async () => page(100, 0))
      .mockImplementationOnce(async () => page(1, 100));
    const { api } = await import("../api.js");
    const rows = await api.safetyQueue("OPEN");
    expect(rows).toHaveLength(101);
    expect(spy.mock.calls[1][0]).toContain("page=1");
  });
});
