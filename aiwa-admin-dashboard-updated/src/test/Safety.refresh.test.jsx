import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { render, screen, fireEvent, act } from "@testing-library/react";
import { Safety, useNavBadges, __setPermissionsForTest } from "../App.jsx";
import * as apiModule from "../api.js";

/**
 * CR-19: the SOS queue used to load once per filter, so an operator watching
 * the page saw a stale list. It now reloads every 15 s while the Open filter is
 * shown, and whenever the sidebar's SOS badge count changes.
 */

// The real hook that feeds the sidebar badge, next to the real page.
function Harness() {
  useNavBadges();
  return <Safety />;
}

const sosRow = { id: 1, kind: "SOS", targetRoute: "safety" };

async function tick(ms) {
  await act(async () => { await vi.advanceTimersByTimeAsync(ms); });
}

describe("<Safety> — CR-19 auto-refresh", () => {
  let safetyQueue;
  let inbox;

  beforeEach(() => {
    vi.useFakeTimers();
    window.localStorage.setItem("aiwa_admin_access_token", "test-token");
    __setPermissionsForTest(["SUPPORT"]);
    safetyQueue = vi.spyOn(apiModule.api, "safetyQueue").mockResolvedValue([]);
    inbox = vi.spyOn(apiModule.api, "inbox").mockResolvedValue([]);
  });

  afterEach(() => { vi.useRealTimers(); });

  it("reloads the open list every 15 seconds", async () => {
    render(<Safety />);
    await tick(0);
    expect(safetyQueue).toHaveBeenCalledTimes(1);
    await tick(15_000);
    expect(safetyQueue).toHaveBeenCalledTimes(2);
    await tick(30_000);
    expect(safetyQueue).toHaveBeenCalledTimes(4);
  });

  it("shows an alert that arrives between loads without a click", async () => {
    render(<Safety />);
    await tick(0);
    expect(screen.queryByText(/Provider is refusing to leave/)).not.toBeInTheDocument();
    safetyQueue.mockResolvedValue([apiModule.normalizeSafety({
      id: 9, bookingId: 5, actorName: "Mariam Adel", notes: "Provider is refusing to leave",
      createdAt: new Date().toISOString()
    })]);
    await tick(15_000);
    expect(screen.getByText(/Provider is refusing to leave/)).toBeInTheDocument();
  });

  it("reloads when the SOS badge count changes, and only then", async () => {
    render(<Harness />);
    await tick(60_000); // four interval reloads + the first load; badge poll sees no change
    expect(safetyQueue).toHaveBeenCalledTimes(5);

    inbox.mockResolvedValue([sosRow]);
    await tick(60_000); // four more interval reloads + one for the badge going 0 -> 1
    expect(safetyQueue).toHaveBeenCalledTimes(10);
  });

  it("does not poll on the Resolved filter and stops after unmount", async () => {
    const { unmount } = render(<Safety />);
    await tick(0);
    fireEvent.click(screen.getByRole("button", { name: "Resolved" }));
    await tick(0);
    expect(safetyQueue).toHaveBeenLastCalledWith("RESOLVED");
    const afterSwitch = safetyQueue.mock.calls.length;
    await tick(60_000);
    expect(safetyQueue).toHaveBeenCalledTimes(afterSwitch);

    fireEvent.click(screen.getByRole("button", { name: "Open" }));
    await tick(0);
    unmount();
    const afterUnmount = safetyQueue.mock.calls.length;
    await tick(60_000);
    expect(safetyQueue).toHaveBeenCalledTimes(afterUnmount);
  });
});
