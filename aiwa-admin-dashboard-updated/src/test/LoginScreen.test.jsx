import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, waitFor, fireEvent } from "@testing-library/react";
import { LoginScreen } from "../App.jsx";
import * as apiModule from "../api.js";

/**
 * Login is the only unauthenticated screen. It has two branches — a plain
 * password flow and the newer 2FA challenge flow — and either of them dropping
 * on the floor means nobody can sign in. Pin both paths.
 */

/** The form starts empty outside mock mode, so type credentials, then submit. */
function signIn() {
  fireEvent.change(screen.getByLabelText(/Email/), { target: { value: "admin@aiwa.com" } });
  fireEvent.change(screen.getByLabelText(/Password/), { target: { value: "secret-password" } });
  fireEvent.click(screen.getByRole("button", { name: /^Sign in$/i }));
}

describe("<LoginScreen>", () => {
  it("starts with empty credentials outside mock mode (no seeded account in the bundle)", () => {
    render(<LoginScreen onLogin={vi.fn()} />);
    expect(screen.getByLabelText(/Email/)).toHaveValue("");
    expect(screen.getByLabelText(/Password/)).toHaveValue("");
  });

  beforeEach(() => {
    apiModule.clearTokens();
    window.localStorage.clear();
  });

  it("calls onLogin with the user when a plain password login succeeds", async () => {
    vi.spyOn(apiModule.api, "login").mockResolvedValue({
      accessToken: "acc", refreshToken: "ref",
      user: { id: 1, fullName: "S. Mahmoud", role: "ADMIN", permissions: ["SUPER_ADMIN"] },
      mfaRequired: false
    });
    const onLogin = vi.fn();
    render(<LoginScreen onLogin={onLogin} />);

    signIn();

    await waitFor(() => expect(onLogin).toHaveBeenCalledTimes(1));
    expect(onLogin.mock.calls[0][0].user.fullName).toBe("S. Mahmoud");
    // The access token is kept in memory and a session hint is stored; no token reaches localStorage (F-05).
    expect(apiModule.getAccessToken()).toBe("acc");
  });

  it("shows a form error when the login call rejects, without dropping to the 2FA screen", async () => {
    vi.spyOn(apiModule.api, "login").mockRejectedValue(
      Object.assign(new Error("Invalid credentials"), { status: 401 })
    );
    const onLogin = vi.fn();
    render(<LoginScreen onLogin={onLogin} />);

    signIn();

    await waitFor(() =>
      expect(screen.getByText("Invalid credentials")).toBeInTheDocument()
    );
    expect(onLogin).not.toHaveBeenCalled();
    // Password step is still on screen — no accidental flip to the code step.
    expect(screen.queryByText(/Enter your code/i)).toBeNull();
  });

  it("switches to the 2FA code entry step when the backend says mfaRequired", async () => {
    vi.spyOn(apiModule.api, "login").mockResolvedValue({
      mfaRequired: true, mfaToken: "challenge-token"
    });
    const onLogin = vi.fn();
    render(<LoginScreen onLogin={onLogin} />);

    signIn();

    await waitFor(() =>
      expect(screen.getByText(/Enter your code/i)).toBeInTheDocument()
    );
    // No session yet — onLogin must not be called until the second step succeeds.
    expect(onLogin).not.toHaveBeenCalled();
    // And absolutely no tokens stored — the mfaToken is not a session token.
    expect(apiModule.getAccessToken()).toBeNull();
  });

  it("keeps the Verify button disabled until 6 digits are entered", async () => {
    vi.spyOn(apiModule.api, "login").mockResolvedValue({
      mfaRequired: true, mfaToken: "challenge-token"
    });
    render(<LoginScreen onLogin={vi.fn()} />);
    signIn();

    const codeInput = await screen.findByLabelText(/Authentication code/i);
    const verifyBtn = screen.getByRole("button", { name: /^Verify$/i });
    expect(verifyBtn).toBeDisabled();

    fireEvent.change(codeInput, { target: { value: "123" } });
    expect(verifyBtn).toBeDisabled();

    fireEvent.change(codeInput, { target: { value: "123456" } });
    expect(verifyBtn).not.toBeDisabled();
  });

  it("strips non-digits and caps at 6 as the user types (prevents copy-paste of a full JWT etc.)", async () => {
    vi.spyOn(apiModule.api, "login").mockResolvedValue({
      mfaRequired: true, mfaToken: "challenge-token"
    });
    render(<LoginScreen onLogin={vi.fn()} />);
    signIn();

    const codeInput = await screen.findByLabelText(/Authentication code/i);
    fireEvent.change(codeInput, { target: { value: "12a3-b4c56789" } });
    // Digits only, max 6.
    expect(codeInput.value).toBe("123456");
  });

  it("completes login and calls onLogin after a successful verify", async () => {
    vi.spyOn(apiModule.api, "login").mockResolvedValue({
      mfaRequired: true, mfaToken: "challenge-token"
    });
    vi.spyOn(apiModule.api, "verifyMfa").mockResolvedValue({
      accessToken: "final-acc", refreshToken: "final-ref",
      user: { id: 1, fullName: "S. Mahmoud", role: "ADMIN", permissions: ["SUPER_ADMIN"] }
    });
    const onLogin = vi.fn();
    render(<LoginScreen onLogin={onLogin} />);

    signIn();
    const codeInput = await screen.findByLabelText(/Authentication code/i);
    fireEvent.change(codeInput, { target: { value: "123456" } });
    fireEvent.click(screen.getByRole("button", { name: /^Verify$/i }));

    await waitFor(() => expect(onLogin).toHaveBeenCalledTimes(1));
    expect(apiModule.api.verifyMfa).toHaveBeenCalledWith("challenge-token", "123456");
    expect(apiModule.getAccessToken()).toBe("final-acc");
  });

  it("Back-to-sign-in from the 2FA step clears the challenge and returns to the password form", async () => {
    vi.spyOn(apiModule.api, "login").mockResolvedValue({
      mfaRequired: true, mfaToken: "challenge-token"
    });
    render(<LoginScreen onLogin={vi.fn()} />);

    signIn();
    await screen.findByLabelText(/Authentication code/i);

    fireEvent.click(screen.getByRole("button", { name: /Back to sign in/i }));
    // Back on the password form.
    expect(await screen.findByLabelText(/Password/i)).toBeInTheDocument();
    // And the code step is gone.
    expect(screen.queryByLabelText(/Authentication code/i)).toBeNull();
  });

  it("shows the verify error message when the code is wrong", async () => {
    vi.spyOn(apiModule.api, "login").mockResolvedValue({
      mfaRequired: true, mfaToken: "challenge-token"
    });
    vi.spyOn(apiModule.api, "verifyMfa").mockRejectedValue(
      new Error("Incorrect or expired authentication code")
    );
    render(<LoginScreen onLogin={vi.fn()} />);

    signIn();
    const codeInput = await screen.findByLabelText(/Authentication code/i);
    fireEvent.change(codeInput, { target: { value: "000000" } });
    fireEvent.click(screen.getByRole("button", { name: /^Verify$/i }));

    await waitFor(() =>
      expect(screen.getByText(/Incorrect or expired authentication code/i)).toBeInTheDocument()
    );
    // Still on the 2FA screen — user gets another try.
    expect(screen.getByLabelText(/Authentication code/i)).toBeInTheDocument();
  });
});
