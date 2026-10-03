import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, fireEvent, waitFor, act, within } from "@testing-library/react";
import App from "../App.jsx";
import * as apiModule from "../api.js";

/**
 * CR-22: after a reload the panel used to start as the mock super admin, and
 * any failure of /auth/me (a 5xx, a network blip) cleared the tokens. It now
 * starts with an empty loading session, signs out only on 401, and asks before
 * the platform commission rate changes.
 */

function res(status, body) {
  return { ok: status >= 200 && status < 300, status, text: async () => JSON.stringify(body) };
}

// Routes every request; /auth/me is whatever the test says, the rest answers
// just enough for the Settlements screen and fails with 500 otherwise.
function routeFetch(me) {
  return vi.spyOn(globalThis, "fetch").mockImplementation(async (url, init) => {
    const path = String(url).replace("http://api.test/api", "");
    if (path === "/auth/me") return me(init);
    if (path.startsWith("/admin/settlements/overview")) return res(200, { data: { totalOwed: 0, providerCount: 0 } });
    if (path.startsWith("/admin/settlements/providers")) return res(200, { data: [] });
    if (path.startsWith("/admin/settings/commission")) return res(200, { data: { commissionPercent: 10 } });
    if (path.startsWith("/admin/inbox")) return res(200, { data: [] });
    return res(500, { message: "not under test" });
  });
}

const ME = { id: 7, fullName: "Nour Support", role: "ADMIN", permissions: ["FINANCE"] };

beforeEach(() => {
  window.localStorage.setItem("aiwa_admin_access_token", "access");
  window.localStorage.setItem("aiwa_admin_refresh_token", "refresh");
});

describe("<App> — CR-22 session start", () => {
  it("shows no admin identity and no admin action until /auth/me answers", async () => {
    let answer;
    routeFetch(() => new Promise((resolve) => { answer = resolve; }));
    render(<App />);
    fireEvent.click(screen.getByRole("button", { name: /Settlements/ }));
    await screen.findByText("Commission rate");
    expect(screen.queryByText(/S\. Mahmoud/)).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Edit commission rate" })).not.toBeInTheDocument();

    await act(async () => { answer(res(200, { data: ME })); });
    expect(await screen.findByText(/Nour Support/)).toBeInTheDocument();
    expect(await screen.findByRole("button", { name: "Edit commission rate" })).toBeInTheDocument();
  });

  it("keeps the tokens and offers a retry when /auth/me fails with a 500", async () => {
    let healthy = false;
    const fetchSpy = routeFetch(() => (healthy ? res(200, { data: ME }) : res(500, { message: "boom" })));
    render(<App />);
    const retry = await screen.findByRole("button", { name: "Retry" });
    expect(window.localStorage.getItem("aiwa_admin_access_token")).toBe("access");
    expect(window.localStorage.getItem("aiwa_admin_refresh_token")).toBe("refresh");
    expect(screen.queryByText("Sign in to dashboard")).not.toBeInTheDocument();

    healthy = true;
    fireEvent.click(retry);
    expect(await screen.findByText(/Nour Support/)).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Retry" })).not.toBeInTheDocument();
    expect(fetchSpy.mock.calls.filter(([u]) => String(u).endsWith("/auth/me"))).toHaveLength(2);
  });

  it("keeps the tokens on a network error", async () => {
    routeFetch(() => { throw new TypeError("Failed to fetch"); });
    render(<App />);
    expect(await screen.findByRole("button", { name: "Retry" })).toBeInTheDocument();
    expect(window.localStorage.getItem("aiwa_admin_access_token")).toBe("access");
    expect(screen.queryByText("Sign in to dashboard")).not.toBeInTheDocument();
  });

  it("clears the tokens and shows the sign-in screen on a 401", async () => {
    window.localStorage.removeItem("aiwa_admin_refresh_token"); // nothing to refresh with
    routeFetch(() => res(401, { message: "Unauthorized" }));
    render(<App />);
    expect(await screen.findByText("Sign in to dashboard")).toBeInTheDocument();
    expect(window.localStorage.getItem("aiwa_admin_access_token")).toBeNull();
  });
});

describe("<App> — CR-22 commission change", () => {
  it("asks for confirmation before the rate changes", async () => {
    routeFetch(() => res(200, { data: ME }));
    const setCommission = vi.spyOn(apiModule.api, "setCommission").mockResolvedValue({ commissionPercent: 12 });
    render(<App />);
    fireEvent.click(screen.getByRole("button", { name: /Settlements/ }));
    fireEvent.click(await screen.findByRole("button", { name: "Edit commission rate" }));
    fireEvent.change(screen.getByLabelText("Commission percent"), { target: { value: "12" } });
    fireEvent.click(screen.getByRole("button", { name: "Save" }));

    const dialog = await screen.findByRole("alertdialog");
    expect(dialog).toHaveTextContent(/12%/);
    expect(setCommission).not.toHaveBeenCalled();

    fireEvent.click(within(dialog).getByRole("button", { name: "Change rate" }));
    await waitFor(() => expect(setCommission).toHaveBeenCalledWith(12));
  });

  it("does not change the rate when the dialog is cancelled", async () => {
    routeFetch(() => res(200, { data: ME }));
    const setCommission = vi.spyOn(apiModule.api, "setCommission").mockResolvedValue({ commissionPercent: 12 });
    render(<App />);
    fireEvent.click(screen.getByRole("button", { name: /Settlements/ }));
    fireEvent.click(await screen.findByRole("button", { name: "Edit commission rate" }));
    fireEvent.change(screen.getByLabelText("Commission percent"), { target: { value: "12" } });
    fireEvent.click(screen.getByRole("button", { name: "Save" }));
    fireEvent.click(within(await screen.findByRole("alertdialog")).getByRole("button", { name: "Cancel" }));
    expect(setCommission).not.toHaveBeenCalled();
  });
});
