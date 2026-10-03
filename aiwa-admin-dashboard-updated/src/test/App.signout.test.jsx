import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { render, screen, fireEvent, act, waitFor } from "@testing-library/react";
import App from "../App.jsx";

/**
 * CR-18 (admin half): sign-out used to wait for the network before clearing
 * the tokens, so on a stalled connection the admin stayed signed in, and a tab
 * never noticed that another tab had signed out or in.
 */

const TOKEN = "aiwa_admin_access_token";
const REFRESH = "aiwa_admin_refresh_token";
const ME = { id: 7, fullName: "Nour Support", role: "ADMIN", permissions: ["SUPPORT"] };

function res(status, body) {
  return { ok: status >= 200 && status < 300, status, text: async () => JSON.stringify(body) };
}

// /auth/me answers, /auth/logout is whatever the test says, the rest fails.
function routeFetch(logout) {
  return vi.spyOn(globalThis, "fetch").mockImplementation(async (url, init) => {
    const path = String(url).replace("http://api.test/api", "");
    if (path === "/auth/me") return res(200, { data: ME });
    if (path === "/auth/logout") return logout(init);
    if (path.startsWith("/admin/inbox")) return res(200, { data: [] });
    return res(500, { message: "not under test" });
  });
}

beforeEach(() => {
  window.localStorage.setItem(TOKEN, "access");
  window.localStorage.setItem(REFRESH, "refresh");
});
afterEach(() => { vi.useRealTimers(); });

describe("<App> — CR-18 sign-out", () => {
  it("clears the tokens and shows the sign-in screen even when the logout request hangs", async () => {
    const fetchSpy = routeFetch(() => new Promise(() => {})); // never answers
    render(<App />);
    await screen.findByText(/Nour Support/);

    fireEvent.click(screen.getByRole("button", { name: /Logout/ }));

    expect(await screen.findByText("Sign in to dashboard")).toBeInTheDocument();
    expect(window.localStorage.getItem(TOKEN)).toBeNull();
    expect(window.localStorage.getItem(REFRESH)).toBeNull();
    // The server was still told, with the tokens read before they were cleared.
    const call = fetchSpy.mock.calls.find(([u]) => String(u).endsWith("/auth/logout"));
    expect(call[1].headers.Authorization).toBe("Bearer access");
    expect(JSON.parse(call[1].body)).toEqual({ refreshToken: "refresh" });
  });

  it("gives up on the server call after a few seconds", async () => {
    let signal;
    routeFetch((init) => new Promise((_, reject) => {
      signal = init.signal;
      init.signal.addEventListener("abort", () => reject(new DOMException("aborted", "AbortError")));
    }));
    render(<App />);
    await screen.findByText(/Nour Support/);
    vi.useFakeTimers();
    fireEvent.click(screen.getByRole("button", { name: /Logout/ }));
    await act(async () => {});
    expect(signal.aborted).toBe(false);
    await act(async () => { await vi.advanceTimersByTimeAsync(5_000); });
    expect(signal.aborted).toBe(true);
  });
});

describe("<App> — CR-18 other tabs", () => {
  it("signs this tab out when another tab signs out", async () => {
    routeFetch(() => res(200, {}));
    render(<App />);
    await screen.findByText(/Nour Support/);

    window.localStorage.removeItem(TOKEN);
    window.localStorage.removeItem(REFRESH);
    act(() => { window.dispatchEvent(new StorageEvent("storage", { key: TOKEN, oldValue: "access", newValue: null })); });

    expect(await screen.findByText("Sign in to dashboard")).toBeInTheDocument();
  });

  it("reloads the profile when another tab signs in with new tokens", async () => {
    const fetchSpy = routeFetch(() => res(200, {}));
    render(<App />);
    await screen.findByText(/Nour Support/);
    const meCalls = () => fetchSpy.mock.calls.filter(([u]) => String(u).endsWith("/auth/me")).length;
    expect(meCalls()).toBe(1);

    window.localStorage.setItem(TOKEN, "other-tab-access");
    act(() => { window.dispatchEvent(new StorageEvent("storage", { key: TOKEN, oldValue: "access", newValue: "other-tab-access" })); });

    await waitFor(() => expect(meCalls()).toBe(2));
    expect(screen.queryByText("Sign in to dashboard")).not.toBeInTheDocument();
  });

  it("drops a refresh that was in flight when another tab changed the tokens", async () => {
    vi.resetModules();
    const { api } = await import("../api.js");
    let finishRefresh;
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(async () => res(401, { message: "expired" }))
      .mockImplementationOnce(() => new Promise((resolve) => { finishRefresh = resolve; }));

    const pending = api.dashboardRaw().catch(() => null);
    await waitFor(() => expect(finishRefresh).toBeTypeOf("function"));

    // Another tab signs out while this tab's refresh is in flight.
    window.localStorage.removeItem(TOKEN);
    window.localStorage.removeItem(REFRESH);
    window.dispatchEvent(new StorageEvent("storage", { key: TOKEN, oldValue: "access", newValue: null }));
    finishRefresh(res(200, { data: { accessToken: "late-access", refreshToken: "late-refresh" } }));
    await pending;

    expect(window.localStorage.getItem(TOKEN)).toBeNull();
    expect(window.localStorage.getItem(REFRESH)).toBeNull();
  });
});
