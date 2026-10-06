import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, waitFor, fireEvent, within } from "@testing-library/react";
import { Flags, ConfirmHost, __setPermissionsForTest } from "../App.jsx";
import * as apiModule from "../api.js";

/**
 * All three Flag actions (warn / suspend / dismiss) must go through the
 * AIWA confirm dialog before contacting a real user or closing a complaint.
 * Sending a warning silently on one misclick is the specific footgun this
 * suite exists to prevent.
 */

const FLAG = {
  id: 1,
  type: "PROVIDER",
  name: "Maadi Hammam",
  reason: "Booking double-charged",
  reporter: "Yara Aboud",
  targetUserId: 42,          // owner user id (populated for provider flags via targetProviderOwnerUserId)
  targetProviderId: 3
};

function renderFlags() {
  vi.spyOn(apiModule.api, "flagsPage").mockResolvedValue({ rows: [FLAG], total: 1, totalPages: 1 });
  return render(
    <>
      <Flags />
      <ConfirmHost />
    </>
  );
}

async function expandFlagRow() {
  // The row's actions only show up after clicking Review.
  fireEvent.click(await screen.findByRole("button", { name: /^Review$/i }));
  return await screen.findByRole("button", { name: /Send warning/i });
}

describe("<Flags> — every destructive action goes through a confirm dialog", () => {
  beforeEach(() => {
    window.localStorage.clear();
    window.localStorage.setItem("aiwa_admin_access_token", "test-token");
    // <App>'s useEffect normally seeds currentPermissions from session.user;
    // we render <Flags> in isolation so seed it directly.
    __setPermissionsForTest(["SUPER_ADMIN", "FINANCE", "SUPPORT"]);
  });

  it("Send warning shows a confirm dialog — clicking outside the dialog does NOT send anything", async () => {
    const warnSpy = vi.spyOn(apiModule.api, "warnUser").mockResolvedValue({});
    renderFlags();
    await expandFlagRow();

    fireEvent.click(screen.getByRole("button", { name: /Send warning/i }));

    // Dialog appears with the specific claim the confirm body should carry.
    const dialog = await screen.findByRole("alertdialog");
    expect(within(dialog).getByText(/Send a warning to Maadi Hammam/i)).toBeInTheDocument();
    // Cancel by clicking the Cancel button.
    fireEvent.click(within(dialog).getByRole("button", { name: /^Cancel$/i }));

    // Absolutely no warning fires — that was the whole point of the confirm.
    expect(warnSpy).not.toHaveBeenCalled();
  });

  it("Send warning + confirm sends the warning via api.warnUser and closes out the flag", async () => {
    const warnSpy = vi.spyOn(apiModule.api, "warnUser").mockResolvedValue({});
    const resolveSpy = vi.spyOn(apiModule.api, "resolveComplaint").mockResolvedValue({});
    renderFlags();
    await expandFlagRow();

    fireEvent.click(screen.getByRole("button", { name: /Send warning/i }));
    const dialog = await screen.findByRole("alertdialog");
    fireEvent.click(within(dialog).getByRole("button", { name: /Send warning/i }));

    await waitFor(() => expect(warnSpy).toHaveBeenCalledWith(42, "Booking double-charged"));
    // The complaint is also resolved server-side so the flag doesn't come
    // right back on refresh — regression guard for the original bug.
    await waitFor(() => expect(resolveSpy).toHaveBeenCalledWith(1, expect.stringContaining("Warned")));
  });

  it("Dismiss shows a confirm dialog before marking the complaint resolved", async () => {
    const resolveSpy = vi.spyOn(apiModule.api, "resolveComplaint").mockResolvedValue({});
    renderFlags();
    await expandFlagRow();

    fireEvent.click(screen.getByRole("button", { name: /^Dismiss$/i }));

    const dialog = await screen.findByRole("alertdialog");
    expect(within(dialog).getByText(/Dismiss this flag/i)).toBeInTheDocument();
    fireEvent.click(within(dialog).getByRole("button", { name: /^Cancel$/i }));

    expect(resolveSpy).not.toHaveBeenCalled();
  });

  it("Dismiss + confirm resolves the complaint", async () => {
    const resolveSpy = vi.spyOn(apiModule.api, "resolveComplaint").mockResolvedValue({});
    renderFlags();
    await expandFlagRow();

    fireEvent.click(screen.getByRole("button", { name: /^Dismiss$/i }));
    const dialog = await screen.findByRole("alertdialog");
    fireEvent.click(within(dialog).getByRole("button", { name: /Dismiss flag/i }));

    await waitFor(() =>
      expect(resolveSpy).toHaveBeenCalledWith(1, expect.stringContaining("no action"))
    );
  });

  it("Suspend / ban shows a confirm dialog (regression guard — it always had one, must stay that way)", async () => {
    const suspendSpy = vi.spyOn(apiModule.api, "suspendProvider").mockResolvedValue({});
    renderFlags();
    await expandFlagRow();

    fireEvent.click(screen.getByRole("button", { name: /Suspend \/ ban/i }));

    const dialog = await screen.findByRole("alertdialog");
    expect(within(dialog).getByText(/Suspend Maadi Hammam/i)).toBeInTheDocument();
    fireEvent.click(within(dialog).getByRole("button", { name: /^Cancel$/i }));

    expect(suspendSpy).not.toHaveBeenCalled();
  });
});
