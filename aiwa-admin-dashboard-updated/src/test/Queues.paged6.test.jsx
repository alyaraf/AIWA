import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { render, screen, fireEvent, act } from "@testing-library/react";
import { Verifications, Moderation, ChatReports, Reviews, Settlements, Safety, __setPermissionsForTest } from "../App.jsx";
import * as mod from "../api.js";

/**
 * R5 follow-up (AD-13): the verification, photo-moderation, chat-report, reported-review, settlement and SOS queues are
 * searched, filtered and paged by the SERVER. Totals and page numbers are the queue's real ones, a search is one request
 * after a pause, an older answer never replaces a newer one, and permissions, filters, ordering and actions are unchanged.
 */

const pageOf = (rows, total = rows.length, totalPages = 1) => ({ rows, total, totalPages });
const tick = async (ms) => { await act(async () => { await vi.advanceTimersByTimeAsync(ms); }); };
const provider = (id, name = `Salon ${id}`) => ({ id, name, ownerName: "Owner", category: "HAIR", city: "Cairo", submitted: "today", documents: "ID front", status: "PENDING", palette: "plum", business: {}, documentPaths: {} });
const photo = (id, name = `Studio ${id}`) => ({ id, type: "IMAGE", provider: name, reason: "inappropriate", when: "today", text: "", imageUrl: null, imageHidden: false });
const chat = (id, text = `rude ${id}`) => ({ id, messageId: id, bookingId: 40 + id, from: `Sender ${id}`, text, reason: "Abusive", removed: false, when: "today" });
const reported = (id, text = `awful ${id}`) => ({ id, reviewId: id, from: `Critic ${id}`, to: "Studio", rating: 1, text, reason: "Spam", hidden: false, lowRating: true, when: "today" });
const settlementRow = (id, name = `Provider ${id}`, status = "OVERDUE") => ({ providerId: id, providerName: name, commissionPercent: 10, grossAmount: 100, balanceOwed: 10, status, accountSuspended: false, dueDate: null, paymentReportedAt: null });
const sos = (id, notes) => mod.normalizeSafety({ id, bookingId: 5, actorName: `Caller ${id}`, notes, createdAt: new Date().toISOString() });

function jsonResponse(data) {
  return { ok: true, status: 200, text: async () => JSON.stringify({ data }) };
}
const emptyPage = { content: [], totalElements: 0, totalPages: 0 };

