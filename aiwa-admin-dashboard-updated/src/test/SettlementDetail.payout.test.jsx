import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, waitFor, fireEvent, within } from "@testing-library/react";
import { SettlementDetail, ConfirmHost, __setPermissionsForTest } from "../App.jsx";
import * as apiModule from "../api.js";

/**
 * CR-06: the payout dialog showed no amount and the request carried none, so
 * the server's amount check never ran. The dialog now shows the total the
 * provider reported and the confirmation sends it as expectedAmount.
 */

const DETAIL = {
  providerId: 11, providerName: "Nadia Studio", settlementPaused: false, status: "WITHIN_LIMIT",
  paymentReportedAt: "2026-10-01T10:00:00", commissionPercent: 10, commissionOverridePercent: null,
  platformCommissionPercent: 10,
  // 45.00 of this was recorded after the provider reported paying 128.40.
  totalOwed: 173.4, dueDate: "2026-10-08T00:00:00", entries: []
};

describe("<SettlementDetail> — confirm payout", () => {
  beforeEach(() => {
    __setPermissionsForTest(["FINANCE"]);
    vi.spyOn(apiModule.api, "providerSettings").mockResolvedValue({});
    vi.spyOn(apiModule.api, "settlementDetail").mockResolvedValue(DETAIL);
  });

  it("shows the reported total and confirms with exactly that amount", async () => {
    const reportSpy = vi.spyOn(apiModule.api, "payoutReport")
      .mockResolvedValue({ reportedAt: "2026-10-01T10:00:00", total: 128.4, entryCount: 2 });
    const confirmSpy = vi.spyOn(apiModule.api, "confirmPayout").mockResolvedValue({ ...DETAIL, totalOwed: 45 });
    render(<><SettlementDetail providerId={11} onBack={() => {}} /><ConfirmHost /></>);

    fireEvent.click(await screen.findByRole("button", { name: /Confirm payout received/i }));

    const dialog = await screen.findByRole("alertdialog");
    expect(reportSpy).toHaveBeenCalledWith(11);
    expect(within(dialog).getByText(/EGP 128\.40/)).toBeInTheDocument();
    expect(within(dialog).getByText(/2 entries/)).toBeInTheDocument();
    expect(confirmSpy).not.toHaveBeenCalled();

    fireEvent.click(within(dialog).getByRole("button", { name: /^Confirm payout$/i }));
    await waitFor(() => expect(confirmSpy).toHaveBeenCalledWith(11, 128.4));
  });

  it("the confirm request carries expectedAmount", async () => {
    window.localStorage.setItem("aiwa_admin_access_token", "test-token");
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(async () =>
      new Response(JSON.stringify({ success: true, data: {} }),
        { status: 200, headers: { "Content-Type": "application/json" } }));

    await apiModule.api.confirmPayout(11, 128.4);

    const [url, options] = fetchSpy.mock.calls[0];
    expect(options.method).toBe("POST");
    expect(new URL(url).pathname).toMatch(/\/admin\/settlements\/provider\/11\/confirm-payout$/);
    expect(new URL(url).searchParams.get("expectedAmount")).toBe("128.4");
  });
});
