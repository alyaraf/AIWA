import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, waitFor, fireEvent } from "@testing-library/react";
import { TotpSetupCard } from "../App.jsx";
import * as apiModule from "../api.js";

/**
 * The provider-side 2FA flow: enable, disable, and the small in-between
 * "setup started but not yet confirmed" state. Zero coverage today — worth
 * pinning down because every button here is one that can lock an admin out
 * of their own account if it silently breaks.
 */

describe("<TotpSetupCard>", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it("renders the Set up CTA when 2FA is currently disabled for this account", async () => {
    vi.spyOn(apiModule.api, "totpStatus").mockResolvedValue({ enabled: false });
    render(<TotpSetupCard />);

    // The initial "Loading…" shows briefly while /2fa/status is in flight.
    expect(await screen.findByRole("button", { name: /Set up two-factor authentication/i }))
      .toBeInTheDocument();
    // And no "Enabled" or "Turn off" language when it's off.
    expect(screen.queryByText(/^Enabled/i)).toBeNull();
    expect(screen.queryByRole("button", { name: /Turn off/i })).toBeNull();
  });

  it("renders the enabled state with a Turn off button when 2FA is already on", async () => {
    vi.spyOn(apiModule.api, "totpStatus").mockResolvedValue({ enabled: true });
    render(<TotpSetupCard />);

    expect(await screen.findByRole("button", { name: /Turn off two-factor authentication/i }))
      .toBeInTheDocument();
    // And no Set up button when it's already on.
    expect(screen.queryByRole("button", { name: /Set up two-factor authentication/i })).toBeNull();
  });

  it("clicking Set up shows the secret and a 6-digit code input", async () => {
    vi.spyOn(apiModule.api, "totpStatus").mockResolvedValue({ enabled: false });
    vi.spyOn(apiModule.api, "totpSetup").mockResolvedValue({
      secret: "YNQBEGM77Y465EFSB5GN2RQQOSLUW7F5",
      otpAuthUri: "otpauth://totp/AIWA:admin@aiwa.com?secret=YNQBEGM77Y465EFSB5GN2RQQOSLUW7F5&issuer=AIWA"
    });
    render(<TotpSetupCard />);

    // DR-017: the current password is required first.
    const setUp = await screen.findByRole("button", { name: /Set up two-factor authentication/i });
    expect(setUp).toBeDisabled();
    fireEvent.change(screen.getByLabelText(/Your current password/i), { target: { value: "pw" } });
    fireEvent.click(setUp);
    expect(apiModule.api.totpSetup).toHaveBeenCalledWith("pw", "");

    // Secret is shown so the user can paste it into their authenticator.
    expect(await screen.findByText("YNQBEGM77Y465EFSB5GN2RQQOSLUW7F5")).toBeInTheDocument();
    // Code input appears, disabled Confirm button until 6 digits.
    const codeInput = screen.getByLabelText(/Code from your app/i);
    const confirmBtn = screen.getByRole("button", { name: /Confirm & enable/i });
    expect(confirmBtn).toBeDisabled();

    fireEvent.change(codeInput, { target: { value: "12" } });
    expect(confirmBtn).toBeDisabled();

    fireEvent.change(codeInput, { target: { value: "123456" } });
    expect(confirmBtn).not.toBeDisabled();
  });

  it("strips non-digits and caps the code at 6 (same guard as the login step)", async () => {
    vi.spyOn(apiModule.api, "totpStatus").mockResolvedValue({ enabled: false });
    vi.spyOn(apiModule.api, "totpSetup").mockResolvedValue({
      secret: "XXXX", otpAuthUri: "otpauth://x"
    });
    render(<TotpSetupCard />);
    fireEvent.change(await screen.findByLabelText(/Your current password/i), { target: { value: "pw" } });
    fireEvent.click(screen.getByRole("button", { name: /Set up two-factor authentication/i }));

    const codeInput = await screen.findByLabelText(/Code from your app/i);
    fireEvent.change(codeInput, { target: { value: "abc-12-def-34-ghi-56-789" } });
    // Digits only, capped at 6.
    expect(codeInput.value).toBe("123456");
  });

  it("Cancel during setup drops back to the pre-setup state without calling enable", async () => {
    vi.spyOn(apiModule.api, "totpStatus").mockResolvedValue({ enabled: false });
    vi.spyOn(apiModule.api, "totpSetup").mockResolvedValue({
      secret: "XXXX", otpAuthUri: "otpauth://x"
    });
    const enableSpy = vi.spyOn(apiModule.api, "totpEnable").mockResolvedValue({});
    render(<TotpSetupCard />);

    fireEvent.change(await screen.findByLabelText(/Your current password/i), { target: { value: "pw" } });
    fireEvent.click(screen.getByRole("button", { name: /Set up two-factor authentication/i }));
    await screen.findByLabelText(/Code from your app/i);

    fireEvent.click(screen.getByRole("button", { name: /^Cancel$/i }));

    // Back to the CTA, and enable was never called.
    expect(await screen.findByRole("button", { name: /Set up two-factor authentication/i }))
      .toBeInTheDocument();
    expect(enableSpy).not.toHaveBeenCalled();
  });

  it("confirming with a correct code calls enable and flips to the enabled state", async () => {
    vi.spyOn(apiModule.api, "totpStatus").mockResolvedValue({ enabled: false });
    vi.spyOn(apiModule.api, "totpSetup").mockResolvedValue({
      secret: "XXXX", otpAuthUri: "otpauth://x"
    });
    const enableSpy = vi.spyOn(apiModule.api, "totpEnable").mockResolvedValue({});
    render(<TotpSetupCard />);

    fireEvent.change(await screen.findByLabelText(/Your current password/i), { target: { value: "pw" } });
    fireEvent.click(screen.getByRole("button", { name: /Set up two-factor authentication/i }));
    const codeInput = await screen.findByLabelText(/Code from your app/i);
    fireEvent.change(codeInput, { target: { value: "550067" } });
    fireEvent.click(screen.getByRole("button", { name: /Confirm & enable/i }));

    await waitFor(() => expect(enableSpy).toHaveBeenCalledWith("550067"));
    // Card flips to enabled state — Turn off button appears.
    await waitFor(() =>
      expect(screen.getByRole("button", { name: /Turn off two-factor authentication/i }))
        .toBeInTheDocument()
    );
  });

  it("Copy button puts the secret on the clipboard (the whole reason users are on this screen)", async () => {
    vi.spyOn(apiModule.api, "totpStatus").mockResolvedValue({ enabled: false });
    vi.spyOn(apiModule.api, "totpSetup").mockResolvedValue({
      secret: "DY22MAYKEL4J5AP74W5CYV47VLXGQSMV", otpAuthUri: "otpauth://x"
    });
    const writeText = vi.fn().mockResolvedValue();
    Object.defineProperty(navigator, "clipboard", { value: { writeText }, configurable: true });

    render(<TotpSetupCard />);
    fireEvent.change(await screen.findByLabelText(/Your current password/i), { target: { value: "pw" } });
    fireEvent.click(screen.getByRole("button", { name: /Set up two-factor authentication/i }));
    await screen.findByText("DY22MAYKEL4J5AP74W5CYV47VLXGQSMV");

    fireEvent.click(screen.getByRole("button", { name: /^Copy$/i }));
    expect(writeText).toHaveBeenCalledWith("DY22MAYKEL4J5AP74W5CYV47VLXGQSMV");
  });

  it("shows an error message when the initial status fetch fails so the card doesn't stay stuck on Loading…", async () => {
    vi.spyOn(apiModule.api, "totpStatus").mockRejectedValue(new Error("boom"));
    render(<TotpSetupCard />);
    expect(await screen.findByText(/boom/i)).toBeInTheDocument();
    // No Loading… text left over.
    expect(screen.queryByText(/^Loading…$/)).toBeNull();
  });
});
