import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import App from "../App.jsx";
import * as apiModule from "../api.js";

vi.setConfig({ testTimeout: 30_000 });

/**
 * Every screen of the sidebar must at least render for an admin who may open it. A render-time error (a hook used
 * before it is declared, a missing import) unmounts the whole panel; unit tests that render one component at a time
 * do not see it, but a real browser did (the Bookings screen, found while verifying AD-06). Server answers here are
 * deliberately empty or failing: the point is that the screen survives them.
 */

function res(status, body) {
  return { ok: status >= 200 && status < 300, status, text: async () => JSON.stringify(body) };
}

const ME = { id: 7, fullName: "Super Admin", role: "ADMIN", permissions: ["SUPER_ADMIN"] };

describe("<App> - every screen renders", () => {
  let errors;

  beforeEach(() => {
    apiModule.setTokens({ accessToken: "access" });
    errors = [];
    vi.spyOn(console, "error").mockImplementation((...args) => { errors.push(args.map(String).join(" ")); });
    vi.spyOn(globalThis, "fetch").mockImplementation(async (url) => {
      const path = String(url).replace("http://api.test/api", "");
      if (path === "/auth/me") return res(200, { data: ME });
      if (path === "/auth/refresh") return res(401, {});
      if (path.includes("/admin/dashboard")) return res(200, { data: { stats: [], activity: [] } });
      // lists: an empty page; everything else: a plain failure (which each screen must show, not crash on)
      if (/(page=|size=)/.test(path)) return res(200, { data: { content: [], totalPages: 1, totalElements: 0, number: 0 } });
      return res(503, { message: "not under test" });
    });
  });
  afterEach(() => vi.restoreAllMocks());

  it("opens each sidebar screen without crashing the panel", async () => {
    const { container } = render(<App />);
    await screen.findByRole("button", { name: /Dashboard/ });
    const labels = [
      "Safety (SOS)", "Verifications", "Complaints", "Flags", "Users & providers", "Bookings", "Reviews",
      "Photo moderation", "Chat reports", "Settlements", "Audit log", "Policies & support", "Dashboard"
    ];
    for (const label of labels) {
      fireEvent.click(screen.getByRole("button", { name: new RegExp(label.replace(/[()&]/g, "\\$&")) }));
      await waitFor(() => expect(container.querySelector("main")).not.toBeNull());
      // give the screen's loaders a moment to settle so a crash after the first fetch would show
      await new Promise((resolve) => setTimeout(resolve, 60));
      expect(container.querySelector("main"), `${label} left the panel standing`).not.toBeNull();
    }
    const crashes = errors.filter((e) => /Cannot access|is not defined|Uncaught|The above error occurred/.test(e));
    expect(crashes, crashes.join("\n")).toEqual([]);
  });
});
