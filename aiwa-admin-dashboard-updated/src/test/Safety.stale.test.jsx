import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { render, screen, act, fireEvent } from "@testing-library/react";
import { Safety, __setPermissionsForTest } from "../App.jsx";
import * as apiModule from "../api.js";
import { pg } from "./safetyPage.js";

/**
 * AD-05: a SOS poll that fails (network, 503, hang) must never leave a reassuring, apparently current list.
 * The screen says when it was last confirmed, shows a persistent stale warning, refuses to claim "no open
 * alerts", ignores late answers, and recovers on the next good poll.
 */

async function tick(ms) {
  await act(async () => { await vi.advanceTimersByTimeAsync(ms); });
}

const OPEN_ALERT = apiModule.normalizeSafety({
  id: 9, bookingId: 5, actorName: "Mariam Adel", notes: "Provider is refusing to leave",
  createdAt: new Date().toISOString()
});

describe("<Safety> - AD-05 stale / offline monitoring", () => {
  let safetyQueue;

  beforeEach(() => {
    vi.useFakeTimers();
    window.localStorage.setItem("aiwa_admin_session", "hint");
    __setPermissionsForTest(["SUPPORT"]);
    safetyQueue = vi.spyOn(apiModule.api, "safetyPage").mockResolvedValue(pg([]));
  });
  afterEach(() => { vi.useRealTimers(); });

  it("says the list is live and when it was confirmed while polling works", async () => {
    render(<Safety />);
    await tick(0);
    expect(screen.getByText(/Live · updated/)).toBeInTheDocument();
    expect(screen.queryByTestId("sos-stale-banner")).not.toBeInTheDocument();
    expect(screen.getByText("No open SOS alerts")).toBeInTheDocument();
  });

  it("a failed poll shows a persistent stale warning and stops claiming there are no open alerts", async () => {
    render(<Safety />);
    await tick(0);
    safetyQueue.mockRejectedValue(new Error("Service Unavailable"));
    await tick(15_000);

    const banner = screen.getByTestId("sos-stale-banner");
    expect(banner).toHaveTextContent(/out of date/i);
    expect(banner).toHaveTextContent(/Service Unavailable/);
    expect(banner).toHaveTextContent(/on-call SMS/i);
    expect(screen.getByText(/Not live · updated/)).toBeInTheDocument();
    expect(screen.queryByText("No open SOS alerts")).not.toBeInTheDocument();
    expect(screen.getByText(/Can't confirm there are no open alerts/)).toBeInTheDocument();

    // it stays until a poll succeeds, however many more fail
    await tick(30_000);
    expect(screen.getByTestId("sos-stale-banner")).toBeInTheDocument();
  });

  it("keeps showing the last alerts, labelled as of the last update, when polling fails", async () => {
    safetyQueue.mockResolvedValue(pg([OPEN_ALERT]));
    render(<Safety />);
    await tick(0);
    safetyQueue.mockRejectedValue(new TypeError("Failed to fetch"));
    await tick(15_000);
    expect(screen.getByText(/Provider is refusing to leave/)).toBeInTheDocument();
    expect(screen.getByText(/1 open \(as of last update\)/)).toBeInTheDocument();
  });

  it("recovers: the next good poll clears the warning and shows the new alert", async () => {
    render(<Safety />);
    await tick(0);
    safetyQueue.mockRejectedValue(new Error("boom"));
    await tick(15_000);
    expect(screen.getByTestId("sos-stale-banner")).toBeInTheDocument();

    safetyQueue.mockResolvedValue(pg([OPEN_ALERT])); // an incident was raised while we were blind
    await tick(15_000);
    expect(screen.queryByTestId("sos-stale-banner")).not.toBeInTheDocument();
    expect(screen.getByText(/Provider is refusing to leave/)).toBeInTheDocument();
    expect(screen.getByText(/Live · updated/)).toBeInTheDocument();
  });

  it("a hung poll counts as a failure after the timeout and polls never overlap", async () => {
    render(<Safety />);
    await tick(0);
    const hung = new Promise(() => {});
    safetyQueue.mockReturnValue(hung);
    await tick(15_000); // starts the hung poll
    const calls = safetyQueue.mock.calls.length;
    await tick(5_000);  // still in flight: no second poll is started
    expect(safetyQueue).toHaveBeenCalledTimes(calls);
    await tick(6_000);  // 10 s timeout reached
    expect(screen.getByTestId("sos-stale-banner")).toHaveTextContent(/did not answer in time/);
  });

  it("goes stale on its own when no answer has been confirmed for too long, even with no error", async () => {
    render(<Safety />);
    await tick(0);
    // every poll "succeeds" slowly enough that nothing lands: simulate by making polls hang forever
    safetyQueue.mockReturnValue(new Promise(() => {}));
    await tick(120_000);
    expect(screen.getByTestId("sos-stale-banner")).toBeInTheDocument();
  });

  it("an offline browser is flagged at once", async () => {
    render(<Safety />);
    await tick(0);
    await act(async () => { window.dispatchEvent(new Event("offline")); });
    expect(screen.getByTestId("sos-stale-banner")).toHaveTextContent(/offline/i);
    safetyQueue.mockResolvedValue(pg([]));
    await act(async () => { window.dispatchEvent(new Event("online")); await vi.advanceTimersByTimeAsync(0); });
    expect(screen.queryByTestId("sos-stale-banner")).not.toBeInTheDocument();
  });

  it("Retry now reloads the list", async () => {
    render(<Safety />);
    await tick(0);
    safetyQueue.mockRejectedValue(new Error("boom"));
    await tick(15_000);
    safetyQueue.mockResolvedValue(pg([OPEN_ALERT]));
    fireEvent.click(screen.getByRole("button", { name: /Retry now/ }));
    await tick(0);
    expect(screen.getByText(/Provider is refusing to leave/)).toBeInTheDocument();
  });
});
