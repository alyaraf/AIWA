import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { VerificationDetail, __setPermissionsForTest } from "../App.jsx";
import * as apiModule from "../api.js";

/**
 * M-3 (audit 2026-10-03): the backend serves identity documents to Support only,
 * so the panel doesn't try to load them for other admins and says why.
 */

const PROVIDER = {
  id: 11, name: "Nadia Studio", status: "PENDING",
  documentPaths: {
    nationalIdFrontPath: "uploads/private/11/front.jpg",
    nationalIdBackPath: "uploads/private/11/back.jpg",
    selfiePath: "uploads/private/11/selfie.jpg"
  }
};

const noop = () => {};

function renderDetail() {
  return render(<VerificationDetail provider={PROVIDER} onBack={noop} onApprove={noop} onReject={noop}
    onRequestInfo={noop} onSuspend={noop} onReactivate={noop} />);
}

describe("<VerificationDetail> identity documents", () => {
  let docUrl;
  beforeEach(() => {
    docUrl = vi.spyOn(apiModule.api, "verificationDocUrl").mockResolvedValue("blob:doc");
  });
  afterEach(() => vi.restoreAllMocks());

  it("a Finance-only admin sees a Support-only note and no document is requested", async () => {
    __setPermissionsForTest(["FINANCE"]);
    renderDetail();
    expect(await screen.findByText(/national ID and selfie images needs the Support permission/i)).toBeInTheDocument();
    expect(docUrl).not.toHaveBeenCalled();
  });

  it("a Support admin loads all three documents", async () => {
    __setPermissionsForTest(["SUPPORT"]);
    renderDetail();
    await waitFor(() => expect(docUrl).toHaveBeenCalledTimes(3));
    expect(screen.queryByText(/national ID and selfie images needs the Support permission/i)).not.toBeInTheDocument();
  });
});
