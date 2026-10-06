import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";

/**
 * R4-04: a private document or export body that finishes after the session changed must never produce an object URL or
 * a download. The generation is validated after the complete body was read and before the side effect.
 */

function deferredBlobResponse(extra = {}) {
  let finish;
  const blob = vi.fn(() => new Promise((resolve) => { finish = resolve; }));
  return { response: { status: 200, ok: true, blob, ...extra }, finish: (b) => finish(b), started: () => typeof finish === "function" };
}

describe("api.js - private response bodies and the session", () => {
  let mod;
  let created;

  beforeEach(async () => {
    vi.resetModules();
    window.localStorage.clear();
    created = vi.fn(() => "blob:private");
    vi.stubGlobal("URL", Object.assign(URL, { createObjectURL: created, revokeObjectURL: vi.fn() }));
    mod = await import("../api.js");
  });
  afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals(); });

  async function startedWith(body) {
    await vi.waitFor(() => expect(body.started()).toBe(true));
  }

  it("a document body that completes after an account change is rejected and no URL is created", async () => {
    mod.setTokens({ accessToken: "A" });
    const body = deferredBlobResponse();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(body.response);
    const pending = mod.api.verificationDocUrl("uploads/private/A.png").catch((error) => error);
    await startedWith(body);
    mod.clearTokens();
    mod.setTokens({ accessToken: "B" });
    body.finish(new Blob(["private document for A"]));
    const result = await pending;
    expect(result).toBeInstanceOf(Error);
    expect(result.code).toBe("SESSION_CHANGED");
    expect(created).not.toHaveBeenCalled();
  });

  it("a document body that completes after logout is rejected", async () => {
    mod.setTokens({ accessToken: "A" });
    const body = deferredBlobResponse();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(body.response);
    const pending = mod.api.verificationDocUrl("uploads/private/A.png").catch((error) => error);
    await startedWith(body);
    mod.clearTokens();
    body.finish(new Blob(["x"]));
    expect((await pending).code).toBe("SESSION_CHANGED");
    expect(created).not.toHaveBeenCalled();
  });

  it("a document body that completes after a sign-in in ANOTHER tab (storage event) is rejected", async () => {
    mod.setTokens({ accessToken: "A" });
    const body = deferredBlobResponse();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(body.response);
    const pending = mod.api.verificationDocUrl("uploads/private/A.png").catch((error) => error);
    await startedWith(body);
    window.dispatchEvent(new StorageEvent("storage", { key: "aiwa_admin_session", newValue: "other-tab" }));
    body.finish(new Blob(["x"]));
    expect((await pending).code).toBe("SESSION_CHANGED");
    expect(created).not.toHaveBeenCalled();
  });

  it("an export that completes after the session changed triggers no download", async () => {
    mod.setTokens({ accessToken: "A" });
    const body = deferredBlobResponse();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(body.response);
    const click = vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(() => {});
    const pending = mod.api.exportLedger().catch((error) => error);
    await startedWith(body);
    mod.clearTokens();
    mod.setTokens({ accessToken: "B" });
    body.finish(new Blob(["id,secret\n1,A-only"]));
    expect((await pending).code).toBe("SESSION_CHANGED");
    expect(click).not.toHaveBeenCalled();
    expect(created).not.toHaveBeenCalled();
  });

  it("the transfer is cancelled when the session changes", async () => {
    mod.setTokens({ accessToken: "A" });
    let signal;
    vi.spyOn(globalThis, "fetch").mockImplementation((url, options) => {
      signal = options.signal;
      return new Promise((resolve, reject) => {
        options.signal.addEventListener("abort", () => reject(Object.assign(new Error("aborted"), { name: "AbortError" })));
      });
    });
    const pending = mod.api.exportAudit().catch((error) => error);
    await vi.waitFor(() => expect(signal).toBeDefined());
    expect(signal.aborted).toBe(false);
    mod.clearTokens();
    expect(signal.aborted).toBe(true);
    const result = await pending;
    expect(result.code).toBe("SESSION_CHANGED");
  });

  it("a normal download in the same session still works", async () => {
    mod.setTokens({ accessToken: "A" });
    const body = deferredBlobResponse();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(body.response);
    const click = vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(() => {});
    const pending = mod.api.exportLedger();
    await startedWith(body);
    body.finish(new Blob(["id\n1"]));
    await expect(pending).resolves.toEqual({ ok: true });
    expect(click).toHaveBeenCalledTimes(1);

    const doc = deferredBlobResponse();
    vi.spyOn(globalThis, "fetch").mockResolvedValue(doc.response);
    const url = mod.api.verificationDocUrl("uploads/private/A.png");
    await startedWith(doc);
    doc.finish(new Blob(["ok"]));
    await expect(url).resolves.toBe("blob:private");
  });

  it("an HTTP error response is still reported as an error, not as a body", async () => {
    mod.setTokens({ accessToken: "A" });
    vi.spyOn(globalThis, "fetch").mockResolvedValue({ status: 404, ok: false, blob: vi.fn() });
    await expect(mod.api.verificationDocUrl("x")).rejects.toMatchObject({ status: 404 });
  });
});
