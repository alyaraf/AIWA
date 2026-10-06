import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { render, screen, fireEvent, act } from "@testing-library/react";
import { Safety, __setPermissionsForTest } from "../App.jsx";
import * as mod from "../api.js";

/**
 * R6-03: the oldest open SOS alert is a fact about the WHOLE open queue. A search that matches nothing must still show it,
 * a queue that is genuinely empty shows none, the Resolved view neither reads nor shows it, and the one-request shortcut
 * stays for an unfiltered first page that holds the whole queue. These tests drive the real api.safetyPage and the real
 * Safety screen against a small stateful fake of GET /admin/safety (status, query, order, page, size) and of the resolve call.
 */

const tick = async (ms) => { await act(async () => { await vi.advanceTimersByTimeAsync(ms); }); };
const alert = (id, actorName, createdAt, resolved = false) => ({ id, bookingId: 100 + id, actorName, createdAt, resolved });

function fakeServer(alerts) {
  const calls = [];
  const hold = { next: null }; // set to a promise to make the next request hang until it resolves
  const impl = async (url, init = {}) => {
    const u = new URL(String(url));
    calls.push({ url: u, method: init.method || "GET" });
    const reply = (data) => ({ ok: true, status: 200, text: async () => JSON.stringify({ data }) });
    const resolveMatch = u.pathname.match(/\/admin\/safety\/(\d+)\/resolve$/);
    if (resolveMatch) {
      const hit = alerts.find((a) => a.id === Number(resolveMatch[1]));
      hit.resolved = true;
      return reply({ ...hit });
    }
    if (hold.next) { const wait = hold.next; hold.next = null; await wait; }
    const p = u.searchParams;
    const status = p.get("status");
    let rows = alerts.filter((a) => (status === "RESOLVED" ? a.resolved : status === "ALL" ? true : !a.resolved));
    const q = (p.get("query") || "").toLowerCase();
    if (q) rows = rows.filter((a) => a.actorName.toLowerCase().includes(q));
    rows = [...rows].sort((a, b) => (p.get("order") === "oldest" ? a.createdAt.localeCompare(b.createdAt) : b.createdAt.localeCompare(a.createdAt)));
    const size = Number(p.get("size")), page = Number(p.get("page"));
    return reply({ content: rows.slice(page * size, (page + 1) * size), totalElements: rows.length, totalPages: Math.ceil(rows.length / size) });
  };
  const reads = () => calls.filter((c) => c.url.pathname.endsWith("/admin/safety"));
  const oldestReads = () => reads().filter((c) => c.url.searchParams.get("order") === "oldest");
  return { impl, calls, reads, oldestReads, hold };
}

const many = (n) => Array.from({ length: n }, (_, i) => alert(i + 1, `Caller ${i + 1}`, `2026-10-06T${String(8 + Math.floor(i / 6)).padStart(2, "0")}:${String((i % 6) * 9).padStart(2, "0")}:00Z`));

