import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, fireEvent, act, waitFor } from "@testing-library/react";
import App from "../App.jsx";
import * as mod from "../api.js";
import { pg } from "./safetyPage.js";

vi.setConfig({ testTimeout: 20_000 });

/**
 * R4-03: another tab signing in as a different account must drop everything the previous account loaded, before
 * the new identity is even known, and must never leave restricted rows mounted for an account without the capability.
 */

const SOS = () => mod.normalizeSafety({ id: 99, bookingId: 5, actorName: "Private A actor", notes: "PRIVATE_A_SOS", createdAt: new Date().toISOString() });

function other(tabHint) {
  window.localStorage.setItem("aiwa_admin_session", tabHint);
  window.dispatchEvent(new StorageEvent("storage", { key: "aiwa_admin_session", newValue: tabHint }));
}

describe("<App> - R4-03 cross-tab account change", () => {
  let who;
  beforeEach(() => {
    mod.setTokens({ accessToken: "A" });
    who = { id: 1, fullName: "Support A", role: "ADMIN", permissions: ["SUPER_ADMIN"] };
    vi.spyOn(mod.api, "me").mockImplementation(async () => who);
    vi.spyOn(mod.api, "dashboard").mockResolvedValue({ stats: [], activity: [] });
    vi.spyOn(mod.api, "safetyPage").mockResolvedValue(pg([SOS()]));
    vi.spyOn(globalThis, "fetch").mockResolvedValue({ status: 200, ok: true, text: async () => JSON.stringify({ data: { content: [], totalPages: 1 } }) });
  });

  async function openSafetyAsA() {
    render(<App />);
    fireEvent.click(await screen.findByRole("button", { name: /Safety \(SOS\)/ }));
    await screen.findByText(/PRIVATE_A_SOS/);
  }

  it("Support/Super admin -> Finance: the loaded private rows are gone at once and stay gone", async () => {
    await openSafetyAsA();
    // the new account's profile is slow: the old data must disappear BEFORE it arrives
    let answer;
    mod.api.me.mockImplementation(() => new Promise((resolve) => { answer = resolve; }));
    await act(async () => { other("new-B"); });
    expect(screen.queryByText(/PRIVATE_A_SOS/)).not.toBeInTheDocument();
    expect(screen.queryByText(/Private A actor/)).not.toBeInTheDocument();
    expect(screen.queryByText(/Support A/)).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Safety \(SOS\)/ })).not.toBeInTheDocument();

    who = { id: 2, fullName: "Finance B", role: "ADMIN", permissions: ["FINANCE"] };
    await act(async () => { answer(who); });
    await screen.findByText(/Admin · Finance B/);
    expect(screen.queryByText(/PRIVATE_A_SOS/)).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Safety \(SOS\)/ })).not.toBeInTheDocument();
    // the new account starts on the dashboard, not on the screen the old one left open
    expect(screen.queryByText("Trust & safety")).not.toBeInTheDocument();
  });

  it("the restricted screen is not even requested again for the new account", async () => {
    await openSafetyAsA();
    mod.api.safetyPage.mockClear();
    who = { id: 2, fullName: "Finance B", role: "ADMIN", permissions: ["FINANCE"] };
    await act(async () => { other("new-B"); });
    await screen.findByText(/Admin · Finance B/);
    await act(async () => { await new Promise((r) => setTimeout(r, 50)); });
    expect(mod.api.safetyPage).not.toHaveBeenCalled();
  });

  it("a failed profile hydration leaves the tab unprivileged with a retry, never the old identity or rows", async () => {
    await openSafetyAsA();
    mod.api.me.mockRejectedValue(Object.assign(new Error("Service Unavailable"), { status: 503 }));
    await act(async () => { other("new-B"); });
    expect(await screen.findByText("Could not load your profile")).toBeInTheDocument();
    expect(screen.queryByText(/PRIVATE_A_SOS/)).not.toBeInTheDocument();
    expect(screen.queryByText(/Support A/)).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Safety \(SOS\)/ })).not.toBeInTheDocument();

    // retry succeeds for Finance B
    who = { id: 2, fullName: "Finance B", role: "ADMIN", permissions: ["FINANCE"] };
    mod.api.me.mockImplementation(async () => who);
    fireEvent.click(screen.getByRole("button", { name: "Retry" }));
    await screen.findByText(/Admin · Finance B/);
    expect(screen.queryByText(/PRIVATE_A_SOS/)).not.toBeInTheDocument();
  });

  it("a rejected new profile (401) returns to the sign-in screen with nothing left behind", async () => {
    await openSafetyAsA();
    mod.api.me.mockRejectedValue(Object.assign(new Error("expired"), { status: 401 }));
    await act(async () => { other("new-B"); });
    await screen.findByText("Sign in to dashboard");
    expect(screen.queryByText(/PRIVATE_A_SOS/)).not.toBeInTheDocument();
  });

  it("the other tab signing OUT returns this tab to sign-in and drops the rows", async () => {
    await openSafetyAsA();
    window.localStorage.removeItem("aiwa_admin_session");
    await act(async () => { window.dispatchEvent(new StorageEvent("storage", { key: "aiwa_admin_session", newValue: null })); });
    await screen.findByText("Sign in to dashboard");
    expect(screen.queryByText(/PRIVATE_A_SOS/)).not.toBeInTheDocument();
  });

  it("the same account signing in elsewhere also reloads the views instead of keeping stale rows", async () => {
    await openSafetyAsA();
    mod.api.safetyPage.mockResolvedValue(pg([mod.normalizeSafety({ id: 100, bookingId: 6, actorName: "New actor", notes: "FRESH_SOS", createdAt: new Date().toISOString() })]));
    await act(async () => { other("same-user-again"); });
    await waitFor(() => expect(screen.queryByText(/PRIVATE_A_SOS/)).not.toBeInTheDocument());
  });
});
