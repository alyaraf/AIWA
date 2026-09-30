import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, fireEvent, within, waitFor } from "@testing-library/react";
import { ProfileView, ConfirmHost, __setPermissionsForTest } from "../App.jsx";
import * as apiModule from "../api.js";

/**
 * OPS-10: pausing a provider's new bookings from their profile stops their
 * income, so it must confirm first, like the same toggle on Settlements.
 */

const USER = { id: 5, role: "PROVIDER", providerProfileId: 11, fullName: "Nadia Studio", email: "n@x.com", active: true };

function renderProfile() {
  vi.spyOn(apiModule.api, "providerDetail").mockResolvedValue({ id: 11, verificationStatus: "APPROVED", settlementPaused: false });
  vi.spyOn(apiModule.api, "providerStaff").mockResolvedValue([]);
  vi.spyOn(apiModule.api, "userActivity").mockResolvedValue({ bookings: [], reviews: [], complaints: [] });
  vi.spyOn(apiModule.api, "providerSettings").mockResolvedValue({});
  return render(<><ProfileView user={USER} onBack={() => {}} /><ConfirmHost /></>);
}

describe("<ProfileView> pause new bookings", () => {
  beforeEach(() => {
    window.localStorage.clear();
    __setPermissionsForTest(["SUPER_ADMIN", "FINANCE", "SUPPORT"]);
  });

  it("asks before pausing, and Cancel sends nothing", async () => {
    const pause = vi.spyOn(apiModule.api, "setSettlementPause").mockResolvedValue({});
    renderProfile();

    fireEvent.click(await screen.findByRole("button", { name: /Pause new bookings/i }));
    const dialog = await screen.findByRole("alertdialog");
    expect(within(dialog).getByText(/Pause new bookings for Nadia Studio\?/i)).toBeInTheDocument();
    fireEvent.click(within(dialog).getByRole("button", { name: /^Cancel$/i }));

    await waitFor(() => expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument());
    expect(pause).not.toHaveBeenCalled();
  });

  it("pauses only after the admin confirms", async () => {
    const pause = vi.spyOn(apiModule.api, "setSettlementPause").mockResolvedValue({});
    renderProfile();

    fireEvent.click(await screen.findByRole("button", { name: /Pause new bookings/i }));
    const dialog = await screen.findByRole("alertdialog");
    fireEvent.click(within(dialog).getByRole("button", { name: /^Pause bookings$/i }));

    await waitFor(() => expect(pause).toHaveBeenCalledWith(11, true));
  });
});
