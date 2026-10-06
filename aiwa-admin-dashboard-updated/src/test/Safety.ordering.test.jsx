import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { render, screen, act, fireEvent } from "@testing-library/react";
import { Safety, __setPermissionsForTest, __notifyBadgeChange } from "../App.jsx";
import { api, normalizeSafety } from "../api.js";
import { pg } from "./safetyPage.js";

/**
 * R4-07: initial, manual, badge-triggered and periodic reads are ONE ordered stream. An older answer never replaces a
 * newer one, and "Live · updated" is only recorded for an accepted server read, never for a local change.
 */

async function tick(ms) {
  await act(async () => { await vi.advanceTimersByTimeAsync(ms); });
}

const sos = (id, notes) => normalizeSafety({ id, bookingId: 5, actorName: "Customer", notes, createdAt: new Date().toISOString() });
const NEW_SOS = sos(9, "NEW_SOS");

function deferred() {
  let resolve; let reject;
  const promise = new Promise((res, rej) => { resolve = res; reject = rej; });
  return { promise, resolve, reject };
}

describe("<Safety> - R4-07 ordering and freshness", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    window.localStorage.setItem("aiwa_admin_session", "hint");
    __setPermissionsForTest(["SUPPORT"]);
  });
  afterEach(() => { vi.useRealTimers(); });

  it("an old initial read that finishes after a newer poll does not erase the new alert or claim Live", async () => {
    const old = deferred();
    const queue = vi.spyOn(api, "safetyPage").mockReturnValueOnce(old.promise).mockResolvedValue(pg([NEW_SOS]));
    render(<Safety />);
    await tick(15_000);
    expect(queue).toHaveBeenCalledTimes(2);
    expect(screen.getByText(/NEW_SOS/)).toBeInTheDocument();
    await act(async () => { old.resolve(pg([])); await vi.advanceTimersByTimeAsync(0); });
    expect(screen.getByText(/NEW_SOS/)).toBeInTheDocument();
    expect(screen.queryByText("No open SOS alerts")).not.toBeInTheDocument();
  });

  it("an initial read that is slower than the timeout is reported, and the next poll recovers", async () => {
    const old = deferred();
    vi.spyOn(api, "safetyPage").mockReturnValueOnce(old.promise).mockResolvedValue(pg([NEW_SOS]));
    render(<Safety />);
    await tick(10_500);
    expect(screen.getByText(/did not answer in time/)).toBeInTheDocument();
    expect(screen.queryByText("No open SOS alerts")).not.toBeInTheDocument();
    await tick(5_000);
    expect(screen.getByText(/NEW_SOS/)).toBeInTheDocument();
    expect(screen.getByText(/Live · updated/)).toBeInTheDocument();
    await act(async () => { old.resolve(pg([])); await vi.advanceTimersByTimeAsync(0); });
    expect(screen.getByText(/NEW_SOS/)).toBeInTheDocument();
  });

  it("reversed responses: a badge-triggered read that answers first wins over the older read that answers last", async () => {
    const first = deferred();
    const second = deferred();
    const queue = vi.spyOn(api, "safetyPage").mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise);
    render(<Safety />);
    await tick(0);
    // the sidebar badge changes: a second read starts while the first is still in flight
    await act(async () => { __notifyBadgeChange("safety"); await vi.advanceTimersByTimeAsync(0); });
    expect(queue).toHaveBeenCalledTimes(2);
    await act(async () => { second.resolve(pg([NEW_SOS])); await vi.advanceTimersByTimeAsync(0); });
    expect(screen.getByText(/NEW_SOS/)).toBeInTheDocument();
    await act(async () => { first.resolve(pg([])); await vi.advanceTimersByTimeAsync(0); });
    expect(screen.getByText(/NEW_SOS/)).toBeInTheDocument();
    expect(screen.queryByText("No open SOS alerts")).not.toBeInTheDocument();
  });

  it("closing an alert is a local change: it records no freshness and an older read cannot bring the alert back", async () => {
    const closed = sos(11, "CLOSE_ME");
    const queue = vi.spyOn(api, "safetyPage").mockResolvedValue(pg([closed]));
    vi.spyOn(api, "resolveSafety").mockResolvedValue({});
    render(<Safety />);
    await tick(0);
    const stamp = () => screen.getByText(/Live · updated/).textContent;
    const before = stamp();
    // a read that started before the closing is still in flight and will say the alert is open
    const older = deferred();
    queue.mockReturnValueOnce(older.promise);
    await tick(15_000); // the 15 s poll starts and hangs on `older`
    fireEvent.change(screen.getByPlaceholderText(/What was done/), { target: { value: "called her" } });
    // every read after the closing hangs: no server answer exists yet (the global refresh and the confirming read both wait)
    queue.mockReturnValue(new Promise(() => {}));
    fireEvent.click(screen.getByRole("button", { name: /Close alert/ }));
    await tick(0);
    expect(screen.queryByText(/CLOSE_ME/)).not.toBeInTheDocument();
    await act(async () => { older.resolve(pg([closed])); await vi.advanceTimersByTimeAsync(0); });
    expect(screen.queryByText(/CLOSE_ME/)).not.toBeInTheDocument();
    // freshness: still the time of the last accepted server read (the 15 s poll's answer was dropped), not "now"
    expect(stamp()).toBe(before);
    queue.mockResolvedValue(pg([])); // the server finally answers with the truth
    await tick(15_000);
    expect(screen.getByText("No open SOS alerts")).toBeInTheDocument();
  });

  it("an initial failure shows the error, and a later good poll recovers it", async () => {
    vi.spyOn(api, "safetyPage").mockRejectedValueOnce(new Error("boom")).mockResolvedValue(pg([NEW_SOS]));
    render(<Safety />);
    await tick(0);
    expect(screen.getByText(/Could not load SOS alerts: boom/)).toBeInTheDocument();
    await tick(15_000);
    expect(screen.getByText(/NEW_SOS/)).toBeInTheDocument();
    expect(screen.queryByText(/Could not load SOS alerts/)).not.toBeInTheDocument();
  });

  it("a Retry that hangs keeps the list stale instead of claiming it is live, and can be tried again", async () => {
    const queue = vi.spyOn(api, "safetyPage").mockResolvedValue(pg([NEW_SOS]));
    render(<Safety />);
    await tick(0);
    queue.mockRejectedValue(new Error("Service Unavailable"));
    await tick(15_000);
    expect(screen.getByTestId("sos-stale-banner")).toBeInTheDocument();
    queue.mockReturnValue(new Promise(() => {}));
    fireEvent.click(screen.getByRole("button", { name: /Retry now/ }));
    await tick(11_000);
    expect(screen.getByTestId("sos-stale-banner")).toBeInTheDocument();
    expect(screen.queryByText(/Live · updated/)).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Retry now/ })).toBeEnabled();
  });
});