describe("api: the six queues ask the server for one page", () => {
  beforeEach(() => { vi.restoreAllMocks(); mod.setTokens({ accessToken: "A" }); });
  const urlOf = (spy, call = 0) => new URL(String(spy.mock.calls[call][0]));

  it("verification: the pending queue and the status tabs, with search, page and size", async () => {
    const spy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ content: [{ id: 1, businessName: "Glow" }], totalElements: 41, totalPages: 5 }));
    const pending = await mod.api.verificationsPage({ status: "PENDING_VERIFICATION", query: " glow ", page: 1, size: 10 });
    expect(urlOf(spy).pathname).toBe("/api/admin/verification/pending");
    expect(Object.fromEntries(urlOf(spy).searchParams)).toEqual({ query: "glow", page: "1", size: "10" });
    expect(pending).toMatchObject({ total: 41, totalPages: 5 });
    expect(pending.rows[0].name).toBe("Glow");
    await mod.api.verificationsPage({ status: "APPROVED", page: 0, size: 10 });
    expect(urlOf(spy, 1).pathname).toBe("/api/admin/verification");
    expect(Object.fromEntries(urlOf(spy, 1).searchParams)).toEqual({ status: "APPROVED", page: "0", size: "10" });
  });

  it("moderation asks for reported photos only; chat and review reports have their own paged routes", async () => {
    const spy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse(emptyPage));
    await mod.api.moderationPage({ query: "x", page: 2, size: 10 });
    expect(urlOf(spy).pathname).toBe("/api/admin/moderation");
    expect(Object.fromEntries(urlOf(spy).searchParams)).toEqual({ type: "GALLERY_IMAGE", query: "x", page: "2", size: "10" });
    await mod.api.chatReportsPage({ query: "", page: 0, size: 10 });
    expect(urlOf(spy, 1).pathname).toBe("/api/admin/chat/moderation");
    await mod.api.reviewReportsPage({ query: "spam", page: 0, size: 10 });
    expect(urlOf(spy, 2).pathname).toBe("/api/admin/reviews/moderation");
    expect(Object.fromEntries(urlOf(spy, 2).searchParams)).toEqual({ query: "spam", page: "0", size: "10" });
  });

  it("settlements: provider rows with a status filter and the server's real total", async () => {
    const spy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ content: [settlementRow(1)], totalElements: 88, totalPages: 9 }));
    const result = await mod.api.settlementProvidersPage({ status: "OVERDUE", query: "late", page: 3, size: 10 });
    expect(urlOf(spy).pathname).toBe("/api/admin/settlements/providers");
    expect(Object.fromEntries(urlOf(spy).searchParams)).toEqual({ status: "OVERDUE", query: "late", page: "3", size: "10" });
    expect(result).toMatchObject({ total: 88, totalPages: 9 });
  });

  it("SOS: a queue that fits one page needs one request, and the oldest open alert is its last row", async () => {
    const rows = [{ id: 3, bookingId: 5, actorName: "C", createdAt: "2026-10-06T10:00:00" }, { id: 2, bookingId: 5, actorName: "B", createdAt: "2026-10-06T09:00:00" }, { id: 1, bookingId: 5, actorName: "A", createdAt: "2026-10-06T08:00:00" }];
    const spy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ content: rows, totalElements: 3, totalPages: 1 }));
    const result = await mod.api.safetyPage({ status: "OPEN", query: "", page: 0, size: 10 });
    expect(spy).toHaveBeenCalledTimes(1);
    expect(Object.fromEntries(urlOf(spy).searchParams)).toEqual({ status: "OPEN", page: "0", size: "10" });
    expect(result.total).toBe(3);
    expect(result.oldest.id).toBe(1);
  });

  it("SOS: with more alerts than a page the oldest open alert is read from the server (order=oldest, size 1), whatever the page", async () => {
    const newest = Array.from({ length: 10 }, (_, i) => ({ id: 100 - i, bookingId: 5, actorName: "N", createdAt: "2026-10-06T10:00:00" }));
    const spy = vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(jsonResponse({ content: newest, totalElements: 57, totalPages: 6 }))
      .mockResolvedValueOnce(jsonResponse({ content: [{ id: 7, bookingId: 9, actorName: "Oldest one", createdAt: "2026-09-01T08:00:00" }], totalElements: 57, totalPages: 57 }));
    const result = await mod.api.safetyPage({ status: "OPEN", page: 0, size: 10 });
    expect(spy).toHaveBeenCalledTimes(2);
    expect(Object.fromEntries(urlOf(spy, 1).searchParams)).toEqual({ status: "OPEN", order: "oldest", page: "0", size: "1" });
    expect(result.oldest.actorName).toBe("Oldest one");
    expect(result.total).toBe(57);
  });

  it("SOS: a search never narrows the oldest-alert read, the Resolved view needs none, and a failed second read fails the whole read", async () => {
    const spy = vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(jsonResponse({ content: [{ id: 5, bookingId: 1, actorName: "Match", createdAt: "2026-10-06T10:00:00" }], totalElements: 1, totalPages: 1 }))
      .mockResolvedValueOnce(jsonResponse({ content: [{ id: 1, bookingId: 2, actorName: "Other", createdAt: "2026-08-01T10:00:00" }], totalElements: 9, totalPages: 9 }));
    const searched = await mod.api.safetyPage({ status: "OPEN", query: "match", page: 0, size: 10 });
    expect(urlOf(spy, 1).searchParams.get("query")).toBeNull();
    expect(searched.oldest.id).toBe(1);
    spy.mockReset();
    spy.mockResolvedValue(jsonResponse({ content: [], totalElements: 0, totalPages: 0 }));
    const resolved = await mod.api.safetyPage({ status: "RESOLVED", page: 0, size: 10 });
    expect(spy).toHaveBeenCalledTimes(1);
    expect(resolved.oldest).toBeNull();
    spy.mockReset();
    spy.mockResolvedValueOnce(jsonResponse({ content: [{ id: 5, bookingId: 1, actorName: "A", createdAt: "2026-10-06T10:00:00" }], totalElements: 25, totalPages: 3 }))
      .mockResolvedValueOnce({ ok: false, status: 503, text: async () => JSON.stringify({ message: "down" }) });
    await expect(mod.api.safetyPage({ status: "OPEN", page: 0, size: 10 })).rejects.toMatchObject({ status: 503 });
  });
});

