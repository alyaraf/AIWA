import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, waitFor, fireEvent, within, act } from "@testing-library/react";
import { SettlementDetail, ConfirmHost, refreshApp, __setPermissionsForTest } from "../App.jsx";
import * as apiModule from "../api.js";

/**
 * AD-03: one confirmed payout settles one frozen report; whatever the refreshed balance still owes stays visible
 * and actionable. AD-10: a retry that succeeds clears the earlier error. AD-06: global Refresh reloads this screen.
 */

const OWING = {
  providerId: 11, providerName: "Nadia Studio", settlementPaused: false, status: "WITHIN_LIMIT",
  paymentReportedAt: "2026-10-01T10:00:00", commissionPercent: 10, platformCommissionPercent: 10,
  totalOwed: 173.4, dueDate: "2026-10-08T00:00:00", entries: []
};

describe("<SettlementDetail> - AD-03 / AD-10 / AD-06", () => {
  beforeEach(() => {
    window.localStorage.setItem("aiwa_admin_session", "hint");
    __setPermissionsForTest(["FINANCE"]);
    vi.spyOn(apiModule.api, "providerSettings").mockResolvedValue({});
  });

  it("after confirming a payout, the 45.00 still owed keeps the confirm action available", async () => {
    const detail = vi.spyOn(apiModule.api, "settlementDetail").mockResolvedValue(OWING);
    vi.spyOn(apiModule.api, "payoutReport").mockResolvedValue({ reportedAt: "2026-10-01T10:00:00", total: 128.4, entryCount: 2 });
    vi.spyOn(apiModule.api, "confirmPayout").mockImplementation(async () => {
      detail.mockResolvedValue({ ...OWING, totalOwed: 45, paymentReportedAt: null }); // newer ledger remains
      return {};
    });
    render(<><SettlementDetail providerId={11} onBack={() => {}} /><ConfirmHost /></>);

    fireEvent.click(await screen.findByRole("button", { name: /Confirm payout received/i }));
    const dialog = await screen.findByRole("alertdialog");
    fireEvent.click(within(dialog).getByRole("button", { name: /^Confirm payout$/i }));

    await screen.findByText(/Payout of EGP 128\.40 confirmed/);
    expect(await screen.findByText(/still owed/i)).toHaveTextContent("45.00");
    expect(screen.getByRole("button", { name: /Confirm payout received/i })).toBeEnabled();
  });

  it("shows nothing-owed only when the refreshed balance is really zero", async () => {
    vi.spyOn(apiModule.api, "settlementDetail").mockResolvedValue({ ...OWING, totalOwed: 0, status: "SETTLED" });
    render(<SettlementDetail providerId={11} onBack={() => {}} />);
    expect(await screen.findByText(/Nothing owed/)).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Confirm payout received/i })).not.toBeInTheDocument();
  });

  it("AD-10: 503 then Retry then 200 shows the detail, not the old error", async () => {
    const detail = vi.spyOn(apiModule.api, "settlementDetail").mockRejectedValueOnce(new Error("Service Unavailable"));
    render(<SettlementDetail providerId={11} onBack={() => {}} />);
    expect(await screen.findByText(/Service Unavailable/)).toBeInTheDocument();

    detail.mockResolvedValue(OWING);
    fireEvent.click(screen.getByRole("button", { name: /Try again/i }));

    expect(await screen.findByRole("heading", { name: "Nadia Studio" })).toBeInTheDocument();
    expect(screen.queryByText(/Service Unavailable/)).not.toBeInTheDocument();
  });

  it("AD-06: the global refresh reloads this screen and reports a failure honestly", async () => {
    const detail = vi.spyOn(apiModule.api, "settlementDetail").mockResolvedValue(OWING);
    render(<SettlementDetail providerId={11} onBack={() => {}} />);
    await screen.findByRole("heading", { name: "Nadia Studio" });
    expect(detail).toHaveBeenCalledTimes(1);

    // the sync act flushes the state change and the load effect it triggers; awaiting inside one act would deadlock
    let run;
    let ok;
    act(() => { run = refreshApp(); });
    await act(async () => { ok = await run; });
    expect(detail).toHaveBeenCalledTimes(2);
    expect(ok).toBe(true);

    detail.mockRejectedValue(new Error("down"));
    act(() => { run = refreshApp(); });
    await act(async () => { ok = await run; });
    expect(ok).toBe(false);
  });
});
