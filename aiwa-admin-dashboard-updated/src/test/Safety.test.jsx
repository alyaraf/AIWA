import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { Safety, __setPermissionsForTest } from "../App.jsx";
import * as apiModule from "../api.js";

/**
 * The SOS queue is how support hears about an emergency (the other party is
 * never told). Closing an alert must carry a note of what was done.
 */

const SOS = apiModule.normalizeSafety({
  id: 41, bookingId: 1182, bookingStatus: "IN_PROGRESS", homeService: true,
  address: "Street 9, Maadi", actorName: "Mariam Adel", actorRole: "CUSTOMER",
  customerName: "Mariam Adel", customerPhone: "+201001234567",
  providerName: "Layla Beauty", providerPhone: "+201112223334",
  latitude: 29.96, longitude: 31.25, notes: "Provider is refusing to leave",
  resolved: false, createdAt: new Date().toISOString()
});

describe("<Safety> — SOS queue", () => {
  beforeEach(() => {
    window.localStorage.setItem("aiwa_admin_access_token", "test-token");
    __setPermissionsForTest(["SUPPORT"]);
  });

  it("lists open alerts with both parties' phones and a map link", async () => {
    vi.spyOn(apiModule.api, "safetyQueue").mockResolvedValue([SOS]);
    render(<Safety />);
    expect(await screen.findByText(/Provider is refusing to leave/)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "+201001234567" })).toHaveAttribute("href", "tel:+201001234567");
    expect(screen.getByRole("link", { name: "+201112223334" })).toHaveAttribute("href", "tel:+201112223334");
    expect(screen.getByRole("link", { name: /Open map/ })).toHaveAttribute("href", expect.stringContaining("29.96,31.25"));
    expect(apiModule.api.safetyQueue).toHaveBeenCalledWith("OPEN");
  });

  it("will not close an alert without a note", async () => {
    vi.spyOn(apiModule.api, "safetyQueue").mockResolvedValue([SOS]);
    const resolveSpy = vi.spyOn(apiModule.api, "resolveSafety").mockResolvedValue({ ...SOS, resolved: true });
    render(<Safety />);
    fireEvent.click(await screen.findByRole("button", { name: /Close alert/ }));
    expect(resolveSpy).not.toHaveBeenCalled();
  });

  it("closes an alert with the note and drops it from the open list", async () => {
    // First load has the alert; the refresh after closing it (runAction) no longer does.
    vi.spyOn(apiModule.api, "safetyQueue").mockResolvedValueOnce([SOS]).mockResolvedValue([]);
    const resolveSpy = vi.spyOn(apiModule.api, "resolveSafety").mockResolvedValue({ ...SOS, resolved: true });
    render(<Safety />);
    fireEvent.change(await screen.findByPlaceholderText(/What was done/), { target: { value: "Called the customer; she is safe." } });
    fireEvent.click(screen.getByRole("button", { name: /Close alert/ }));
    await waitFor(() => expect(resolveSpy).toHaveBeenCalledWith(41, "Called the customer; she is safe."));
    await waitFor(() => expect(screen.queryByText(/Provider is refusing to leave/)).not.toBeInTheDocument());
  });

  it("switching to Resolved reloads with that status", async () => {
    const spy = vi.spyOn(apiModule.api, "safetyQueue").mockResolvedValue([]);
    render(<Safety />);
    await waitFor(() => expect(spy).toHaveBeenCalledWith("OPEN"));
    fireEvent.click(screen.getByRole("button", { name: "Resolved" }));
    await waitFor(() => expect(spy).toHaveBeenCalledWith("RESOLVED"));
  });

  it("view-only admins see the queue but no close controls", async () => {
    __setPermissionsForTest([]);
    vi.spyOn(apiModule.api, "safetyQueue").mockResolvedValue([SOS]);
    render(<Safety />);
    expect(await screen.findByText(/Provider is refusing to leave/)).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Close alert/ })).not.toBeInTheDocument();
  });
});

describe("api.js helpers for the 2026-09-29 backend fields", () => {
  it("mediaUrl puts public upload paths under the API base", () => {
    expect(apiModule.mediaUrl("/files/public/gallery/a.jpg")).toBe("http://api.test/api/files/public/gallery/a.jpg");
    expect(apiModule.mediaUrl("https://cdn.x/a.jpg")).toBe("https://cdn.x/a.jpg");
    expect(apiModule.mediaUrl(null)).toBeNull();
  });

  it("pctDelta compares with the previous window", () => {
    expect(apiModule.pctDelta(12, 10)).toBe("+20.0%");
    expect(apiModule.pctDelta(5, 10)).toBe("-50.0%");
    expect(apiModule.pctDelta(5, 0)).toBe("");
  });

  it("pageWindow keeps first, last and a 3-page window", async () => {
    const { pageWindow } = await import("../App.jsx");
    expect(pageWindow(1, 1)).toEqual([1]);
    expect(pageWindow(5, 12)).toEqual([1, "…", 4, 5, 6, "…", 12]);
    expect(pageWindow(2, 4)).toEqual([1, 2, 3, 4]);
  });
});
