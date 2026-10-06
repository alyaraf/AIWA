import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { render, screen, fireEvent, act, waitFor } from "@testing-library/react";
import { Complaints, Flags, Reviews, __setPermissionsForTest } from "../App.jsx";
import * as mod from "../api.js";

/**
 * R4 follow-up: the Complaints, Flags and Reviews queues are paged, filtered and searched by the SERVER. The count and the
 * page numbers are the queue's real ones, a search is one request after a pause, and an older answer never replaces a newer one.
 */

const complaint = (id, text = "late arrival") => ({ id, customer: `Customer ${id}`, provider: "Studio", subject: text, when: "today", status: "OPEN", flagged: false, priority: "Medium", category: "BOOKING", description: text, adminNotes: "", bookingId: null });
const pageOf = (rows, total, totalPages) => ({ rows, total, totalPages });
const tick = async (ms) => { await act(async () => { await vi.advanceTimersByTimeAsync(ms); }); };

describe("api.requestPage", () => {
  beforeEach(() => { vi.restoreAllMocks(); mod.setTokens({ accessToken: "A" }); });

  it("sends status, search text, page and size to the server and returns the server's own totals", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue({
      ok: true, status: 200,
      text: async () => JSON.stringify({ data: { content: [{ id: 5, reporterName: "Mona", description: "rude", status: "OPEN", createdAt: "2026-10-01T10:00:00" }], totalElements: 134, totalPages: 14 } })
    });
    const result = await mod.api.complaintsPage({ status: "OPEN", query: "  rude  ", page: 2, size: 10 });
    const url = new URL(String(fetchSpy.mock.calls[0][0]));
    expect(url.pathname).toBe("/api/admin/complaints");
    expect(Object.fromEntries(url.searchParams)).toEqual({ status: "OPEN", query: "rude", page: "2", size: "10" });
    expect(result.total).toBe(134);
    expect(result.totalPages).toBe(14);
    expect(result.rows).toHaveLength(1);
    expect(result.rows[0].customer).toBe("Mona");
  });

  it("omits empty filters and never sends 'ALL'-style placeholders as a query", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue({ ok: true, status: 200, text: async () => JSON.stringify({ data: { content: [], totalElements: 0, totalPages: 0 } }) });
    const result = await mod.api.reviewsPage({ query: "", maxRating: 2, page: 0, size: 10 });
    const url = new URL(String(fetchSpy.mock.calls[0][0]));
    expect(Object.fromEntries(url.searchParams)).toEqual({ maxRating: "2", page: "0", size: "10" });
    expect(result).toEqual({ rows: [], total: 0, totalPages: 1 });
  });

  it("a server error surfaces as an error, not as an empty list", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue({ ok: false, status: 503, text: async () => JSON.stringify({ message: "down" }) });
    await expect(mod.api.flagsPage({ page: 0, size: 10 })).rejects.toMatchObject({ status: 503 });
  });
});

