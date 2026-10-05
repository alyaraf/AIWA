import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, waitFor, fireEvent, within, act } from "@testing-library/react";
import { TermsEditorPanel, ConfirmHost, __setPermissionsForTest, __triggerTermsPublishForTest } from "../App.jsx";
import * as apiModule from "../api.js";

/**
 * AD-02: switching between Customer and Provider terms while a load is in flight must never publish one type's
 * text under the other type, whichever answer arrives first.
 */

const version = (type, text) => [{ id: 1, version: "1.0.0", type, active: true, contentEn: text, contentAr: "", changeNote: "" }];

function deferred() {
  let resolve;
  const promise = new Promise((res) => { resolve = res; });
  return { promise, resolve };
}

function mockLoads(loads) {
  vi.spyOn(apiModule.api, "termsVersions").mockImplementation((type) => loads[type]);
}

describe("<TermsEditorPanel> - AD-02 out-of-order loads", () => {
  beforeEach(() => {
    window.localStorage.setItem("aiwa_admin_session", "hint");
    __setPermissionsForTest(["SUPER_ADMIN"]);
  });

  it("a slow customer answer does not overwrite the provider draft", async () => {
    const customer = deferred();
    const provider = deferred();
    mockLoads({ CUSTOMER_TERMS: customer.promise, PROVIDER_TERMS: provider.promise });
    render(<TermsEditorPanel />);

    fireEvent.click(screen.getByRole("button", { name: "Provider terms" }));
    await act(async () => { provider.resolve(version("PROVIDER_TERMS", "PROVIDER TEXT")); });
    expect(await screen.findByLabelText("English text")).toHaveValue("PROVIDER TEXT");

    await act(async () => { customer.resolve(version("CUSTOMER_TERMS", "CUSTOMER TEXT")); }); // arrives last
    expect(screen.getByLabelText("English text")).toHaveValue("PROVIDER TEXT");
  });

  it("Publish is refused while the selected policy is still loading", async () => {
    const provider = deferred();
    mockLoads({ CUSTOMER_TERMS: Promise.resolve(version("CUSTOMER_TERMS", "CUSTOMER TEXT")), PROVIDER_TERMS: provider.promise });
    const publish = vi.spyOn(apiModule.api, "publishTerms").mockResolvedValue({});
    render(<><TermsEditorPanel /><ConfirmHost /></>);
    await screen.findByDisplayValue("CUSTOMER TEXT");

    fireEvent.click(screen.getByRole("button", { name: "Provider terms" })); // provider load still pending
    act(() => { __triggerTermsPublishForTest(); });

    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
    expect(publish).not.toHaveBeenCalled();
  });

  it("publishes the type and text on screen after the loads settle in the reversed order", async () => {
    const customer = deferred();
    const provider = deferred();
    mockLoads({ CUSTOMER_TERMS: customer.promise, PROVIDER_TERMS: provider.promise });
    const publish = vi.spyOn(apiModule.api, "publishTerms").mockResolvedValue({});
    render(<><TermsEditorPanel /><ConfirmHost /></>);

    fireEvent.click(screen.getByRole("button", { name: "Provider terms" }));
    await act(async () => { provider.resolve(version("PROVIDER_TERMS", "PROVIDER TEXT")); });
    await screen.findByDisplayValue("PROVIDER TEXT");
    await act(async () => { customer.resolve(version("CUSTOMER_TERMS", "CUSTOMER TEXT")); });

    act(() => { __triggerTermsPublishForTest(); });
    const dialog = await screen.findByRole("alertdialog");
    fireEvent.change(within(dialog).getByRole("textbox"), { target: { value: "what changed" } });
    fireEvent.click(within(dialog).getByRole("button", { name: /Publish/ }));

    await waitFor(() => expect(publish).toHaveBeenCalledTimes(1));
    const [, text, type] = publish.mock.calls[0];
    expect(type).toBe("PROVIDER_TERMS");
    expect(text).toBe("PROVIDER TEXT");
  });
});
