import { describe, it, expect, afterEach, beforeEach, vi } from "vitest";
import { api } from "../api.js";

/**
 * CR-21: policy text and free-text notes travel in a JSON body, not the URL,
 * where a long Arabic policy can pass the request-line limit and the text lands
 * in proxy and access logs.
 */
describe("free text goes in the request body", () => {
  let fetchSpy;
  beforeEach(() => {
    fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(async () =>
      new Response(JSON.stringify({ data: {} }), { status: 200, headers: { "Content-Type": "application/json" } }));
  });
  afterEach(() => vi.restoreAllMocks());

  const call = () => {
    const [url, init] = fetchSpy.mock.calls.at(-1);
    return { url: String(url), method: init.method, body: init.body ? JSON.parse(init.body) : null };
  };

  it("publishes a 20 KB Arabic policy in the body", async () => {
    const arabic = "تلتزم منصة أيوه بحماية بياناتك وخصوصيتك. ".repeat(500);
    await api.publishTerms("2.0", "English text", "PRIVACY", arabic, "  Longer text ");
    const { url, method, body } = call();
    expect(method).toBe("POST");
    expect(url.endsWith("/terms")).toBe(true);
    expect(url.length).toBeLessThan(200);
    expect(body).toEqual({ version: "2.0", type: "PRIVACY", contentEn: "English text", contentAr: arabic, changeNote: "Longer text" });
  });

  it("leaves out an empty Arabic text and note", async () => {
    await api.publishTerms("2.1", "English text");
    expect(call().body).toEqual({ version: "2.1", type: "CUSTOMER_TERMS", contentEn: "English text" });
  });

  it.each([
    ["rejectProvider", () => api.rejectProvider(7, "Licence & ID unreadable"), "/admin/verification/7/reject", "reason"],
    ["requestProviderInfo", () => api.requestProviderInfo(7, "Please re-upload?"), "/admin/verification/7/request-info", "message"],
    ["resolveComplaint", () => api.resolveComplaint(8, "Called both sides"), "/admin/complaints/8/resolve", "notes"],
    ["resolveSafety", () => api.resolveSafety(9, "She is safe"), "/admin/safety/9/resolve", "notes"],
    ["warnUser", () => api.warnUser(10, "Abusive chat"), "/admin/users/10/warn", "reason"],
    ["forceCancelBooking", () => api.forceCancelBooking(11, "Studio closed"), "/admin/bookings/11/force-cancel", "reason"],
  ])("%s sends its text as a JSON body field", async (_name, run, path, field) => {
    await run();
    const { url, method, body } = call();
    expect(method).toBe("POST");
    expect(url.endsWith(path)).toBe(true);
    expect(Object.values(body)[0]).toBeTruthy();
    expect(Object.keys(body)).toEqual([field]);
  });

  it("moderationAction keeps the status in the URL and the notes in the body", async () => {
    await api.moderationAction(12, { status: "ACTIONED", notes: "Hidden: stock photo" });
    const { url, method, body } = call();
    expect(method).toBe("PATCH");
    expect(url.endsWith("/admin/moderation/12/action?status=ACTIONED")).toBe(true);
    expect(body).toEqual({ notes: "Hidden: stock photo" });
  });

  it("resolveDispute keeps the outcome in the URL and the reason in the body", async () => {
    await api.resolveDispute(13, "CANCEL", "Provider agreed");
    const { url, body } = call();
    expect(url.endsWith("/admin/bookings/13/resolve-dispute?outcome=CANCEL")).toBe(true);
    expect(body).toEqual({ reason: "Provider agreed" });
  });

  it("no free text lands in any URL", async () => {
    const secret = "secret-free-text-marker";
    await api.rejectProvider(1, secret);
    await api.requestProviderInfo(1, secret);
    await api.resolveComplaint(1, secret);
    await api.resolveSafety(1, secret);
    await api.warnUser(1, secret);
    await api.forceCancelBooking(1, secret);
    await api.resolveDispute(1, "PAID", secret);
    await api.moderationAction(1, { status: "DISMISSED", notes: secret });
    await api.publishTerms(secret, secret, "SAFETY", secret, secret);
    for (const [url] of fetchSpy.mock.calls) expect(String(url)).not.toContain(secret);
  });
});