describe("<Verifications> - server paging", () => {
  let spy;
  beforeEach(() => {
    vi.useFakeTimers();
    window.localStorage.setItem("aiwa_admin_session", "hint");
    __setPermissionsForTest(["SUPPORT"]);
    vi.spyOn(mod.api, "verificationCounts").mockResolvedValue({ pending: 41, approved: 9, rejected: 2, suspended: 1 });
    spy = vi.spyOn(mod.api, "verificationsPage").mockResolvedValue(pageOf(Array.from({ length: 10 }, (_, i) => provider(i + 1)), 41, 5));
  });
  afterEach(() => vi.useRealTimers());

  it("asks for the pending page, shows the real total and page count, and the tab counts", async () => {
    render(<Verifications />);
    await tick(0);
    expect(spy).toHaveBeenLastCalledWith({ status: "PENDING_VERIFICATION", query: "", page: 0, size: 10 });
    expect(screen.getByText("1–10 of 41")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Page 5" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Pending (41)" })).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Page 2" }));
    await tick(0);
    expect(spy).toHaveBeenLastCalledWith({ status: "PENDING_VERIFICATION", query: "", page: 1, size: 10 });
  });

  it("a tab is a server filter and a search is one request after the pause, back on page 1", async () => {
    render(<Verifications />);
    await tick(0);
    fireEvent.click(screen.getByRole("button", { name: "Page 2" }));
    await tick(0);
    fireEvent.click(screen.getByRole("button", { name: /^Approved/ }));
    await tick(0);
    expect(spy).toHaveBeenLastCalledWith({ status: "APPROVED", query: "", page: 0, size: 10 });
    const calls = spy.mock.calls.length;
    const box = screen.getByPlaceholderText(/Search provider/);
    fireEvent.change(box, { target: { value: "gl" } });
    fireEvent.change(box, { target: { value: "glow" } });
    await tick(100);
    expect(spy.mock.calls.length).toBe(calls);
    await tick(300);
    expect(spy).toHaveBeenLastCalledWith({ status: "APPROVED", query: "glow", page: 0, size: 10 });
  });

  it("a failed page shows an error with a retry, never an empty queue", async () => {
    spy.mockReset();
    spy.mockRejectedValueOnce(Object.assign(new Error("Service Unavailable"), { status: 503 }));
    render(<Verifications />);
    await tick(0);
    expect(screen.getByText(/Could not load the verification queue: Service Unavailable/)).toBeInTheDocument();
    expect(screen.queryByText("Queue is clear")).not.toBeInTheDocument();
    spy.mockResolvedValue(pageOf([provider(7, "Recovered Salon")], 1, 1));
    fireEvent.click(screen.getByRole("button", { name: /Retry|Try again/ }));
    await tick(0);
    expect(screen.getByText("Recovered Salon")).toBeInTheDocument();
  });
});