describe("<Complaints> - server paging and search", () => {
  let spy;
  beforeEach(() => {
    vi.useFakeTimers();
    window.localStorage.setItem("aiwa_admin_session", "hint");
    __setPermissionsForTest(["SUPPORT"]);
    spy = vi.spyOn(mod.api, "complaintsPage").mockResolvedValue(pageOf(Array.from({ length: 10 }, (_, i) => complaint(i + 1)), 134, 14));
  });
  afterEach(() => vi.useRealTimers());

  it("shows the real total, asks the server for page 0 and moves with the server's page numbers", async () => {
    render(<Complaints />);
    await tick(0);
    expect(spy).toHaveBeenLastCalledWith({ status: undefined, query: "", page: 0, size: 10 });
    expect(screen.getByText("1–10 of 134")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "All (134)" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Page 14" })).toBeInTheDocument(); // 14 pages, not what a cap happened to collect
    fireEvent.click(screen.getByRole("button", { name: "Page 2" }));
    await tick(0);
    expect(spy).toHaveBeenLastCalledWith({ status: undefined, query: "", page: 1, size: 10 });
  });

  it("a search is sent once after the typing pauses, as the server's query, and goes back to page 1", async () => {
    render(<Complaints />);
    await tick(0);
    fireEvent.click(screen.getByRole("button", { name: "Page 2" }));
    await tick(0);
    expect(spy).toHaveBeenLastCalledWith(expect.objectContaining({ page: 1 }));
    const calls = spy.mock.calls.length;
    const box = screen.getByPlaceholderText(/Search customer/);
    fireEvent.change(box, { target: { value: "r" } });
    fireEvent.change(box, { target: { value: "ru" } });
    fireEvent.change(box, { target: { value: "rude" } });
    await tick(100);
    expect(spy.mock.calls.length).toBe(calls); // nothing sent while typing
    await tick(300);
    expect(spy).toHaveBeenLastCalledWith({ status: undefined, query: "rude", page: 0, size: 10 });
    expect(spy.mock.calls.length).toBe(calls + 1);
  });

  it("the status chip is a server filter", async () => {
    render(<Complaints />);
    await tick(0);
    fireEvent.click(screen.getByRole("button", { name: "Open" }));
    await tick(0);
    expect(spy).toHaveBeenLastCalledWith({ status: "OPEN", query: "", page: 0, size: 10 });
  });

  it("an older, slower answer never replaces the newer one", async () => {
    let finishOld;
    spy.mockReset();
    spy.mockReturnValueOnce(new Promise((resolve) => { finishOld = resolve; }));
    render(<Complaints />);
    await tick(0);
    spy.mockResolvedValue(pageOf([complaint(99, "NEW ROW")], 1, 1));
    fireEvent.click(screen.getByRole("button", { name: "Open" }));
    await tick(0);
    expect(screen.getByText(/NEW ROW/)).toBeInTheDocument();
    await act(async () => { finishOld(pageOf([complaint(1, "OLD ROW")], 500, 50)); await vi.advanceTimersByTimeAsync(0); });
    expect(screen.queryByText(/OLD ROW/)).not.toBeInTheDocument();
    expect(screen.getByText(/NEW ROW/)).toBeInTheDocument();
    expect(screen.getByText("1–1 of 1")).toBeInTheDocument();
  });

  it("a failed page says so with a retry instead of showing an empty queue", async () => {
    spy.mockReset();
    spy.mockRejectedValueOnce(Object.assign(new Error("Service Unavailable"), { status: 503 }));
    render(<Complaints />);
    await tick(0);
    expect(screen.getByText(/Could not load complaints: Service Unavailable/)).toBeInTheDocument();
    expect(screen.queryByText("No complaints")).not.toBeInTheDocument();
    spy.mockResolvedValue(pageOf([complaint(7, "RECOVERED")], 1, 1));
    fireEvent.click(screen.getByRole("button", { name: /Retry|Try again/ }));
    await tick(0);
    expect(screen.getByText(/RECOVERED/)).toBeInTheDocument();
  });
});

describe("<Flags> and <Reviews> - server paging", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    window.localStorage.setItem("aiwa_admin_session", "hint");
    __setPermissionsForTest(["SUPPORT"]);
  });
  afterEach(() => vi.useRealTimers());

  it("Flags pages and searches on the server", async () => {
    const spy = vi.spyOn(mod.api, "flagsPage").mockResolvedValue(pageOf([], 0, 1));
    render(<Flags />);
    await tick(0);
    expect(spy).toHaveBeenLastCalledWith({ query: "", page: 0, size: 10 });
    fireEvent.change(screen.getByPlaceholderText(/Search name/), { target: { value: "unsafe" } });
    await tick(400);
    expect(spy).toHaveBeenLastCalledWith({ query: "unsafe", page: 0, size: 10 });
  });

  it("Reviews: the reported queue and 'All' / 'Low rating' are server pages (the latter with a rating filter)", async () => {
    // R5 follow-up: the reported queue is a server page too (see Queues.paged6.test.jsx)
    vi.spyOn(mod.api, "reviewReportsPage").mockResolvedValue(pageOf([], 0, 1));
    const page = vi.spyOn(mod.api, "reviewsPage").mockResolvedValue(pageOf([], 57, 6));
    render(<Reviews />);
    await tick(0);
    expect(page).not.toHaveBeenCalled(); // Reported is the first view
    fireEvent.click(screen.getByRole("button", { name: "Low rating" }));
    await tick(0);
    expect(page).toHaveBeenLastCalledWith({ query: "", maxRating: 2, page: 0, size: 10 });
    fireEvent.click(screen.getByRole("button", { name: "All" }));
    await tick(0);
    expect(page).toHaveBeenLastCalledWith({ query: "", maxRating: undefined, page: 0, size: 10 });
  });
});