describe("api.safetyPage - the oldest open alert is independent of the search's match count (R6-03)", () => {
  let server;
  const install = (alerts) => { server = fakeServer(alerts); vi.spyOn(globalThis, "fetch").mockImplementation(server.impl); };
  beforeEach(() => { vi.restoreAllMocks(); mod.setTokens({ accessToken: "A" }); });

  it("a search with ZERO matches still returns the unrelated global oldest open alert", async () => {
    install([alert(99, "Waiting customer", "2026-10-06T08:00:00Z"), alert(98, "Another", "2026-10-06T09:00:00Z")]);
    const result = await mod.api.safetyPage({ status: "OPEN", query: "no-such-person", page: 0, size: 10 });
    expect(result.rows).toEqual([]);
    expect(result.total).toBe(0);
    expect(result.oldest.id).toBe(99);
    expect(server.reads()).toHaveLength(2);
    const second = server.oldestReads()[0].url.searchParams;
    expect(second.get("query")).toBeNull(); // the global read is not narrowed by the search
    expect(second.get("size")).toBe("1");
  });

  it("a genuinely empty queue has no oldest alert: one request unfiltered, a second one (answering nothing) when a search is active", async () => {
    install([alert(1, "Done", "2026-10-06T08:00:00Z", true)]); // only a resolved alert exists
    const unfiltered = await mod.api.safetyPage({ status: "OPEN", page: 0, size: 10 });
    expect(unfiltered.oldest).toBeNull();
    expect(server.reads()).toHaveLength(1);
    const searched = await mod.api.safetyPage({ status: "OPEN", query: "done", page: 0, size: 10 });
    expect(searched.oldest).toBeNull();
    expect(server.oldestReads()).toHaveLength(1);
  });

  it("the one-request optimisation stays when an unfiltered first page holds the whole queue", async () => {
    install([alert(3, "C", "2026-10-06T10:00:00Z"), alert(2, "B", "2026-10-06T09:00:00Z"), alert(1, "A", "2026-10-06T08:00:00Z")]);
    const result = await mod.api.safetyPage({ status: "OPEN", page: 0, size: 10 });
    expect(server.reads()).toHaveLength(1);
    expect(result.oldest.id).toBe(1);
  });

  it("a later page or a queue larger than one page asks for the global oldest", async () => {
    install(many(25));
    const first = await mod.api.safetyPage({ status: "OPEN", page: 0, size: 10 });
    expect(server.oldestReads()).toHaveLength(1);
    const later = await mod.api.safetyPage({ status: "OPEN", page: 2, size: 10 });
    expect(server.oldestReads()).toHaveLength(2);
    expect(later.oldest.id).toBe(first.oldest.id);
    expect(first.oldest.id).toBe(1);
  });

  it("a search that matches something still returns the global (not the matching) oldest", async () => {
    install([alert(1, "Zed", "2026-10-06T08:00:00Z"), alert(2, "Amy", "2026-10-06T09:00:00Z"), alert(3, "Amy B", "2026-10-06T10:00:00Z")]);
    const result = await mod.api.safetyPage({ status: "OPEN", query: "amy", page: 0, size: 10 });
    expect(result.rows.map((r) => r.id)).toEqual([3, 2]);
    expect(result.oldest.id).toBe(1);
  });

  it("the Resolved and All views neither request nor return an open-alert banner", async () => {
    install([alert(1, "Zed", "2026-10-06T08:00:00Z"), alert(2, "Done", "2026-10-06T09:00:00Z", true)]);
    for (const status of ["RESOLVED", "ALL"]) {
      const result = await mod.api.safetyPage({ status, query: "nothing-matches", page: 0, size: 10 });
      expect(result.oldest).toBeNull();
    }
    expect(server.reads()).toHaveLength(2);
    expect(server.oldestReads()).toHaveLength(0);
  });

  it("a failed second read fails the whole read, also when the search matched nothing", async () => {
    const calls = [];
    vi.spyOn(globalThis, "fetch").mockImplementation(async (url) => {
      calls.push(String(url));
      if (calls.length === 1) return { ok: true, status: 200, text: async () => JSON.stringify({ data: { content: [], totalElements: 0, totalPages: 0 } }) };
      return { ok: false, status: 503, text: async () => JSON.stringify({ message: "down" }) };
    });
    await expect(mod.api.safetyPage({ status: "OPEN", query: "nobody", page: 0, size: 10 })).rejects.toMatchObject({ status: 503 });
    expect(calls).toHaveLength(2);
  });
});

