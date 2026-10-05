import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, waitFor, fireEvent, within } from "@testing-library/react";
import { Flags, ConfirmHost, __setPermissionsForTest } from "../App.jsx";
import * as apiModule from "../api.js";

/**
 * AD-07: warn/suspend and "close the complaint" are two writes. When the second fails, the first has happened:
 * the row stays and says so, nothing is repeated, and only the closing step can be retried.
 */

const FLAG = { id: 1, type: "PROVIDER", name: "Maadi Hammam", reason: "Double charge", reporter: "Yara", targetUserId: 42, targetProviderId: 3 };

async function startWarn() {
  fireEvent.click(await screen.findByRole("button", { name: /^Review$/i }));
  fireEvent.click(await screen.findByRole("button", { name: /Send warning/i }));
  const dialog = await screen.findByRole("alertdialog");
  fireEvent.click(within(dialog).getByRole("button", { name: /^Send warning$/i }));
}

describe("<Flags> - AD-07 partial operations", () => {
  beforeEach(() => {
    window.localStorage.setItem("aiwa_admin_session", "hint");
    __setPermissionsForTest(["SUPPORT"]);
  });

  it("a failed closing step keeps the flag, says the warning went out, and retries only the closing step", async () => {
    const flags = vi.spyOn(apiModule.api, "flags").mockResolvedValue([FLAG]);
    const warn = vi.spyOn(apiModule.api, "warnUser").mockResolvedValue({});
    const resolve = vi.spyOn(apiModule.api, "resolveComplaint")
      .mockRejectedValueOnce(new Error("Service Unavailable"))
      .mockResolvedValue({});
    render(<><Flags /><ConfirmHost /></>);

    await startWarn();

    expect(await screen.findByText(/Warning sent to Maadi Hammam/, { selector: "strong" })).toBeInTheDocument();
    expect(screen.getByText("Maadi Hammam", { selector: ".strong-cell" })).toBeInTheDocument(); // row not removed
    expect(screen.queryByRole("button", { name: /Send warning/i })).not.toBeInTheDocument(); // cannot warn twice
    expect(warn).toHaveBeenCalledTimes(1);

    flags.mockResolvedValue([]); // once the complaint is closed the server no longer lists it
    fireEvent.click(screen.getByRole("button", { name: /Retry closing/i }));
    await waitFor(() => expect(resolve).toHaveBeenCalledTimes(2));
    expect(warn).toHaveBeenCalledTimes(1); // the warning was NOT sent again
    await waitFor(() => expect(screen.queryByText("Maadi Hammam", { selector: ".strong-cell" })).not.toBeInTheDocument());
    expect(flags).toHaveBeenCalled();
  });

  it("no refresh runs between the two writes, so a stale list cannot reinsert the row", async () => {
    const flags = vi.spyOn(apiModule.api, "flags").mockResolvedValue([FLAG]);
    vi.spyOn(apiModule.api, "warnUser").mockResolvedValue({});
    let finishClose;
    vi.spyOn(apiModule.api, "resolveComplaint").mockImplementation(() => new Promise((resolve) => { finishClose = resolve; }));
    render(<><Flags /><ConfirmHost /></>);
    await screen.findByRole("button", { name: /^Review$/i });
    const loadsBefore = flags.mock.calls.length;

    await startWarn();
    await waitFor(() => expect(finishClose).toBeTypeOf("function"));
    expect(flags.mock.calls.length).toBe(loadsBefore); // warn succeeded, closing still pending: no reload yet
    finishClose({});
    await waitFor(() => expect(flags.mock.calls.length).toBeGreaterThan(loadsBefore)); // refreshed once, after both writes
  });

  it("when the first write fails nothing is closed", async () => {
    vi.spyOn(apiModule.api, "flags").mockResolvedValue([FLAG]);
    vi.spyOn(apiModule.api, "warnUser").mockRejectedValue(new Error("nope"));
    const resolve = vi.spyOn(apiModule.api, "resolveComplaint").mockResolvedValue({});
    render(<><Flags /><ConfirmHost /></>);
    await startWarn();
    await waitFor(() => expect(apiModule.api.warnUser).toHaveBeenCalled());
    expect(resolve).not.toHaveBeenCalled();
    expect(screen.getByText("Maadi Hammam", { selector: ".strong-cell" })).toBeInTheDocument();
  });
});
