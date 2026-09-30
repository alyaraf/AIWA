import { describe, it, expect, afterEach, vi } from "vitest";
import { api } from "../api.js";

/**
 * OPS-9: a proxy error page (HTML 502) used to surface as the JSON parser's
 * "Unexpected token <" with no status, so the panel couldn't tell an outage
 * from a bug. The status must survive.
 */
describe("request() with a non-JSON body", () => {
  afterEach(() => vi.restoreAllMocks());

  it("an HTML 502 keeps its status and a readable message", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response("<html><body>Bad Gateway</body></html>", { status: 502, headers: { "Content-Type": "text/html" } })
    );
    const err = await api.me().catch((e) => e);
    expect(err.status).toBe(502);
    expect(err.message).toBe("Request failed with status 502");
  });

  it("a 200 with an unreadable body fails clearly instead of returning garbage", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response("<html>login portal</html>", { status: 200 }));
    await expect(api.me()).rejects.toThrow("unreadable response");
  });
});