describe("<Safety> - the oldest-open-alert banner (R6-03)", () => {
  let server;
  const open = (alerts) => {
    server = fakeServer(alerts);
    vi.spyOn(globalThis, "fetch").mockImplementation(server.impl);
  };
  beforeEach(() => {
    vi.restoreAllMocks();
    vi.useFakeTimers();
    mod.setTokens({ accessToken: "A" });
    window.localStorage.setItem("aiwa_admin_session", "hint");
    __setPermissionsForTest(["SUPPORT"]);
  });
  afterEach(() => vi.useRealTimers());
  const search = async (text) => {
    fireEvent.change(screen.getByPlaceholderText(/Search person/), { target: { value: text } });
    await tick(400);
  };

  it("a search with no match says 'No matches' AND still warns about the unrelated oldest open alert", async () => {
    open([alert(99, "Waiting customer", "2026-10-06T08:00:00Z"), alert(98, "Other", "2026-10-06T09:00:00Z")]);
    render(<Safety />);
    await tick(0);
    expect(screen.getByText(/raised by Waiting customer/)).toBeInTheDocument();
    await search("nobody-by-this-name");
    expect(screen.getByText("No matches")).toBeInTheDocument();
    expect(screen.getByText("0 matching")).toBeInTheDocument();
    expect(screen.getByText(/Oldest open alert/)).toBeInTheDocument();
    expect(screen.getByText(/Booking #199, raised by Waiting customer/)).toBeInTheDocument();
  });

  it("a genuinely empty queue shows no banner, with or without a search", async () => {
    open([alert(1, "Done", "2026-10-06T08:00:00Z", true)]);
    render(<Safety />);
    await tick(0);
    expect(screen.getByText("No open SOS alerts")).toBeInTheDocument();
    expect(screen.queryByText(/Oldest open alert/)).not.toBeInTheDocument();
    await search("done");
    expect(screen.getByText("No matches")).toBeInTheDocument();
    expect(screen.queryByText(/Oldest open alert/)).not.toBeInTheDocument();
  });

  it("the Resolved view neither requests nor displays the banner", async () => {
    open([alert(1, "Open one", "2026-10-06T08:00:00Z"), alert(2, "Done", "2026-10-06T09:00:00Z", true)]);
    render(<Safety />);
    await tick(0);
    expect(screen.getByText(/Oldest open alert/)).toBeInTheDocument();
    const before = server.oldestReads().length;
    fireEvent.click(screen.getByRole("button", { name: "Resolved" }));
    await tick(0);
    await search("nothing-matches");
    expect(screen.queryByText(/Oldest open alert/)).not.toBeInTheDocument();
    expect(server.oldestReads().length).toBe(before);
    expect(server.reads().at(-1).url.searchParams.get("status")).toBe("RESOLVED");
  });

  it("paging and changing the search keep the banner on the global oldest alert", async () => {
    open(many(25));
    render(<Safety />);
    await tick(0);
    expect(screen.getByText(/raised by Caller 1\b/)).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Page 2" }));
    await tick(0);
    expect(screen.getByText(/raised by Caller 1\b/)).toBeInTheDocument();
    await search("caller 2"); // matches Caller 2 and Caller 20..25 only
    expect(screen.getByText(/raised by Caller 1\b/)).toBeInTheDocument();
    await search("zzz-no-one");
    expect(screen.getByText("No matches")).toBeInTheDocument();
    expect(screen.getByText(/raised by Caller 1\b/)).toBeInTheDocument();
  });

  it("an obsolete answer never replaces the banner of the search on screen", async () => {
    open([alert(1, "Oldest person", "2026-10-06T08:00:00Z"), alert(2, "Newer person", "2026-10-06T09:00:00Z")]);
    render(<Safety />);
    await tick(0);
    let release;
    server.hold.next = new Promise((resolve) => { release = resolve; });
    await search("newer"); // this read hangs
    await search("oldest"); // ...the user already typed something else; this one is answered
    expect(screen.getByText(/Oldest person/, { selector: ".review-meta .strong-cell" })).toBeInTheDocument();
    await act(async () => { release(); await vi.advanceTimersByTimeAsync(0); });
    expect(screen.getByText("1 matching")).toBeInTheDocument();
    expect(screen.queryByText(/Newer person/, { selector: ".review-meta .strong-cell" })).not.toBeInTheDocument();
    expect(screen.getByText(/raised by Oldest person/)).toBeInTheDocument();
  });

  it("a failed second read keeps the last confirmed screen and reports it as not live (existing failure behaviour)", async () => {
    open([alert(1, "Oldest person", "2026-10-06T08:00:00Z"), alert(2, "Newer person", "2026-10-06T09:00:00Z")]);
    render(<Safety />);
    await tick(0);
    await search("nobody-by-this-name");
    expect(screen.getByText(/raised by Oldest person/)).toBeInTheDocument();
    // from now on the global read fails while the filtered read answers
    server.calls.length = 0;
    const answer = server.impl;
    globalThis.fetch.mockImplementation(async (url, init) => {
      if (new URL(String(url)).searchParams.get("order") === "oldest") return { ok: false, status: 503, text: async () => JSON.stringify({ message: "down" }) };
      return answer(url, init);
    });
    await tick(15_000);
    expect(screen.getByTestId("sos-stale-banner")).toBeInTheDocument();
    expect(screen.queryByText("Live · updated")).not.toBeInTheDocument();
  });

  it("closing the oldest alert removes it from the banner at once and the confirming read names the next oldest", async () => {
    open([alert(1, "Oldest person", "2026-10-06T08:00:00Z"), alert(2, "Next person", "2026-10-06T09:00:00Z"), alert(3, "Newest person", "2026-10-06T10:00:00Z")]);
    render(<Safety />);
    await tick(0);
    expect(screen.getByText(/raised by Oldest person/)).toBeInTheDocument();
    // list is newest first: the oldest alert's card is the last one
    const closeButtons = screen.getAllByRole("button", { name: /Close alert/ });
    const notes = screen.getAllByPlaceholderText(/What was done/);
    fireEvent.change(notes[2], { target: { value: "called her" } });
    fireEvent.click(closeButtons[2]);
    await tick(0);
    expect(screen.queryByText(/raised by Oldest person/)).not.toBeInTheDocument();
    expect(screen.getByText(/Booking #102, raised by Next person/)).toBeInTheDocument();
    expect(screen.getByText("2 open")).toBeInTheDocument();
  });

  it("closing the LAST open alert clears the banner", async () => {
    open([alert(1, "Only person", "2026-10-06T08:00:00Z")]);
    render(<Safety />);
    await tick(0);
    expect(screen.getByText(/raised by Only person/)).toBeInTheDocument();
    fireEvent.change(screen.getByPlaceholderText(/What was done/), { target: { value: "handled" } });
    fireEvent.click(screen.getByRole("button", { name: /Close alert/ }));
    await tick(0);
    expect(screen.queryByText(/Oldest open alert/)).not.toBeInTheDocument();
    expect(screen.getByText("No open SOS alerts")).toBeInTheDocument();
  });
});