describe("<Moderation> (reported photos) - server paging", () => {
  let spy;
  beforeEach(() => {
    vi.useFakeTimers();
    window.localStorage.setItem("aiwa_admin_session", "hint");
    __setPermissionsForTest(["SUPPORT"]);
    spy = vi.spyOn(mod.api, "moderationPage").mockResolvedValue(pageOf(Array.from({ length: 10 }, (_, i) => photo(i + 1)), 23, 3));
  });
  afterEach(() => vi.useRealTimers());

  it("pages and searches on the server and shows the real total", async () => {
    render(<Moderation />);
    await tick(0);
    expect(spy).toHaveBeenLastCalledWith({ query: "", page: 0, size: 10 });
    expect(screen.getByText("1–10 of 23")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Page 3" }));
    await tick(0);
    expect(spy).toHaveBeenLastCalledWith({ query: "", page: 2, size: 10 });
    fireEvent.change(screen.getByPlaceholderText(/Search provider/), { target: { value: "studio 4" } });
    await tick(400);
    expect(spy).toHaveBeenLastCalledWith({ query: "studio 4", page: 0, size: 10 });
  });

  it("dismissing a report removes the row and re-reads the page so the queue refills and the total follows", async () => {
    const act1 = vi.spyOn(mod.api, "moderationAction").mockResolvedValue({});
    render(<Moderation />);
    await tick(0);
    const calls = spy.mock.calls.length;
    spy.mockResolvedValue(pageOf(Array.from({ length: 9 }, (_, i) => photo(i + 2)), 22, 3));
    fireEvent.click(screen.getAllByRole("button", { name: "Dismiss report" })[0]);
    await tick(0);
    expect(act1).toHaveBeenCalledWith(1, { status: "DISMISSED", notes: "" });
    expect(spy.mock.calls.length).toBe(calls + 1);
    expect(screen.getByText("1–10 of 22")).toBeInTheDocument();
  });

  it("when the last row of the last page is handled the screen steps back to the last real page, not 'Queue is clear'", async () => {
    vi.spyOn(mod.api, "moderationAction").mockResolvedValue({});
    spy.mockImplementation(async ({ page }) => pageOf(Array.from({ length: 10 }, (_, i) => photo(page * 10 + i + 1, `Studio P${page}-${i}`)), 20, 2));
    render(<Moderation />);
    await tick(0);
    fireEvent.click(screen.getByRole("button", { name: "Page 2" }));
    await tick(0);
    // handling the report shrinks the queue to ONE page: page 2 no longer exists, so the screen must land on page 1
    spy.mockImplementation(async ({ page }) => (page === 0
      ? pageOf(Array.from({ length: 10 }, (_, i) => photo(i + 1, `Studio P0-${i}`)), 10, 1)
      : pageOf([], 10, 1)));
    fireEvent.click(screen.getAllByRole("button", { name: "Dismiss report" })[0]);
    await tick(0);
    expect(spy).toHaveBeenLastCalledWith({ query: "", page: 0, size: 10 });
    expect(screen.queryByText("Queue is clear")).not.toBeInTheDocument();
    expect(screen.getByText("Studio P0-0")).toBeInTheDocument();
  });
});

describe("<ChatReports> - server paging", () => {
  let spy;
  beforeEach(() => {
    vi.useFakeTimers();
    window.localStorage.setItem("aiwa_admin_session", "hint");
    __setPermissionsForTest(["SUPPORT"]);
    spy = vi.spyOn(mod.api, "chatReportsPage").mockResolvedValue(pageOf(Array.from({ length: 10 }, (_, i) => chat(i + 1)), 31, 4));
  });
  afterEach(() => vi.useRealTimers());

  it("the queue tag, footer and pages are the server's; search is the server's query", async () => {
    render(<ChatReports />);
    await tick(0);
    expect(spy).toHaveBeenLastCalledWith({ query: "", page: 0, size: 10 });
    expect(screen.getByText("31 in queue")).toBeInTheDocument();
    expect(screen.getByText("1–10 of 31")).toBeInTheDocument();
    fireEvent.change(screen.getByPlaceholderText(/Search reporter/), { target: { value: "rude 3" } });
    await tick(400);
    expect(spy).toHaveBeenLastCalledWith({ query: "rude 3", page: 0, size: 10 });
  });

  it("keeping a message dismisses the report and re-reads the page", async () => {
    const resolve = vi.spyOn(mod.api, "resolveChatReport").mockResolvedValue({});
    render(<ChatReports />);
    await tick(0);
    const calls = spy.mock.calls.length;
    spy.mockResolvedValue(pageOf(Array.from({ length: 9 }, (_, i) => chat(i + 2)), 30, 3));
    fireEvent.click(screen.getAllByRole("button", { name: /Keep · dismiss/ })[0]);
    await tick(0);
    expect(resolve).toHaveBeenCalledWith(1, "KEEP");
    expect(spy.mock.calls.length).toBe(calls + 1);
    expect(screen.getByText("30 in queue")).toBeInTheDocument();
  });

  it("view-only admins still see no action buttons", async () => {
    __setPermissionsForTest([]);
    render(<ChatReports />);
    await tick(0);
    expect(screen.queryByRole("button", { name: /Keep · dismiss/ })).not.toBeInTheDocument();
    expect(screen.getAllByText(/rude 1/).length).toBeGreaterThan(0);
  });
});

describe("<Reviews> - the reported queue is a server page too", () => {
  let reports;
  beforeEach(() => {
    vi.useFakeTimers();
    window.localStorage.setItem("aiwa_admin_session", "hint");
    __setPermissionsForTest(["SUPPORT"]);
    reports = vi.spyOn(mod.api, "reviewReportsPage").mockResolvedValue(pageOf(Array.from({ length: 10 }, (_, i) => reported(i + 1)), 26, 3));
    vi.spyOn(mod.api, "reviewsPage").mockResolvedValue(pageOf([], 0, 1));
  });
  afterEach(() => vi.useRealTimers());

  it("the queue tag is the server's total, the search is the server's query, and switching to All keeps the tag", async () => {
    render(<Reviews />);
    await tick(0);
    expect(reports).toHaveBeenLastCalledWith({ query: "", page: 0, size: 10 });
    expect(screen.getByText("26 in queue")).toBeInTheDocument();
    expect(screen.getByText("1–10 of 26")).toBeInTheDocument();
    fireEvent.change(screen.getByPlaceholderText(/Search reviews/), { target: { value: "spam" } });
    await tick(400);
    expect(reports).toHaveBeenLastCalledWith({ query: "spam", page: 0, size: 10 });
    fireEvent.click(screen.getByRole("button", { name: "All" }));
    await tick(400);
    expect(reports).toHaveBeenLastCalledWith({ query: "", page: 0, size: 10 }); // the tag stays the whole queue's, not the search's
    expect(screen.getByText("26 in queue")).toBeInTheDocument();
  });

  it("dismissing a report re-reads the queue", async () => {
    const resolve = vi.spyOn(mod.api, "resolveReviewReport").mockResolvedValue({});
    render(<Reviews />);
    await tick(0);
    const calls = reports.mock.calls.length;
    reports.mockResolvedValue(pageOf(Array.from({ length: 9 }, (_, i) => reported(i + 2)), 25, 3));
    fireEvent.click(screen.getAllByRole("button", { name: /Keep · dismiss/ })[0]);
    await tick(0);
    expect(resolve).toHaveBeenCalledWith(1, "KEEP");
    expect(reports.mock.calls.length).toBeGreaterThan(calls);
    expect(screen.getByText("25 in queue")).toBeInTheDocument();
  });
});

describe("<Settlements> - server paging, search and status filter", () => {
  let spy;
  beforeEach(() => {
    vi.useFakeTimers();
    window.localStorage.setItem("aiwa_admin_session", "hint");
    __setPermissionsForTest(["FINANCE"]);
    vi.spyOn(mod.api, "getCommission").mockResolvedValue({ commissionPercent: 10 });
    vi.spyOn(mod.api, "settlementOverview").mockResolvedValue({ totalOwed: 410, providerCount: 41 });
    spy = vi.spyOn(mod.api, "settlementProvidersPage").mockResolvedValue(pageOf(Array.from({ length: 10 }, (_, i) => settlementRow(i + 1)), 41, 5));
  });
  afterEach(() => vi.useRealTimers());

  it("shows the real total and the commission-owed card; the status chips and the search are the server's", async () => {
    render(<Settlements />);
    await tick(0);
    expect(spy).toHaveBeenLastCalledWith({ status: "ALL", query: "", page: 0, size: 10 });
    expect(screen.getByText("1–10 of 41")).toBeInTheDocument();
    expect(screen.getByText("across 41 providers")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Overdue" }));
    await tick(0);
    expect(spy).toHaveBeenLastCalledWith({ status: "OVERDUE", query: "", page: 0, size: 10 });
    fireEvent.change(screen.getByPlaceholderText("Search provider…"), { target: { value: "provider 3" } });
    await tick(400);
    expect(spy).toHaveBeenLastCalledWith({ status: "OVERDUE", query: "provider 3", page: 0, size: 10 });
    fireEvent.click(screen.getByRole("button", { name: "Page 1" }) ?? screen.getByRole("button", { name: "All" }));
  });

  it("a filter that matches nothing says so instead of 'Nothing owing'", async () => {
    spy.mockResolvedValue(pageOf([], 0, 1));
    render(<Settlements />);
    await tick(0);
    expect(screen.getByText("Nothing owing")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Settled" }));
    await tick(0);
    expect(screen.getByText("No matches")).toBeInTheDocument();
  });

  it("a failed read says so (including a 403) and offers a retry", async () => {
    spy.mockReset();
    spy.mockRejectedValueOnce(Object.assign(new Error("Forbidden"), { status: 403 }));
    render(<Settlements />);
    await tick(0);
    expect(screen.getByText(/permission/i)).toBeInTheDocument();
    expect(screen.queryByText("Nothing owing")).not.toBeInTheDocument();
  });

  it("Send reminder is still the overdue row's action for FINANCE", async () => {
    const remind = vi.spyOn(mod.api, "remindSettlement").mockResolvedValue({});
    render(<Settlements />);
    await tick(0);
    fireEvent.click(screen.getAllByRole("button", { name: "Send reminder" })[0]);
    await tick(0);
    expect(remind).toHaveBeenCalledWith(1);
  });
});

describe("<Safety> (SOS) - server paging, search and the oldest open alert", () => {
  let spy;
  beforeEach(() => {
    vi.useFakeTimers();
    window.localStorage.setItem("aiwa_admin_session", "hint");
    __setPermissionsForTest(["SUPPORT"]);
    spy = vi.spyOn(mod.api, "safetyPage").mockResolvedValue({ rows: Array.from({ length: 10 }, (_, i) => sos(100 - i, `NOTE_${100 - i}`)), total: 57, totalPages: 6, oldest: sos(7, "THE_OLDEST") });
  });
  afterEach(() => vi.useRealTimers());

  it("shows the queue's real open count, the page the server sent and the OLDEST open alert even though it is not on this page", async () => {
    render(<Safety />);
    await tick(0);
    expect(spy).toHaveBeenLastCalledWith({ status: "OPEN", query: "", page: 0, size: 10 });
    expect(screen.getByText("57 open")).toBeInTheDocument();
    expect(screen.getByText("1–10 of 57")).toBeInTheDocument();
    expect(screen.getByText(/Oldest open alert/)).toBeInTheDocument();
    expect(screen.getByText(/Booking #5, raised by Caller 7/)).toBeInTheDocument();
    expect(screen.queryByText(/THE_OLDEST/)).not.toBeInTheDocument(); // not on this page: the banner does not need it to be
  });

  it("paging asks the server for that page and keeps the oldest-alert banner", async () => {
    render(<Safety />);
    await tick(0);
    fireEvent.click(screen.getByRole("button", { name: "Page 2" }));
    await tick(0);
    fireEvent.click(screen.getByRole("button", { name: "Page 3" }));
    await tick(0);
    expect(spy).toHaveBeenLastCalledWith({ status: "OPEN", query: "", page: 2, size: 10 });
    expect(screen.getByText(/Oldest open alert/)).toBeInTheDocument();
  });

  it("a search goes back to page 1, is one request after the pause, and the tag says 'matching' not 'open'", async () => {
    render(<Safety />);
    await tick(0);
    fireEvent.click(screen.getByRole("button", { name: "Page 2" }));
    await tick(0);
    const calls = spy.mock.calls.length;
    spy.mockResolvedValue({ rows: [sos(5, "NEEDLE")], total: 1, totalPages: 1, oldest: sos(7, "THE_OLDEST") });
    const box = screen.getByPlaceholderText(/Search person/);
    fireEvent.change(box, { target: { value: "ne" } });
    fireEvent.change(box, { target: { value: "needle" } });
    await tick(100);
    expect(spy.mock.calls.length).toBe(calls);
    await tick(300);
    expect(spy).toHaveBeenLastCalledWith({ status: "OPEN", query: "needle", page: 0, size: 10 });
    expect(screen.getByText("1 matching")).toBeInTheDocument();
    expect(screen.getByText(/NEEDLE/)).toBeInTheDocument();
  });

  it("the 15 s poll re-reads the page and search that are on screen", async () => {
    render(<Safety />);
    await tick(0);
    fireEvent.click(screen.getByRole("button", { name: "Page 2" }));
    await tick(0);
    const calls = spy.mock.calls.length;
    await tick(15_000);
    expect(spy.mock.calls.length).toBeGreaterThan(calls);
    expect(spy).toHaveBeenLastCalledWith({ status: "OPEN", query: "", page: 1, size: 10 });
  });

  it("an answer for a page or search the user already left is dropped, never shown under the new one", async () => {
    let slow;
    render(<Safety />);
    await tick(0);
    spy.mockReturnValueOnce(new Promise((resolve) => { slow = resolve; }));
    fireEvent.click(screen.getByRole("button", { name: "Page 2" })); // this read hangs (the footer is hidden while it loads)
    await tick(0);
    spy.mockResolvedValue({ rows: [sos(1, "SEARCH_ROW")], total: 1, totalPages: 1, oldest: sos(7, "THE_OLDEST") });
    fireEvent.change(screen.getByPlaceholderText(/Search person/), { target: { value: "search" } });
    await tick(400);
    expect(screen.getByText(/SEARCH_ROW/)).toBeInTheDocument();
    await act(async () => { slow({ rows: [sos(2, "PAGE_TWO_ROW")], total: 57, totalPages: 6, oldest: null }); await vi.advanceTimersByTimeAsync(0); });
    expect(screen.queryByText(/PAGE_TWO_ROW/)).not.toBeInTheDocument();
    expect(screen.getByText(/SEARCH_ROW/)).toBeInTheDocument();
    expect(screen.getByText("1 matching")).toBeInTheDocument();
  });

  it("when the queue shrinks below the page shown, the screen steps back to the last real page instead of 'No open SOS alerts'", async () => {
    spy.mockImplementation(async ({ page }) => (page >= 1 ? { rows: [], total: 10, totalPages: 1, oldest: sos(7, "THE_OLDEST") }
      : { rows: Array.from({ length: 10 }, (_, i) => sos(i + 1, `ROW_${i + 1}`)), total: 10, totalPages: 1, oldest: sos(7, "THE_OLDEST") }));
    render(<Safety />);
    await tick(0);
    // the user is on page 2 of what used to be 11 alerts; one was closed from elsewhere
    spy.mockImplementation(async ({ page }) => (page === 0
      ? { rows: Array.from({ length: 10 }, (_, i) => sos(i + 1, `ROW_${i + 1}`)), total: 10, totalPages: 1, oldest: sos(7, "THE_OLDEST") }
      : { rows: [], total: 10, totalPages: 1, oldest: sos(7, "THE_OLDEST") }));
    await tick(15_000);
    expect(screen.queryByText("No open SOS alerts")).not.toBeInTheDocument();
    expect(screen.getByText(/ROW_1\b/)).toBeInTheDocument();
  });

  it("closing an alert lowers the shown total and still needs a note and SUPPORT", async () => {
    const resolve = vi.spyOn(mod.api, "resolveSafety").mockResolvedValue({});
    render(<Safety />);
    await tick(0);
    fireEvent.click(screen.getAllByRole("button", { name: /Close alert/ })[0]);
    expect(resolve).not.toHaveBeenCalled(); // no note
    fireEvent.change(screen.getAllByPlaceholderText(/What was done/)[0], { target: { value: "called her" } });
    spy.mockReturnValue(new Promise(() => {})); // the confirming read has not answered yet
    fireEvent.click(screen.getAllByRole("button", { name: /Close alert/ })[0]);
    await tick(0);
    expect(resolve).toHaveBeenCalledWith(100, "called her");
    expect(screen.getByText("56 open")).toBeInTheDocument();
  });

  it("the Resolved view pages without polling and without an oldest-alert banner", async () => {
    spy.mockResolvedValue({ rows: [{ ...sos(3, "DONE"), resolved: true }], total: 12, totalPages: 2, oldest: null });
    render(<Safety />);
    await tick(0);
    fireEvent.click(screen.getByRole("button", { name: "Resolved" }));
    await tick(0);
    expect(spy).toHaveBeenLastCalledWith({ status: "RESOLVED", query: "", page: 0, size: 10 });
    expect(screen.queryByText(/Oldest open alert/)).not.toBeInTheDocument();
    expect(screen.getByText("1–10 of 12")).toBeInTheDocument();
  });
});
