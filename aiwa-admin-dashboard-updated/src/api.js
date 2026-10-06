const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "http://localhost:8080/api";
// Mock mode only when explicitly asked for (VITE_USE_MOCKS=true); a build that
// forgets the flag talks to the real API instead of accepting any login (OPS-8).
const USE_MOCKS = import.meta.env.VITE_USE_MOCKS === "true"; // F-21: a literal comparison, so a normal build drops the mock code

// F-05: no credential is readable from JavaScript that outlives the page.
//  - The short-lived (15 min) ACCESS token lives only in this module's memory.
//  - The REFRESH token is an HttpOnly, Secure, SameSite=Strict cookie that the backend sets and the
//    browser sends to /auth/* (fetch with credentials: "include" + the X-Requested-With header). Script cannot read it.
//  - localStorage keeps only a non-secret "a session exists" hint (a random id), so a reload knows
//    whether to try restoring the session and other tabs learn about sign-in / sign-out.
// Reload: no access token in memory, hint present -> the first request gets 401, refreshes through
// the cookie and retries (or the login screen shows when the cookie is gone).

const SESSION_KEY = "aiwa_admin_session";
// Before F-05 the tokens themselves were stored under these keys. They are removed on load so a token
// left behind by an older build does not sit in the browser for longer than the upgrade.
const LEGACY_TOKEN_KEYS = ["aiwa_admin_access_token", "aiwa_admin_refresh_token"];
try { LEGACY_TOKEN_KEYS.forEach((key) => window.localStorage.removeItem(key)); } catch { /* storage unavailable */ }

// CSRF defence in depth: the backend refuses a cookie-based refresh without this header (a cross-site
// page cannot add it without a CORS preflight the API refuses).
const CSRF_HEADERS = { "X-Requested-With": "aiwa-admin" };

let accessToken = null;

export function getAccessToken() {
  return accessToken;
}

function sessionHint() {
  try { return !!window.localStorage.getItem(SESSION_KEY); } catch { return false; }
}

/** True while an admin is (or, after a reload, may still be) signed in. The hint holds no secret. */
export function hasSession() {
  return !!accessToken || sessionHint();
}

// Bumped when a session ends (sign-out, expiry) or a new one starts (sign-in).
// A refresh that was in flight across that change must not store its token
// (DR-003): it used to sign an admin who had just signed out straight back in.
let sessionGeneration = 0;

// R4-04: private downloads (documents, exports) that are still running when the session changes are cancelled, and
// whatever still completes is discarded by the generation check after its body has been read.
const blobControllers = new Set();

function bumpSessionGeneration() {
  sessionGeneration += 1;
  blobControllers.forEach((controller) => { try { controller.abort(); } catch { /* already finished */ } });
  blobControllers.clear();
}

/** The access token of a new sign-in (the refresh token arrives as a cookie). */
export function setTokens(tokens) {
  bumpSessionGeneration();
  if (tokens?.accessToken) accessToken = tokens.accessToken;
  try { window.localStorage.setItem(SESSION_KEY, `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 10)}`); } catch { /* storage unavailable */ }
  markActive();
}

export function clearTokens() {
  bumpSessionGeneration();
  accessToken = null;
  try {
    window.localStorage.removeItem(SESSION_KEY);
    window.localStorage.removeItem(IDLE_KEY);
  } catch { /* storage unavailable */ }
}

// CR-18: another tab ended the session this tab holds (signed out) or started a different one
// (signed in): what this tab has in flight carries the old session and must not write over it.
// After a sign-in elsewhere this tab drops its access token and gets one for the new session
// through the shared cookie; a sign-out ends it here too.
if (typeof window !== "undefined") {
  window.addEventListener("storage", (event) => {
    if (event.key !== null && event.key !== SESSION_KEY) return;
    bumpSessionGeneration();
    accessToken = null;
  });
}

/** localStorage key names the App's cross-tab listener watches. */
export const TOKEN_STORAGE_KEYS = [SESSION_KEY];

// S-04: an unattended browser must not stay signed in. After VITE_ADMIN_IDLE_MINUTES (default 30; 0
// turns it off) without a click or keypress the next API call, or the next poll of an open panel,
// ends the session and the admin signs in again (with 2FA).
const IDLE_KEY = "aiwa_admin_last_activity";
const IDLE_MS = (() => {
  const minutes = Number(import.meta.env.VITE_ADMIN_IDLE_MINUTES ?? 30);
  return Number.isFinite(minutes) && minutes > 0 ? minutes * 60_000 : 0;
})();

function markActive() {
  try { window.localStorage.setItem(IDLE_KEY, String(Date.now())); } catch { /* storage unavailable */ }
}

/** True when the signed-in admin has been inactive longer than the idle limit. */
export function sessionIdleExpired(now = Date.now()) {
  if (!IDLE_MS) return false;
  const last = Number(window.localStorage.getItem(IDLE_KEY));
  // No record (a session from before this check) counts as fresh; the next click starts the clock.
  return Number.isFinite(last) && last > 0 && now - last > IDLE_MS;
}

if (typeof window !== "undefined" && IDLE_MS) {
  let lastWrite = 0;
  const onUserActivity = () => {
    const now = Date.now();
    if (now - lastWrite < 10_000 || !hasSession() || sessionIdleExpired(now)) return;
    lastWrite = now;
    markActive();
  };
  window.addEventListener("pointerdown", onUserActivity, { passive: true });
  window.addEventListener("keydown", onUserActivity, { passive: true });
}

// AD-04: one signal for "this session is over" (idle limit or a refresh the server rejected). The App
// subscribes and drops every view that still holds the previous admin's data; before, only the request
// that noticed learned about it, and a page that swallowed the error stayed on screen with its old rows.
const sessionEndedListeners = new Set();

/** Subscribes to session end (reason "idle" | "expired"); returns the unsubscribe function. */
export function onSessionEnded(listener) {
  sessionEndedListeners.add(listener);
  return () => sessionEndedListeners.delete(listener);
}

function endSession(reason) {
  const hadSession = hasSession();
  clearTokens();
  if (hadSession) sessionEndedListeners.forEach((listener) => { try { listener(reason); } catch { /* a listener must not break sign-out */ } });
}

function sessionEndedError(reason) {
  const error = new Error(reason === "idle"
    ? "You were signed out after a period of inactivity. Please sign in again."
    : "Your session has ended. Please sign in again.");
  error.status = 401;
  error.sessionEnded = true;
  return error;
}

/**
 * Enforces the idle limit. Called before every request and blob download, by the App's timer and when the tab
 * becomes visible again. Returns true when it ended the session.
 */
export function enforceIdleLimit() {
  if (hasSession() && sessionIdleExpired()) {
    endSession("idle");
    return true;
  }
  return false;
}

// P-04: a response that arrives after the session changed (sign-out, expiry, another tab signing in as someone
// else) belongs to the previous session and must never be shown or cached for the new one.
function staleSessionError() {
  const error = new Error("The session changed while this request was running.");
  error.status = 0;
  error.code = "SESSION_CHANGED";
  error.stale = true;
  return error;
}

// CR-18: how long the best-effort server sign-out may take before it is dropped.
const SIGN_OUT_TIMEOUT_MS = 3000;

/**
 * Signs out: the local session goes first (so a stalled connection cannot keep the admin signed in),
 * then the server is told on a best-effort basis (it revokes the refresh cookie's token and clears
 * the cookie), giving up after a few seconds.
 */
// P-03: the logout response clears the refresh cookie. A slow logout that finishes after the NEXT sign-in has set
// its cookie would clear the new session's cookie, so a sign-in waits for any sign-out still in flight.
let signOutInFlight = null;

function signOut() {
  const token = getAccessToken();
  const hadSession = hasSession();
  clearTokens();
  if (USE_MOCKS || !hadSession) return Promise.resolve();
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), SIGN_OUT_TIMEOUT_MS);
  const headers = { "Content-Type": "application/json", ...CSRF_HEADERS };
  if (token) headers.Authorization = `Bearer ${token}`;
  const call = fetch(`${API_BASE_URL}/auth/logout`, {
    method: "POST", headers, credentials: "include", signal: controller.signal, body: "{}"
  }).catch(() => {}).finally(() => {
    clearTimeout(timer);
    if (signOutInFlight === call) signOutInFlight = null;
  });
  signOutInFlight = call;
  return call;
}

// A 401 from any endpoint but these two means "this access token is no good
// anymore" (expired is the common case — access tokens last 15 minutes) rather than
// "this account can't do that" — worth a silent refresh-and-retry before
// giving up and forcing a full re-login. Refreshing itself, or a login
// attempt, failing with 401 is the real "you're signed out" signal.
const NO_REFRESH_RETRY_PATHS = new Set(["/auth/refresh", "/auth/login"]);

// Concurrent requests that all 401 at once (e.g. a page loading several
// widgets right as the token expires) must not each fire their own refresh —
// they share one in-flight attempt and all retry once it settles.
let refreshInFlight = null;

// SA-14: why the last refresh failed. A refresh the server REJECTED (401/403) ends the session;
// one that could not be answered (network down, 5xx, a proxy error page) must not, or a short
// backend outage signs every admin out.
let refreshFailedTransiently = false;

// The refresh token is single-use and shared by every tab through the cookie, so tabs take turns
// (Web Locks). Without the API the refreshes simply run as before: a loser sees 401 and signs in again.
function withRefreshLock(call) {
  const locks = typeof navigator !== "undefined" ? navigator.locks : undefined;
  return locks?.request ? locks.request("aiwa-admin-refresh", call) : call();
}

function refreshAccessToken() {
  if (refreshInFlight) return refreshInFlight;
  if (!hasSession()) return Promise.resolve(false);

  refreshFailedTransiently = false;
  const generation = sessionGeneration;

  refreshInFlight = withRefreshLock(() => fetch(`${API_BASE_URL}/auth/refresh`, {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json", ...CSRF_HEADERS },
    body: "{}"
  }))
    .then(async (response) => {
      const text = await response.text();
      let data = null;
      try { data = text ? JSON.parse(text) : null; } catch { data = null; }
      if (!response.ok) {
        if (response.status !== 401 && response.status !== 403) refreshFailedTransiently = true;
        return false;
      }
      const tokens = unwrap(data);
      if (!tokens?.accessToken) return false;
      // Signed out (or in again) while this was in flight: drop it.
      if (generation !== sessionGeneration) return false;
      accessToken = tokens.accessToken;
      return true;
    })
    .catch(() => {
      refreshFailedTransiently = true;
      return false;
    })
    .finally(() => { refreshInFlight = null; });

  return refreshInFlight;
}

/**
 * Authenticated GET for a non-JSON body (document images, CSV exports). It goes through the same session rules
 * as request(): idle limit, one refresh-and-retry on 401, and a response that arrives after the session changed
 * is discarded (AD-04).
 */
async function authedBlobFetch(path, isRetryAfterRefresh = false, signal = undefined) {
  if (enforceIdleLimit()) throw sessionEndedError("idle");
  const generation = sessionGeneration;
  const token = getAccessToken();
  const response = await fetch(`${API_BASE_URL}${path}`, { headers: token ? { Authorization: `Bearer ${token}` } : {}, ...(signal ? { signal } : {}) });
  if (generation !== sessionGeneration) throw staleSessionError();
  if (response.status === 401 && !isRetryAfterRefresh) {
    const stored = getAccessToken();
    const refreshed = (stored && stored !== token) || await refreshAccessToken();
    if (refreshed && generation === sessionGeneration) return authedBlobFetch(path, true, signal);
    if (!refreshed && !refreshFailedTransiently && generation === sessionGeneration && hasSession()) {
      endSession("expired");
      throw sessionEndedError("expired");
    }
  }
  return response;
}

/**
 * R4-04: the complete private download. The session generation is validated AFTER the whole body was read, so the
 * caller only ever receives a blob that belongs to the session that asked for it; creating an object URL or starting
 * a download is a side effect and must happen after this returns. A session change cancels the transfer and rejects
 * with SESSION_CHANGED. Returns { response, blob } (blob is null for a non-2xx response).
 */
async function authedBlob(path) {
  const generation = sessionGeneration;
  const controller = typeof AbortController === "function" ? new AbortController() : null;
  if (controller) blobControllers.add(controller);
  try {
    const response = await authedBlobFetch(path, false, controller?.signal);
    if (generation !== sessionGeneration) throw staleSessionError();
    if (!response.ok) return { response, blob: null };
    const blob = await response.blob();
    if (generation !== sessionGeneration) throw staleSessionError();
    return { response, blob };
  } catch (error) {
    // An aborted transfer is the session change we caused; report it as that.
    if (generation !== sessionGeneration && !error?.sessionEnded) throw staleSessionError();
    throw error;
  } finally {
    if (controller) blobControllers.delete(controller);
  }
}

async function request(path, options = {}, isRetryAfterRefresh = false) {
  if (USE_MOCKS) return mockRequest(path, options);
  if (path === "/auth/login") {
    // A sign-in is how a session starts, so a leftover idle record from an old session is cleared, not an error.
    if (signOutInFlight) await signOutInFlight;
    if (hasSession() && sessionIdleExpired()) clearTokens();
  } else if (enforceIdleLimit()) {
    throw sessionEndedError("idle");
  }

  const headers = new Headers(options.headers || {});
  if (!(options.body instanceof FormData)) headers.set("Content-Type", "application/json");

  const token = getAccessToken();
  if (token) headers.set("Authorization", `Bearer ${token}`);
  const generation = sessionGeneration;

  // /auth/* is where the refresh cookie is set and sent (F-05); it needs credentials and the CSRF header.
  const authPath = path.startsWith("/auth/");
  if (authPath) Object.entries(CSRF_HEADERS).forEach(([name, value]) => headers.set(name, value));
  const response = await fetch(`${API_BASE_URL}${path}`, { ...options, headers, ...(authPath ? { credentials: "include" } : {}) });
  const text = await response.text();
  // A proxy error page (HTML 502/504) is not JSON; keep the status instead of
  // surfacing "Unexpected token <".
  let data = null;
  if (text) {
    try { data = JSON.parse(text); } catch {
      if (response.ok) throw new Error("The server sent an unreadable response.");
    }
  }

  // P-04: the session changed while this was in flight; the body belongs to the previous one.
  if (generation !== sessionGeneration) throw staleSessionError();

  if (!response.ok) {
    if (response.status === 401 && !isRetryAfterRefresh && !NO_REFRESH_RETRY_PATHS.has(path)
        && generation === sessionGeneration) {
      // Another tab already refreshed: the stored token is newer than the one sent.
      const stored = getAccessToken();
      const refreshed = (stored && stored !== token) || await refreshAccessToken();
      if (refreshed && generation === sessionGeneration) return request(path, options, true);
      if (!refreshed && refreshFailedTransiently && generation === sessionGeneration) {
        // The refresh could not be answered, which says nothing about the session: keep the
        // tokens and report a temporary failure instead of the 401 that signs the admin out.
        const unavailable = new Error("The server could not be reached. You are still signed in; try again in a moment.");
        unavailable.status = 503;
        unavailable.transient = true;
        throw unavailable;
      }
    }
    // The server rejected the session (and its refresh): it is over for every view, not just this call.
    if (response.status === 401 && !NO_REFRESH_RETRY_PATHS.has(path) && generation === sessionGeneration && hasSession()) {
      endSession("expired");
    }
    const message = data?.message || data?.error || `Request failed with status ${response.status}`;
    const error = new Error(message);
    error.status = response.status;
    error.code = data?.code;
    // E-1: the backend refuses Super admin / Finance until two-factor is on.
    if (response.status === 403 && data?.code === ADMIN_2FA_REQUIRED) onAdminTwoFactorRequired();
    throw error;
  }

  return unwrap(data);
}

/**
 * Every row of a paged admin list (OPS-8). These queues used to ask for one
 * page of 500 and silently drop the rest; now they walk the pages. Capped at
 * 50 pages so a runaway list can't hang the panel.
 */
export const MAX_PAGES = 50;

export async function requestAllPages(path, size = 200) {
  const sep = path.includes("?") ? "&" : "?";
  const all = [];
  let truncated = false;
  let total = null;
  for (let page = 0; page < MAX_PAGES; page += 1) {
    const result = await request(`${path}${sep}page=${page}&size=${size}`);
    const items = normalizeList(result);
    all.push(...items);
    const totalPages = result?.totalPages ?? result?.data?.totalPages;
    total = result?.totalElements ?? result?.data?.totalElements ?? total;
    if (totalPages == null || page + 1 >= totalPages || items.length < size) break;
    // Hit the cap with the server still holding more: say so. The list is NOT complete (AD-13).
    if (page + 1 >= MAX_PAGES) truncated = true;
  }
  return markTruncation(all, truncated, total);
}

/**
 * R4 follow-up: ONE server page of an admin queue, filtered and searched by the server, with the server's own total.
 * Unlike {@link requestAllPages} nothing is collected up to a cap and filtered in the browser, so the count, the page
 * numbers and the search always describe the whole queue. Resolves to { rows, total, totalPages }.
 * In mock mode (no server) the mock list is filtered and sliced here so the screens behave the same ("mockKeep" is an extra
 * mock-only row filter for a queue the server narrows by a parameter the mock data does not carry).
 */
export async function requestPage(path, { page = 0, size = 10, query = "", ...filters } = {}, normalize = (item) => item, mockKeep = () => true) {
  const params = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => { if (value !== undefined && value !== null && value !== "") params.set(key, String(value)); });
  const text = String(query || "").trim();
  if (text) params.set("query", text);
  params.set("page", String(page));
  params.set("size", String(size));
  const result = await request(`${path}?${params.toString()}`);
  if (USE_MOCKS) {
    const needle = text.toLowerCase();
    const all = normalizeList(result)
      .filter((item) => !filters.status || filters.status === "ALL" || item.status === undefined || item.status === filters.status)
      .filter(mockKeep)
      .filter((item) => !filters.maxRating || !(Number(item.rating) > Number(filters.maxRating)))
      .filter((item) => !needle || JSON.stringify(Object.values(item)).toLowerCase().includes(needle));
    return { rows: all.slice(page * size, (page + 1) * size).map(normalize), total: all.length, totalPages: Math.max(1, Math.ceil(all.length / size)) };
  }
  const body = result?.data ?? result;
  const items = normalizeList(result);
  const total = Number.isFinite(Number(body?.totalElements)) ? Number(body.totalElements) : items.length;
  const totalPages = Math.max(1, Number(body?.totalPages) || Math.ceil(total / size) || 1);
  return { rows: items.map(normalize), total, totalPages };
}

/**
 * Carries "this list was cut off" along with the rows. The properties are not enumerable, so existing code that
 * maps, filters or spreads the array keeps working; {@link isTruncated} reads them back, and normalizing a list
 * with {@link carryTruncation} keeps the mark.
 */
function markTruncation(list, truncated, total) {
  Object.defineProperty(list, "truncated", { value: !!truncated, enumerable: false, configurable: true });
  Object.defineProperty(list, "serverTotal", { value: total ?? null, enumerable: false, configurable: true });
  return list;
}

/** Maps a loaded list and keeps its truncation mark. */
export function carryTruncation(source, mapped) {
  return markTruncation(mapped, source?.truncated === true, source?.serverTotal ?? null);
}

/** True when the list stopped at the page cap although the server has more rows. */
export function isTruncated(list) {
  return !!list && list.truncated === true;
}

/** E-1 (AdminTwoFactorInterceptor): the code of a 403 that means "turn on two-factor first". */
export const ADMIN_2FA_REQUIRED = "auth.error.admin_2fa_required";
let onAdminTwoFactorRequired = () => {};
/** App registers the handler that shows the two-factor setup gate. */
export function setAdminTwoFactorHandler(fn) { onAdminTwoFactorRequired = typeof fn === "function" ? fn : () => {}; }

export const api = {
  login: (payload) => request("/auth/login", {
    method: "POST",
    body: JSON.stringify({
      identifier: payload.identifier || payload.email || payload.phone,
      password: payload.password
    })
  }),
  me: () => request("/auth/me"),
  logout: signOut,
  verifyMfa: (mfaToken, code) => request("/auth/2fa/verify", {
    method: "POST",
    body: JSON.stringify({ mfaToken, code })
  }),
  totpStatus: () => request("/auth/2fa/status"),
  /** Public — no auth. Returns the server's current clock so a user with
   *  TOTP problems can compare their phone's time to it (>30s skew is the
   *  usual "code always rejected" cause). */
  totpServerTime: () => request("/auth/2fa/server-time"),
  /** DR-017: needs the current password (and current code when 2FA is already on). */
  totpSetup: (password, code) => request("/auth/2fa/setup", {
    method: "POST",
    body: JSON.stringify({ password, code: code || undefined })
  }),
  /** SA-02: turning 2FA on ends the sessions issued before it; the response carries the new pair. */
  totpEnable: (code) => request("/auth/2fa/enable", {
    method: "POST",
    body: JSON.stringify({ code })
  }).then((result) => {
    if (result?.accessToken) setTokens(result);
    return result;
  }),
  totpDisable: (password, code) => request("/auth/2fa/disable", {
    method: "POST",
    body: JSON.stringify({ password, code: code || undefined })
  }),
  dashboard: () => request("/admin/dashboard").then(normalizeDashboard),
  dashboardRaw: () => request("/admin/dashboard").then(unwrap),
  /** R5 follow-up: a server page of the verification queue ({ status, query, page, size }); no status = the pending queue. */
  verificationsPage: ({ status, ...options } = {}) => (status && status !== "PENDING_VERIFICATION" && status !== "PENDING")
    ? requestPage("/admin/verification", { ...options, status }, normalizeVerification)
    : requestPage("/admin/verification/pending", options, normalizeVerification),
  approveProvider: (providerId) => request(`/admin/verification/${providerId}/approve`, { method: "POST" }),
  rejectProvider: (providerId, reason) => request(`/admin/verification/${providerId}/reject`, { method: "POST", body: JSON.stringify({ reason }) }),
  /** Blob URL for a private verification document (caller must revokeObjectURL). */
  verificationDocUrl: async (filePath) => {
    if (USE_MOCKS) return null;
    const docPath = `/admin/verification/document?filePath=${encodeURIComponent(filePath)}`;
    const { response: res, blob } = await authedBlob(docPath);
    if (!res.ok) { const e = new Error(`Document load failed (${res.status})`); e.status = res.status; throw e; }
    return URL.createObjectURL(blob);
  },
  /** R5 follow-up: a server page of reported reviews ({ query, page, size }). */
  reviewReportsPage: (options) => requestPage("/admin/reviews/moderation", options, normalizeReviewReport),
  /** R5 follow-up: a server page of reported chat messages ({ query, page, size }). */
  chatReportsPage: (options) => requestPage("/admin/chat/moderation", options, normalizeChatReport),
  resolveReviewReport: (caseId, action) => request(`/admin/reviews/moderation/${caseId}/resolve?action=${encodeURIComponent(action)}`, { method: "POST" }),
  resolveChatReport: (caseId, action) => request(`/admin/chat/moderation/${caseId}/resolve?action=${encodeURIComponent(action)}`, { method: "POST" }),
  /** R4 follow-up: a server page of complaints ({ status, query, page, size }). */
  complaintsPage: (options) => requestPage("/admin/complaints", options, normalizeComplaint),
  complaints: () => requestAllPages("/admin/complaints").then((items) => carryTruncation(items, items.map(normalizeComplaint))),
  resolveComplaint: (id, notes) => request(`/admin/complaints/${id}/resolve`, { method: "POST", body: JSON.stringify({ notes }) }).then(normalizeComplaint),
  flagComplaint: (id) => request(`/admin/complaints/${id}/flag`, { method: "POST" }),
  userActivity: (id) => request(`/admin/users/${id}/activity`).then(unwrap),
  editUser: (id, fields) => request(`/admin/users/${id}`, { method: "PATCH", body: JSON.stringify(fields) }).then(normalizeUser),
  resetUserPassword: (id) => request(`/admin/users/${id}/reset-password`, { method: "POST" }).then(unwrap),
  /** Server-side role filter, search (name/email/phone) and paging (OPS-8). */
  users: ({ role, query = "", page = 0, size = 20 } = {}) => {
    const qs = new URLSearchParams({ page: String(page), size: String(size) });
    if (role) qs.set("role", role);
    if (query.trim()) qs.set("q", query.trim());
    return request(`/admin/users?${qs.toString()}`).then((result) => ({
      items: normalizeList(result).map(normalizeUser),
      totalPages: Math.max(1, result?.totalPages ?? result?.data?.totalPages ?? 1),
      total: result?.totalElements ?? result?.data?.totalElements ?? normalizeList(result).length
    }));
  },
  createAdmin: (payload) => request("/admin/users/admins", { method: "POST", body: JSON.stringify(payload) }),
  updateAdminPermissions: (id, permissions) => {
    const qs = permissions.map((p) => `permissions=${encodeURIComponent(p)}`).join("&");
    return request(`/admin/users/${id}/permissions?${qs}`, { method: "PATCH" });
  },
  deactivateUser: (id) => request(`/admin/users/${id}/deactivate`, { method: "PATCH" }),
  reactivateUser: (id) => request(`/admin/users/${id}/reactivate`, { method: "PATCH" }),
  deleteUser: (id) => request(`/admin/users/${id}`, { method: "DELETE" }),
  userDetail: (id) => request(`/admin/users/${id}`).then(normalizeUser),
  providerDetail: (providerId) => request(`/providers/${providerId}`),
  reactivateProvider: (providerId) => request(`/admin/verification/${providerId}/reactivate`, { method: "POST" }),
  /** R5 follow-up: a server page of REPORTED PHOTOS ({ query, page, size }); reviews and chat have their own queues. */
  moderationPage: (options) => requestPage("/admin/moderation", { ...options, type: "GALLERY_IMAGE" }, normalizeModeration,
    (item) => normalizeModeration(item).type === "IMAGE"),
  moderationAction: (id, payload) => request(`/admin/moderation/${id}/action?status=${encodeURIComponent(payload.status)}`, { method: "PATCH", body: JSON.stringify({ notes: payload.notes || "" }) }),
  // DR-028: these lists are paged on the server; walk every page.
  settlements: () => requestAllPages("/admin/settlements").then((items) => carryTruncation(items, items.map(normalizeSettlement))),
  settle: (id, expectedAmount, reference) => request(`/admin/settlements/${id}/settle?expectedAmount=${encodeURIComponent(expectedAmount)}&reference=${encodeURIComponent(reference)}`, { method: "PATCH" }),
  settlementOverview: () => request("/admin/settlements/overview"),
  /** R5 follow-up: a server page of the provider settlement rows ({ status: ALL|OVERDUE|WITHIN_LIMIT|SETTLED, query, page, size }). */
  settlementProvidersPage: (options) => requestPage("/admin/settlements/providers", options),
  settlementDetail: (providerId) => request(`/admin/settlements/provider/${providerId}`),
  // CR-06: what a confirmation would settle ({ reportedAt, total, entryCount });
  // the confirmation sends that total back and the server refuses any other.
  payoutReport: (providerId) => request(`/admin/settlements/provider/${providerId}/payout-report`),
  confirmPayout: (providerId, expectedAmount) => request(`/admin/settlements/provider/${providerId}/confirm-payout?expectedAmount=${encodeURIComponent(expectedAmount)}`, { method: "POST" }),
  setSettlementPause: (providerId, paused) => request(`/admin/providers/${providerId}/settlement-pause?paused=${paused}`, { method: "PATCH" }),
  latestTerms: (type = "CUSTOMER_TERMS") => request(`/terms/latest?type=${type}`),
  termsVersions: (type = "CUSTOMER_TERMS") => request(`/terms?type=${type}`).then(normalizeList),
  // CR-21: a full policy (Arabic especially) does not fit in a URL, so it goes in the body.
  publishTerms: (version, contentEn, type = "CUSTOMER_TERMS", contentAr = "", changeNote = "") => {
    const body = { version, type, contentEn };
    if (contentAr && contentAr.trim()) body.contentAr = contentAr;
    if (changeNote && changeNote.trim()) body.changeNote = changeNote.trim();
    return request("/terms", { method: "POST", body: JSON.stringify(body) });
  },
  // DR-006 (the oldest open alerts were never shown) is answered by safetyPage below: the oldest open alert is its own read.
  /**
   * R5 follow-up: ONE server page of the SOS queue ({ status, query, page, size }) with the queue's real total. For the OPEN
   * queue it also resolves the OLDEST open alert (the one most at risk of being missed), because with paging it is not
   * necessarily on the page shown: it is taken from the page itself when that page is the whole queue, otherwise from a
   * second request (order=oldest, size 1). Both reads belong to the same call, so the screen's ordered-read rule (one
   * accepted read, no freshness without a server answer) applies to the pair; if either fails the whole read fails.
   * R6-03: the oldest open alert is a fact about the WHOLE open queue, so it never depends on how many alerts match the
   * search: a search with zero matches still reads it (an unrelated alert may be waiting). The only reads that are skipped
   * are the ones whose answer is already known: an unfiltered queue that is empty (nothing is open) and an unfiltered first
   * page that holds the whole queue (its last row is the oldest).
   * Resolves to { rows, total, totalPages, oldest }.
   */
  safetyPage: async ({ status = "OPEN", query = "", page = 0, size = 10 } = {}) => {
    const current = await requestPage("/admin/safety", { status, query, page, size }, normalizeSafety);
    if (status !== "OPEN") return { ...current, oldest: null };
    const text = String(query || "").trim();
    let oldest = null;
    if (!text && current.total === 0) {
      oldest = null; // the whole open queue is empty: there is nothing to warn about
    } else if (!text && page === 0 && current.total <= size) {
      oldest = current.rows[current.rows.length - 1] ?? null; // newest first: the last row of the whole queue is the oldest
    } else {
      // a search (matches or not), a later page, or a queue larger than a page: ask for the global oldest
      const first = await requestPage("/admin/safety", { status: "OPEN", order: "oldest", page: 0, size: 1 }, normalizeSafety);
      oldest = first.rows[0] ?? null;
    }
    return { ...current, oldest };
  },
  resolveSafety: (eventId, notes) => request(`/admin/safety/${eventId}/resolve`, { method: "POST", body: JSON.stringify({ notes }) })
    .then(normalizeSafety),
  exportAudit: (query = "") => downloadFile(`/admin/audit/export${query ? `?query=${encodeURIComponent(query)}` : ""}`, "aiwa-audit-log.csv", "text/csv"),
  supportContact: () => request("/support/contact"),
  getSupportSettings: () => request("/support/admin/settings"),
  updateSupportSettings: (payload) =>
    request("/support/admin/settings", { method: "PATCH", body: JSON.stringify(payload) }),
  getCommission: () => request("/admin/settings/commission"),
  setCommission: (percent) => request(`/admin/settings/commission?percent=${encodeURIComponent(percent)}`, { method: "PATCH" }),
  providerSettings: (providerId) => request(`/admin/providers/${providerId}/settings`),
  // Admin-only: includes inactive/departed staff, unlike the public provider detail.
  providerStaff: (providerId) => request(`/admin/providers/${providerId}/staff`).then(normalizeList),
  setProviderCommission: (providerId, percent) => {
    const qs = percent == null || percent === ""
      ? "clear=true"
      : `percent=${encodeURIComponent(percent)}`;
    return request(`/admin/providers/${providerId}/commission?${qs}`, { method: "PATCH" });
  },
  setProviderBookingRules: (providerId, { set = {}, clear = [] }) => {
    const qs = new URLSearchParams();
    if (set.cancellationCutoffHours != null) qs.set("cancellationCutoffHours", String(set.cancellationCutoffHours));
    if (set.providerCancelPenaltyPercent != null) qs.set("providerCancelPenaltyPercent", String(set.providerCancelPenaltyPercent));
    if (set.responseWindowMinutes != null) qs.set("responseWindowMinutes", String(set.responseWindowMinutes));
    if (clear.length) qs.set("clear", clear.join(","));
    return request(`/admin/providers/${providerId}/booking-rules?${qs.toString()}`, { method: "PATCH" });
  },
  setProviderTravelFee: (providerId, amount) => {
    const qs = amount == null || amount === "" || Number(amount) === 0
      ? "clear=true"
      : `amount=${encodeURIComponent(amount)}`;
    return request(`/admin/providers/${providerId}/travel-fee?${qs}`, { method: "PATCH" });
  },
  remindSettlement: (providerId) => request(`/admin/settlements/provider/${providerId}/remind`, { method: "POST" }),
  exportLedger: () => downloadFile("/admin/settlements/export", "commission-ledger.csv", "text/csv"),
  exportBookings: (days = 30) => downloadFile(`/admin/analytics/export?days=${days}`, "aiwa-bookings.csv", "text/csv"),
  analyticsBookings: (days = 14) => request(`/admin/analytics/bookings?days=${days}`).then(normalizeList).then((rows) => rows.map(normalizeAnalyticsPoint)),
  verificationCounts: () => request("/admin/verification/counts"),
  forceCancelBooking: (id, reason) => request(`/admin/bookings/${id}/force-cancel`, { method: "POST", body: JSON.stringify(reason ? { reason } : {}) }),
  resolveDispute: (id, outcome, reason) => request(`/admin/bookings/${id}/resolve-dispute?outcome=${encodeURIComponent(outcome)}`, { method: "POST", body: JSON.stringify(reason ? { reason } : {}) }),
  bookingChat: (id) => request(`/admin/bookings/${id}/chat`).then(normalizeList),
  getBookingRules: () => request("/admin/settings/booking-rules"),
  setBookingRules: (rules) => {
    const qs = new URLSearchParams();
    if (rules.cancellationCutoffHours != null) qs.set("cancellationCutoffHours", String(rules.cancellationCutoffHours));
    if (rules.providerCancelPenaltyPercent != null) qs.set("providerCancelPenaltyPercent", String(rules.providerCancelPenaltyPercent));
    if (rules.responseWindowMinutes != null) qs.set("responseWindowMinutes", String(rules.responseWindowMinutes));
    return request(`/admin/settings/booking-rules?${qs.toString()}`, { method: "PATCH" });
  },
  saveVerificationNote: (providerId, note) => request(`/admin/verification/${providerId}/note`, { method: "PATCH", body: JSON.stringify({ note }) }),
  requestProviderInfo: (providerId, message) => request(`/admin/verification/${providerId}/request-info`, { method: "POST", body: JSON.stringify({ message }) }),
  suspendProvider: (providerId) => request(`/admin/verification/${providerId}/suspend`, { method: "POST" }),
  warnUser: (id, reason) => request(`/admin/users/${id}/warn`, { method: "POST", body: JSON.stringify({ reason }) }),
  setReviewVisibility: (id, hidden) => request(`/admin/reviews/${id}/visibility?hidden=${hidden}`, { method: "PATCH" }),
  /** Unified inbox: complaints + verifications + reported content + disputes,
   *  newest first. Powers the top-bar notification bell. */
  inbox: (limit = 20) => request(`/admin/inbox?limit=${limit}`)
    .then(normalizeList)
    .then((items) => items.map((it) => ({
      id: it.id,
      kind: it.kind,
      title: it.title,
      body: it.body,
      when: formatWhen(it.createdAt),
      createdAt: it.createdAt,
      targetRoute: it.targetRoute
    }))),
  audit: (query, page = 0, size = 20) => {
    const qs = new URLSearchParams({ page: String(page), size: String(size) });
    if (query) qs.set("query", query);
    return request(`/admin/audit?${qs.toString()}`).then((result) => ({
      items: normalizeList(result).map(normalizeAudit),
      totalPages: result?.totalPages ?? 1
    }));
  },
  /** Server-side search / filter / paging (GET /admin/bookings). filter is a monitor chip. */
  bookings: ({ query = "", filter = "All", page = 0, size = 6 } = {}) =>
    request(`/admin/bookings?${bookingParams(query, filter, { page: String(page), size: String(size) })}`)
      .then((result) => ({
        items: normalizeList(result).map(normalizeBooking),
        totalPages: Math.max(1, result?.totalPages ?? result?.data?.totalPages ?? 1),
        total: result?.totalElements ?? result?.data?.totalElements ?? normalizeList(result).length
      })),
  bookingStats: () => request("/admin/bookings/stats"),
  exportBookingList: (query = "", filter = "All") =>
    downloadFile(`/admin/bookings/export?${bookingParams(query, filter)}`, "aiwa-bookings.csv", "text/csv"),
  /** R4 follow-up: a server page of every review ({ query, maxRating, page, size }). */
  reviewsPage: (options) => requestPage("/admin/reviews", options, normalizeReview),
  flagsPage: (options) => requestPage("/admin/flags", options, normalizeFlag),
  reviews: () => requestAllPages("/admin/reviews").then((items) => carryTruncation(items, items.map(normalizeReview))),
  flags: () => requestAllPages("/admin/flags").then((items) => carryTruncation(items, items.map(normalizeFlag)))
};

function unwrap(payload) {
  return payload?.data ?? payload;
}

/** Public upload paths ("/files/public/…") are served under the API base. */
export function mediaUrl(path) {
  if (!path) return null;
  if (/^https?:\/\//.test(path)) return path;
  return `${API_BASE_URL}${path.startsWith("/") ? "" : "/"}${path}`;
}

/** AdminSafetyEventDto → one SOS row. */
export function normalizeSafety(item) {
  return {
    id: item.id,
    bookingId: item.bookingId,
    bookingStatus: item.bookingStatus || "",
    homeService: !!item.homeService,
    address: item.address || "",
    actorName: item.actorName || "Unknown",
    actorRole: item.actorRole || "",
    actorPhone: item.actorPhone || "",
    customerName: item.customerName || "",
    customerPhone: item.customerPhone || "",
    providerName: item.providerName || "",
    providerPhone: item.providerPhone || "",
    latitude: item.latitude ?? null,
    longitude: item.longitude ?? null,
    notes: item.notes || "",
    resolved: !!item.resolved,
    resolvedAt: item.resolvedAt || null,
    resolvedByName: item.resolvedByName || "",
    resolutionNotes: item.resolutionNotes || "",
    createdAt: item.createdAt || null,
    when: formatWhen(item.createdAt),
    // BE-37: who the SOS texts reached.
    deliveries: (item.deliveries || []).map((d) => ({
      kind: d.recipientKind === "ONCALL" ? "On-call" : "Trusted contact",
      phone: d.phone || "",
      status: d.status || "PENDING",
      attempts: d.attempts ?? 0,
      lastError: d.lastError || ""
    }))
  };
}

/** Fetches a non-JSON body (e.g. CSV) and triggers a browser download. */
async function downloadFile(path, filename, mime) {
  if (USE_MOCKS) {
    const csv = path.includes("/analytics/")
      ? "date,completed,cancelled,total\n2026-08-18,50,11,61\n2026-08-19,58,12,70\n2026-08-20,66,14,80\n"
      : path.includes("/audit/")
      ? "id,createdAt,actor,action,targetType,targetId,details,ip\n1,2026-09-29T10:00:00,S. Mahmoud,PROVIDER_APPROVED,PROVIDER,11,,127.0.0.1\n"
      : "id,providerId,bookingId,bookingAmount,commissionPercent,commissionAmount,status,createdAt,settledAt\n"
        + "1,7,55,100.00,10.00,10.00,DUE,2026-05-20,\n"
        + "2,9,61,450.00,10.00,45.00,SETTLED,2026-05-18,2026-05-24\n";
    saveBlob(new Blob([csv], { type: mime }), filename);
    return { ok: true };
  }
  const { response, blob } = await authedBlob(path);
  if (!response.ok) {
    const error = new Error(`Export failed with status ${response.status}`);
    error.status = response.status;
    throw error;
  }
  saveBlob(blob, filename);
  return { ok: true };
}

function saveBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

/** Monitor chip → GET /admin/bookings params (status / disputed / query). */
const BOOKING_FILTER_STATUS = { Cancelled: "CANCELLED", "No-show": "NO_SHOW", Completed: "COMPLETED" };
function bookingParams(query, filter, extra = {}) {
  const qs = new URLSearchParams(extra);
  if (query.trim()) qs.set("query", query.trim());
  if (filter === "Disputes") qs.set("disputed", "true");
  if (BOOKING_FILTER_STATUS[filter]) qs.set("status", BOOKING_FILTER_STATUS[filter]);
  return qs.toString();
}

function normalizeList(payload) {
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload?.content)) return payload.content;
  if (Array.isArray(payload?.data?.content)) return payload.data.content;
  if (Array.isArray(payload?.data)) return payload.data;
  return [];
}

function formatMoney(value) {
  const amount = Number(value || 0);
  if (amount >= 1000000) return `${(amount / 1000000).toFixed(2)}M`;
  if (amount >= 1000) return `${Math.round(amount).toLocaleString()}`;
  return amount.toLocaleString();
}

function formatWhen(value) {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return date.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

/** "+18.4%" / "-3.1%" against the previous window; "" when there is nothing to compare. */
export function pctDelta(current, previous) {
  const prev = Number(previous || 0);
  if (!prev) return "";
  const pct = ((Number(current || 0) - prev) / prev) * 100;
  return `${pct >= 0 ? "+" : ""}${pct.toFixed(1)}%`;
}

function normalizeDashboard(data) {
  if (data?.stats && Array.isArray(data.stats)) return data;
  const totalRevenue = Number(data?.totalRevenue ?? 0);
  const completed = Number(data?.completedBookings || 0);
  const totalProviders = Number(data?.totalProviders || 0);
  const avg = completed > 0 ? totalRevenue / completed : 0;
  // Windowed counts (AdminDashboardDto, by creation time in Cairo).
  const today = Number(data?.bookingsToday || 0);
  const week = Number(data?.bookingsLast7Days || 0);
  const newCustomers = Number(data?.newCustomersLast30Days || 0);
  const bookings30 = Number(data?.bookingsLast30Days || 0);
  const revenue30 = Number(data?.revenueLast30Days ?? 0);
  const verified30 = Number(data?.providersVerifiedLast30Days || 0);
  const customers = Number(data?.totalCustomers || 0);
  return {
    pendingVerification: Number(data?.pendingVerification || 0),
    openComplaints: Number(data?.openComplaints || 0),
    openDisputes: Number(data?.openDisputes || 0),
    overdueSettlements: Number(data?.overdueSettlements || 0),
    openSos: Number(data?.openSos || 0),
    highPriorityComplaints: Number(data?.highPriorityComplaints || 0),
    totalAccounts: customers + totalProviders,
    // Kit tiles: headline value + green delta (vs the previous 30 days).
    stats: [
      { label: "Customers", value: customers.toLocaleString(), delta: pctDelta(customers, customers - newCustomers), sub: `+${newCustomers.toLocaleString()} in 30 days · ${totalProviders.toLocaleString()} providers`, icon: "Users" },
      { label: "Verified providers", value: Number(data?.approvedProviders || 0).toLocaleString(), delta: verified30 > 0 ? `+${verified30.toLocaleString()}` : "", sub: `${data?.pendingVerification || 0} pending review`, icon: "BadgeCheck" },
      { label: "Bookings · 30d", value: bookings30.toLocaleString(), delta: pctDelta(bookings30, data?.bookingsPrevious30Days), sub: `${today.toLocaleString()} today · ${week.toLocaleString()} in 7 days`, icon: "CalendarCheck" },
      { label: "GMV · 30d (EGP)", value: formatMoney(revenue30), delta: pctDelta(revenue30, data?.revenuePrevious30Days), sub: completed > 0 ? `avg EGP ${Math.round(avg).toLocaleString()} per booking · ${formatMoney(totalRevenue)} all time` : "from completed bookings", icon: "Banknote" }
    ]
  };
}

function normalizeVerification(item) {
  return {
    id: item.id,
    name: item.businessName || item.ownerName || "Provider",
    ownerName: item.ownerName || "",
    category: item.primaryCategory || "Provider",
    city: item.city || "-",
    submitted: formatWhen(item.submittedAt),
    documents: ["ID front", "ID back", "Live selfie"].filter((_, index) => [
      item.nationalIdFrontPath,
      item.nationalIdBackPath,
      item.selfiePath
    ][index]).join(", ") || "Documents",
    status: String(item.verificationStatus || "PENDING").replace("PENDING_VERIFICATION", "PENDING"),
    palette: "plum",
    risk: item.rejectionReason || "Low",
    verificationNote: item.verificationNote || "",
    // Business profile rows (ADMIN-04).
    business: {
      coordinates: item.latitude != null && item.longitude != null
        ? `${Number(item.latitude).toFixed(4)}, ${Number(item.longitude).toFixed(4)}` : "",
      services: item.serviceCount
        ? `${item.serviceCount} service${item.serviceCount === 1 ? "" : "s"}${item.minServicePrice != null
          ? ` · EGP ${Number(item.minServicePrice).toLocaleString()}${Number(item.maxServicePrice) !== Number(item.minServicePrice) ? `–${Number(item.maxServicePrice).toLocaleString()}` : ""}` : ""}`
        : "",
      gallery: `${item.galleryCount || 0} uploaded`,
      terms: item.acceptedTermsVersion ? `v${item.acceptedTermsVersion}${item.termsAcceptedAt ? ` · ${formatWhen(item.termsAcceptedAt)}` : ""}` : ""
    },
    documentPaths: {
      nationalIdFrontPath: item.nationalIdFrontPath,
      nationalIdBackPath: item.nationalIdBackPath,
      selfiePath: item.selfiePath
    }
  };
}

function normalizeComplaint(item) {
  return {
    id: item.id,
    customer: item.reporterName || "Customer",
    provider: item.targetProviderName || item.targetUserName || "-",
    subject: item.description || item.category || "Complaint",
    when: formatWhen(item.createdAt),
    status: item.status || "OPEN",
    flagged: item.flagged === true,
    // ComplaintDto.priority (HIGH / MEDIUM / LOW); older servers only send flagged.
    priority: { HIGH: "High", MEDIUM: "Medium", LOW: "Low" }[item.priority] || (item.flagged ? "High" : "Medium"),
    category: item.category || "",
    description: item.description || "",
    adminNotes: item.adminNotes || "",
    bookingId: item.bookingId ?? null
  };
}

function normalizeUser(item) {
  const role = item.role || "CUSTOMER";
  const providerStatus = item.providerStatus || null;
  let status = item.status;
  if (!status) {
    if (item.active === false) status = "SUSPENDED";
    else if (providerStatus === "SUSPENDED") status = "SUSPENDED";
    else if (providerStatus === "REJECTED") status = "REJECTED";
    else if (providerStatus && providerStatus !== "APPROVED" && role === "PROVIDER") status = "PENDING";
    else status = "ACTIVE";
  }
  return {
    id: item.id,
    fullName: item.fullName || item.email || item.phone || "User",
    role,
    email: item.email || "-",
    phone: item.phone || null,
    bookings: item.bookingCount ?? item.bookings ?? 0,
    joined: item.joined || formatWhen(item.createdAt),
    status,
    active: item.active !== false,
    providerStatus,
    permissions: Array.isArray(item.permissions) ? item.permissions : [],
    providerProfileId: item.providerProfileId ?? null,
    palette: role === "PROVIDER" ? "plum" : role === "ADMIN" ? "gold" : "rose"
  };
}

function normalizeModeration(item) {
  const rawType = String(item.targetType || item.type || "IMAGE").toUpperCase();
  const type = rawType.includes("REVIEW") ? "REVIEW" : rawType.includes("IMAGE") || rawType.includes("PHOTO") ? "IMAGE" : rawType;
  return {
    id: item.id,
    type,
    provider: item.provider || item.providerName || `${type === "REVIEW" ? "Reported review" : type === "IMAGE" ? "Reported photo" : "Case"} #${item.targetId || item.id}`,
    reason: item.reason || item.adminNotes || "Moderation case",
    when: item.when || formatWhen(item.createdAt),
    text: item.text || item.adminNotes,
    // ModerationCaseDto.imageUrl: the reported photo itself.
    imageUrl: mediaUrl(item.imageUrl),
    imageHidden: !!item.imageHidden
  };
}

function normalizeSettlement(item) {
  // Tolerant of both the backend ledger shape and the local mock shape.
  const balance = item.commissionAmount ?? item.dueAmount ?? item.balance ?? 0;
  const status = item.status && item.status !== "DUE"
    ? item.status
    : Number(balance) > 0 ? "OK" : "SETTLED";
  return {
    id: item.id ?? item.providerId,
    providerId: item.providerId ?? null,
    provider: item.providerName || item.provider || `Provider #${item.providerId || "-"}`,
    balance,
    status: status === "OVERDUE" ? "OVERDUE" : status === "SETTLED" ? "SETTLED" : "OK",
    due: item.due || (item.settledAt ? formatWhen(item.settledAt) : formatWhen(item.createdAt))
  };
}

function normalizeBooking(item) {
  // Tolerant of both the backend BookingDto and the local mock shape.
  const amount = Number(
    item.totalPrice ?? item.amount ?? String(item.total || "").replace(/[^\d.]/g, "") ?? 0
  ) || 0;
  const paymentStatus = item.paymentStatus || (item.dispute ? "DISPUTED" : "UNPAID");
  return {
    id: item.id,
    ref: typeof item.id === "string" && item.id.startsWith("BK") ? item.id : (item.id != null ? `BK-${item.id}` : "BK-—"),
    customer: item.customer?.fullName || item.customer || "Customer",
    provider: item.provider?.businessName || item.provider || "Provider",
    service: item.service?.name || item.service || "Service",
    status: item.status || "PENDING",
    paymentStatus,
    dispute: paymentStatus === "DISPUTED" || item.dispute === true,
    commissionAmount: item.commissionAmount != null ? Number(item.commissionAmount) : null,
    homeService: item.homeService === true,
    travelFee: item.travelFee != null ? Number(item.travelFee) : null,
    penaltyApplied: item.penaltyApplied === true,
    date: item.date || `${formatWhen(item.bookingDate)} ${item.startTime || ""}`.trim(),
    amount,
    total: item.total || `EGP ${amount.toFixed(2)}`,
    // lifecycle detail (for the row timeline)
    createdAt: item.createdAt || null,
    checkedInAt: item.checkedInAt || null,
    cancelledAt: item.cancelledAt || null,
    cancelledBy: item.cancelledBy || null,
    cancellationReason: item.cancellationReason || null,
    rejectionReason: item.rejectionReason || null,
    proposedDate: item.proposedDate || null,
    proposedStartTime: item.proposedStartTime || null
  };
}

function normalizeReview(item) {
  return {
    id: item.id,
    from: item.user?.fullName || item.from || "User",
    to: item.provider?.businessName || item.to || "Provider",
    rating: item.rating || 0,
    text: item.comment || item.text || "-",
    // AD-09: the backend sends a boolean `hidden` (no status field); derive the state from it.
    hidden: item.hidden === true,
    status: item.hidden === true ? "HIDDEN" : (item.status || "VISIBLE")
  };
}

function normalizeReviewReport(item) {
  const rating = Number(item.rating || 0);
  return {
    id: item.moderationCaseId ?? item.id,
    reviewId: item.reviewId ?? item.id,
    from: item.authorName || "User",
    to: item.providerName || "Provider",
    rating,
    text: item.comment || "-",
    reason: item.reason || "Reported by a user",
    hidden: item.hidden === true,
    lowRating: rating > 0 && rating <= 2,
    when: formatWhen(item.createdAt)
  };
}

function normalizeChatReport(item) {
  return {
    id: item.moderationCaseId ?? item.id,
    messageId: item.messageId,
    bookingId: item.bookingId,
    from: item.senderName || "User",
    text: item.message || "-",
    reason: item.reason || "Reported by a user",
    removed: item.removed === true,
    when: formatWhen(item.createdAt)
  };
}

function normalizeFlag(item) {
  return {
    id: item.id,
    type: item.targetProviderId ? "provider" : "customer",
    name: item.targetProviderName || item.targetUserName || item.reporterName || "Flagged party",
    reason: item.description || item.category || "Flagged for review",
    reporter: item.reporterName || "System",
    // A provider complaint only carries targetProviderId; targetProviderOwnerUserId
    // is that provider's own account, so "Send warning" (a user-scoped action) can
    // still reach a flagged provider, not just flagged customers.
    targetUserId: item.targetUserId ?? item.targetProviderOwnerUserId ?? null,
    targetProviderId: item.targetProviderId ?? null,
    when: item.when || formatWhen(item.createdAt)
  };
}

function normalizeAnalyticsPoint(item) {
  return {
    date: item.date,
    completed: Number(item.completed || 0),
    cancelled: Number(item.cancelled || 0),
    total: Number(item.total || 0)
  };
}

function normalizeAudit(item) {
  const action = String(item.action || "");
  let tone = "info";
  if (/APPROVED|REACTIVATED|CONFIRMED|RESTORED/.test(action)) tone = "success";
  else if (/REJECTED|SUSPENDED|DELETED|DEACTIVATED|HIDDEN|WARNED|ACTIONED/.test(action)) tone = "danger";
  else if (/INFO_REQUESTED|UPDATED|DISMISSED/.test(action)) tone = "warn";
  return {
    id: item.id,
    actor: item.actor || "system",
    action,
    target: item.target || "—",
    ip: item.ipAddress || "—",
    when: formatWhen(item.createdAt),
    tone
  };
}

const mock = {
  user: { id: "admin-1", fullName: "S. Mahmoud", role: "ADMIN", location: "Cairo HQ", permissions: ["SUPER_ADMIN", "SUPPORT", "FINANCE"] },
  commissionPercent: 10,
  bookingRules: { cancellationCutoffHours: 2, providerCancelPenaltyPercent: 15, responseWindowMinutes: 120 },
  providerOverrides: {
    11: { commissionOverridePercent: 8, cancellationCutoffHoursOverride: null, providerCancelPenaltyPercentOverride: null, responseWindowMinutesOverride: null },
    12: { commissionOverridePercent: 12.5, cancellationCutoffHoursOverride: 4, providerCancelPenaltyPercentOverride: null, responseWindowMinutesOverride: 45 }
  },
  safety: [
    { id: 41, bookingId: 1182, bookingStatus: "IN_PROGRESS", homeService: true, address: "Street 9, Maadi, Cairo", actorId: 21, actorName: "Mariam Adel", actorRole: "CUSTOMER", actorPhone: "+201001234567", customerName: "Mariam Adel", customerPhone: "+201001234567", providerName: "Layla Beauty", providerPhone: "+201112223334", latitude: 29.9602, longitude: 31.2569, notes: "Provider is refusing to leave", resolved: false, createdAt: new Date(Date.now() - 6 * 60000).toISOString() }
  ],
  dashboard: {
    pendingVerification: 4, openComplaints: 2, openDisputes: 1, overdueSettlements: 2, openSos: 1,
    stats: [
      { label: "Customers", value: "12,840", delta: "+8.2%", icon: "Users" },
      { label: "Verified providers", value: "486", delta: "+12", icon: "BadgeCheck" },
      { label: "Bookings 30d", value: "3,217", delta: "+18.4%", icon: "CalendarCheck" },
      { label: "GMV 30d (EGP)", value: "1.42M", delta: "+22.6%", icon: "Banknote" }
    ],
    activity: [
      { icon: "BadgeCheck", color: "success", text: "Approved Salma Beauty Lounge", when: "3m ago" },
      { icon: "UserPlus", color: "info", text: "36 new customer signups today", when: "1h ago" },
      { icon: "Flag", color: "danger", text: "New complaint from Karim Helmi", when: "2h ago" },
      { icon: "XCircle", color: "danger", text: "Rejected Yousef Beauty - invalid ID", when: "4h ago" },
      { icon: "Star", color: "gold", text: "128 reviews submitted this week", when: "Today" },
      { icon: "Banknote", color: "success", text: "GMV crossed EGP 1.4M this month", when: "Today" }
    ]
  },
  verifications: [
    { id: "pv1", name: "Salma Beauty Lounge", category: "Hair · Nails", city: "New Cairo", submitted: "2 hours ago", documents: "ID front, ID back, Live selfie", status: "PENDING", palette: "plum", risk: "Low" },
    { id: "pv2", name: "Omar — Barber", category: "Hair · Men", city: "Maadi", submitted: "5 hours ago", documents: "ID front, ID back, Live selfie", status: "PENDING", palette: "gold", risk: "Low" },
    { id: "pv3", name: "Hala Skin Studio", category: "Skin · Spa", city: "Zamalek", submitted: "Yesterday", documents: "ID front, ID back, Live selfie", status: "PENDING", palette: "rose", risk: "Medium" },
    { id: "pv4", name: "Mona Lashes & Brows", category: "Lashes", city: "Heliopolis", submitted: "2 days ago", documents: "ID front, ID back, Live selfie · awaiting selfie reshoot", status: "NEEDS_RESUBMIT", palette: "plum", risk: "Selfie unclear", flag: "Selfie unclear — request reshoot" }
  ],
  complaints: [
    { id: "c1", customer: "Layla Hassan", provider: "Nadia Studio", subject: "Service delivered late", when: "2 days ago", status: "OPEN", priority: "High" },
    { id: "c2", customer: "Yara Aboud", provider: "Maadi Hammam", subject: "Booking double-charged", when: "3 days ago", status: "UNDER_REVIEW", priority: "High" },
    { id: "c3", customer: "Karim Helmi", provider: "Omar Barber", subject: "Rude staff", when: "5 days ago", status: "OPEN", priority: "Medium" },
    { id: "c4", customer: "Aya Salem", provider: "Layla Beauty", subject: "No-show by provider", when: "1 week ago", status: "RESOLVED", priority: "Low" }
  ],
  users: [
    { id: "u1", fullName: "Layla Hassan", role: "CUSTOMER", email: "layla@example.com", bookings: 12, joined: "Jan 2026", status: "ACTIVE", palette: "rose" },
    { id: "u2", fullName: "Nadia Studio", role: "PROVIDER", email: "nadia.studio@aiwa.com", bookings: 312, joined: "Dec 2025", status: "ACTIVE", palette: "plum" },
    { id: "u3", fullName: "Karim Helmi", role: "CUSTOMER", email: "karim@example.com", bookings: 4, joined: "Mar 2026", status: "FLAGGED", palette: "gold" },
    { id: "u4", fullName: "Omar — Barber", role: "PROVIDER", email: "omar.barber@aiwa.com", bookings: 96, joined: "Feb 2026", status: "ACTIVE", palette: "plum" },
    { id: "u5", fullName: "Yara Aboud", role: "CUSTOMER", email: "yara@example.com", bookings: 1, joined: "May 2026", status: "ACTIVE", palette: "rose" },
    { id: "u6", fullName: "Yousef Beauty", role: "PROVIDER", email: "yousef@aiwa.com", bookings: 0, joined: "May 2026", status: "SUSPENDED", palette: "gold" },
    { id: "u7", fullName: "Mona Farouk", role: "ADMIN", email: "mona@aiwa.com", bookings: "—", joined: "Jan 2026", status: "ACTIVE", permissions: ["SUPER_ADMIN"] },
    { id: "u8", fullName: "Yasmin Nabil", role: "ADMIN", email: "yasmin@aiwa.com", bookings: "—", joined: "Mar 2026", status: "ACTIVE", permissions: ["SUPPORT", "FINANCE"] }
  ],
  bookings: [
    { id: "BK-2841", customer: "Hana Kamal", provider: "Nadia Studio", service: "Balayage", status: "IN_PROGRESS", date: "Today · 4:00 PM", total: "EGP 1,100", amount: 1100, paymentStatus: "UNPAID", homeService: true },
    { id: "BK-2840", customer: "Rana Mostafa", provider: "Layla Beauty", service: "Gel Manicure", status: "COMPLETED", date: "Today · 2:30 PM", total: "EGP 180", amount: 180, paymentStatus: "CASH_CONFIRMED", commissionAmount: 18 },
    { id: "BK-2839", customer: "Karim Helmi", provider: "Omar Barber", service: "Fade & Beard", status: "CANCELLED", date: "Today · 1:00 PM", total: "EGP 120", amount: 120, penaltyApplied: true },
    { id: "BK-2838", customer: "Dalia Saad", provider: "Maadi Hammam", service: "Deep Tissue", status: "COMPLETED", date: "Today · 11:00 AM", total: "EGP 450", amount: 450, paymentStatus: "DISPUTED", dispute: true },
    { id: "BK-2837", customer: "Nour Hassan", provider: "Nadia Studio", service: "Haircut & Style", status: "COMPLETED", date: "Yesterday · 6:00 PM", total: "EGP 350", amount: 350, paymentStatus: "CASH_CONFIRMED", commissionAmount: 35 },
    { id: "BK-2836", customer: "Salma Adel", provider: "Mariam Lashes", service: "Russian Volume", status: "NO_SHOW", date: "Yesterday · 3:00 PM", total: "EGP 400", amount: 400, penaltyApplied: true },
    { id: "BK-2834", customer: "Yasmin Ezz", provider: "Hala Skin Studio", service: "Hydrafacial", status: "REJECTED", date: "2 days ago", total: "EGP 700", amount: 700 }
  ],
  reviews: [
    { id: "r1", from: "Layla Hassan", to: "Nadia Studio", rating: 5, text: "Great result and very clean setup.", status: "VISIBLE" },
    { id: "r2", from: "Karim Helmi", to: "Omar Barber", rating: 2, text: "Late arrival and poor communication.", status: "REPORTED" },
    { id: "r3", from: "Nadia Studio", to: "Customer", rating: 5, text: "Respectful and clear about requirements.", status: "VISIBLE" }
  ],
  moderation: [
    { id: "m1", type: "IMAGE", provider: "Hala Skin Studio", reason: "Reported: unrelated / low quality photo", when: "3 hours ago" },
    { id: "m2", type: "REVIEW", provider: "Omar Barber", reason: "Reported: abusive language toward provider", when: "1 day ago", text: "Terrible service, never again." },
    { id: "m3", type: "IMAGE", provider: "Maadi Hammam", reason: "Reported: not the actual venue", when: "2 days ago" }
  ],
  chatReports: [
    { id: "cr1", moderationCaseId: 1, messageId: 3, bookingId: 2, senderName: "Nadia Studio",
      message: "Here's my personal number, message me there instead.",
      reason: "Reported: asking to move payment off-platform", removed: false, createdAt: "2026-09-08T12:00:00" }
  ],
  reviewReports: [
    { moderationCaseId: "rr1", reviewId: "r2", authorName: "Karim Helmi", providerName: "Omar Barber", rating: 2, comment: "Late arrival and poor communication. Would not recommend.", reason: "Abusive language toward provider", hidden: false, createdAt: "2026-09-06T12:20:00" },
    { moderationCaseId: "rr2", reviewId: "r7", authorName: "Anonymous", providerName: "Hala Skin Studio", rating: 1, comment: "Total scam, avoid this place at all costs!!!", reason: "Suspected fake / competitor review", hidden: false, createdAt: "2026-09-05T09:05:00" },
    { moderationCaseId: "rr3", reviewId: "r9", authorName: "Dalia Saad", providerName: "Maadi Hammam", rating: 2, comment: "Room was not clean when I arrived.", reason: "Provider disputes accuracy", hidden: true, createdAt: "2026-09-03T18:40:00" }
  ],
  verificationsByStatus: {
    APPROVED: [
      { id: "va1", businessName: "Salma Beauty Lounge", ownerName: "Salma Ibrahim", primaryCategory: "HAIR", city: "New Cairo", verificationStatus: "APPROVED", submittedAt: "2026-08-20T10:00:00" },
      { id: "va2", businessName: "Nadia Studio", ownerName: "Nadia Fouad", primaryCategory: "HAIR", city: "Maadi", verificationStatus: "APPROVED", submittedAt: "2026-07-14T10:00:00" }
    ],
    REJECTED: [
      { id: "vr1", businessName: "Yousef Beauty", ownerName: "Yousef Adel", primaryCategory: "SKINCARE", city: "Nasr City", verificationStatus: "REJECTED", rejectionReason: "National ID photo unreadable", submittedAt: "2026-08-28T10:00:00" }
    ],
    SUSPENDED: [
      { id: "vs1", businessName: "Cairo Glow Spa", ownerName: "Mariam Nabil", primaryCategory: "SPA", city: "Zamalek", verificationStatus: "SUSPENDED", submittedAt: "2026-06-01T10:00:00" }
    ]
  },
  audit: [
    { id: "a1", actor: "AIWA Admin", action: "PROVIDER_APPROVED", target: "Nadia Studio", createdAt: "2026-09-01T16:12:00", ipAddress: "41.35.22.8" },
    { id: "a2", actor: "AIWA Admin", action: "REVIEW_HIDDEN", target: "review #8821", createdAt: "2026-09-01T15:40:00", ipAddress: "41.35.22.8" },
    { id: "a3", actor: "Mona Farouk", action: "ADMIN_CREATED", target: "admin2@aiwa.com", createdAt: "2026-09-01T11:02:00", ipAddress: "156.200.4.1" },
    { id: "a4", actor: "Mona Farouk", action: "SETTLEMENT_CONFIRMED", target: "ledger #204", createdAt: "2026-08-31T18:20:00", ipAddress: "156.200.4.1" },
    { id: "a5", actor: "AIWA Admin", action: "USER_DEACTIVATED", target: "Karim Helmi", createdAt: "2026-08-31T14:15:00", ipAddress: "41.35.22.8" },
    { id: "a6", actor: "AIWA Admin", action: "MODERATION_ACTIONED", target: "IMAGE #12", createdAt: "2026-08-30T09:05:00", ipAddress: "41.35.22.8" },
    { id: "a7", actor: "Mona Farouk", action: "COMMISSION_RATE_UPDATED", target: "12%", createdAt: "2026-08-20T10:00:00", ipAddress: "156.200.4.1" }
  ],
  settlements: [
    { id: "s1", providerId: 11, provider: "Nadia Studio", balance: 128.4, status: "OK", due: "May 24" },
    { id: "s2", providerId: 12, provider: "Maadi Hammam", balance: 612.0, status: "OVERDUE", due: "May 17" },
    { id: "s3", providerId: 13, provider: "Omar Barber", balance: 45.0, status: "OK", due: "May 24" },
    { id: "s4", providerId: 14, provider: "Layla Beauty", balance: 0, status: "SETTLED", due: "-" }
  ],
  settlementRows: [
    { providerId: 11, providerName: "Nadia Studio", commissionPercent: 8, commissionOverridePercent: 8, platformCommissionPercent: 10, grossAmount: 856, balanceOwed: 128.4, status: "WITHIN_LIMIT", settlementPaused: false, dueDate: "2026-05-24T00:00:00" },
    { providerId: 12, providerName: "Maadi Hammam", commissionPercent: 12.5, commissionOverridePercent: 12.5, platformCommissionPercent: 10, grossAmount: 4080, balanceOwed: 612, status: "OVERDUE", settlementPaused: true, dueDate: "2026-05-17T00:00:00" },
    { providerId: 13, providerName: "Omar — Barber", commissionPercent: 10, commissionOverridePercent: null, platformCommissionPercent: 10, grossAmount: 300, balanceOwed: 45, status: "WITHIN_LIMIT", settlementPaused: false, dueDate: "2026-05-24T00:00:00" },
    { providerId: 14, providerName: "Layla Beauty", commissionPercent: 10, commissionOverridePercent: null, platformCommissionPercent: 10, grossAmount: 0, balanceOwed: 0, status: "SETTLED", settlementPaused: false, dueDate: null }
  ],
  termsVersions: [
    { id: 3, version: "1.1.0", type: "CUSTOMER_TERMS", active: true, createdAt: "2026-05-20T10:00:00", contentEn: "AIWA connects customers with verified beauty and grooming providers across Egypt. By using AIWA you agree to the booking, cancellation, home-service safety and cash-payment terms set out below, including provider cancel penalties and platform commission on cash bookings." },
    { id: 2, version: "1.0.2", type: "CUSTOMER_TERMS", active: false, createdAt: "2026-03-02T10:00:00", contentEn: "Clarified no-show handling and cash-payment confirmation." },
    { id: 1, version: "1.0.0", type: "CUSTOMER_TERMS", active: false, createdAt: "2026-01-14T10:00:00", contentEn: "Initial launch terms." }
  ],
  supportSettings: {
    whatsappNumber: "+201005550000", whatsappNumberDisplay: "+20 100 555 0000",
    supportEmail: "support@aiwa.com", availabilityHoursEn: "Daily · 9:00 AM – 11:00 PM", whatsappEnabled: true,
    numbers: [
      { label: "General", number: "+201005550000", displayNumber: "+20 100 555 0000", primary: true, enabled: true },
      { label: "Payments & settlements", number: "+201005550100", displayNumber: "+20 100 555 0100", primary: false, enabled: true },
      { label: "Alexandria line", number: "+201005550200", displayNumber: "+20 100 555 0200", primary: false, enabled: false }
    ]
  }
};

async function mockRequest(path, options = {}) {
  await new Promise((resolve) => setTimeout(resolve, 180));

  if (path === "/auth/login") {
    return { accessToken: "mock-admin-access-token", refreshToken: "mock-refresh-token", user: mock.user };
  }
  if (path === "/auth/me") return { user: mock.user };
  if (path === "/auth/logout") return { success: true };
  if (path === "/auth/2fa/status") return { enabled: mock.totpEnabled ?? false };
  if (path === "/auth/2fa/setup") return { secret: "MOCKSECRETMOCKSECRET", otpAuthUri: "otpauth://totp/AIWA:admin@aiwa.com?secret=MOCKSECRETMOCKSECRET&issuer=AIWA&algorithm=SHA1&digits=6&period=30" };
  if (path === "/auth/2fa/enable") { mock.totpEnabled = true; return { success: true }; }
  if (path === "/auth/2fa/disable") { mock.totpEnabled = false; return { success: true }; }
  if (path === "/auth/2fa/verify") return { accessToken: "mock-admin-access-token", refreshToken: "mock-refresh-token", user: mock.user };
  if (path === "/auth/2fa/server-time") return { epochMillis: Date.now(), iso: new Date().toISOString(), totpStepSeconds: 30, driftToleranceSeconds: 30 };
  if (path === "/admin/dashboard") return mock.dashboard;
  if (path.startsWith("/admin/verification/counts")) return { pending: mock.verifications.length, approved: mock.verificationsByStatus.APPROVED.length, rejected: mock.verificationsByStatus.REJECTED.length, suspended: mock.verificationsByStatus.SUSPENDED.length };
  if (path.startsWith("/admin/verification?")) {
    const status = new URLSearchParams(path.split("?")[1] || "").get("status");
    if (status && status !== "PENDING_VERIFICATION" && status !== "PENDING") return mock.verificationsByStatus[status] || [];
    return mock.verifications;
  }
  if (path.startsWith("/admin/verification")) return mock.verifications;
  if (path.startsWith("/admin/complaints") && path.includes("/flag")) return { success: true };
  if (path.startsWith("/admin/complaints")) return mock.complaints;
  if (path.match(/^\/admin\/users\/[^/?]+\/activity$/)) {
    return {
      bookings: [
        { id: 2841, reference: "BK-2841", counterparty: "Nadia Studio", service: "Balayage", status: "COMPLETED", paymentStatus: "CASH_CONFIRMED", amount: 1100, date: "2026-09-06", createdAt: "2026-09-05T10:00:00" },
        { id: 2799, reference: "BK-2799", counterparty: "Omar Barber", service: "Fade & Beard", status: "CANCELLED", paymentStatus: "UNPAID", amount: 120, date: "2026-08-21", createdAt: "2026-08-20T09:00:00" }
      ],
      reviews: [
        { id: 71, providerName: "Nadia Studio", rating: 5, comment: "Great result and very clean setup.", hidden: false, createdAt: "2026-09-06T18:00:00" }
      ],
      complaints: [
        { id: 12, subject: "Service delivered late", status: "RESOLVED", flagged: false, createdAt: "2026-08-22T12:00:00" }
      ]
    };
  }
  if (path.match(/^\/admin\/users\/[^/?]+$/) && (options.method || "GET") === "GET") {
    const id = path.split("/").pop();
    const u = mock.users.find((x) => String(x.id) === String(id)) || mock.users[0];
    return {
      ...u,
      active: u.status !== "SUSPENDED",
      providerProfileId: u.role === "PROVIDER" ? Number(String(u.id).replace(/\D/g, "")) || 11 : null,
      providerStatus: u.role === "PROVIDER" ? (u.status === "SUSPENDED" ? "SUSPENDED" : "APPROVED") : null,
      bookingCount: u.bookings
    };
  }
  if (path.match(/^\/providers\/[^/?]+$/) && (options.method || "GET") === "GET") {
    return {
      id: Number(path.split("/").pop()) || 11, businessName: "Nadia Studio",
      bio: "Trusted hair specialists in New Cairo.", address: "New Cairo, Cairo",
      primaryCategory: "HAIR", averageRating: 4.8, totalReviews: 312,
      verificationStatus: "APPROVED", providerType: "INDIVIDUAL",
      vacationMode: false, offlineMode: false, settlementPaused: false, travelBufferMinutes: 30,
      owner: { fullName: "Nadia Studio", email: "nadia.studio@aiwa.com", phone: "+201112223344", active: true },
      services: [
        { id: 1, name: "Balayage", price: 1100, durationMinutes: 150, category: "HAIR", active: true },
        { id: 2, name: "Haircut & Style", price: 350, durationMinutes: 60, category: "HAIR", active: true }
      ],
      galleryImages: []
    };
  }
  if (path.startsWith("/admin/users")) {
    if (options.method === "POST") {
      const body = JSON.parse(options.body || "{}");
      return { id: `admin-${Date.now()}`, role: "ADMIN", status: "ACTIVE", ...body, permissions: body.permissions || [] };
    }
    if (options.method === "PATCH" && path.includes("/permissions")) {
      const perms = [...new URLSearchParams(path.split("?")[1] || "").getAll("permissions")];
      return { id: path.split("/")[3], role: "ADMIN", permissions: perms };
    }
    if (options.method === "PATCH" && (path.includes("/deactivate") || path.includes("/reactivate"))) {
      const id = path.split("/")[3];
      const u = mock.users.find((x) => String(x.id) === String(id));
      if (u) u.status = path.includes("/reactivate") ? "ACTIVE" : "SUSPENDED";
      return { success: true };
    }
    if (options.method === "POST" && path.includes("/reset-password")) {
      return { delivery: "SMS", sentTo: "***4477" };
    }
    if (options.method === "PATCH" && path.match(/^\/admin\/users\/[^/?]+$/)) {
      const id = path.split("/").pop();
      const u = mock.users.find((x) => String(x.id) === String(id)) || mock.users[0];
      const body = JSON.parse(options.body || "{}");
      Object.assign(u, body);
      return { ...u };
    }
    // Same contract as GET /admin/users: role + q combine, newest first, paged.
    const qs = new URLSearchParams(path.split("?")[1] || "");
    const role = (qs.get("role") || "").toUpperCase();
    const q = (qs.get("q") || "").toLowerCase();
    const page = Number(qs.get("page") || 0);
    const size = Number(qs.get("size") || 20);
    const hits = mock.users.filter((u) => (!role || u.role === role)
      && (!q || [u.fullName, u.email, u.phone].some((v) => String(v || "").toLowerCase().includes(q))));
    return { content: hits.slice(page * size, (page + 1) * size), totalPages: Math.max(1, Math.ceil(hits.length / size)), totalElements: hits.length, number: page };
  }
  if (path.split("?")[0] === "/admin/moderation") return mock.moderation;
  if (path.startsWith("/admin/audit")) {
    return { content: mock.audit, totalPages: 1, number: 0, totalElements: mock.audit.length };
  }
  if (path.startsWith("/admin/inbox")) {
    // Mock inbox seed — a mix of kinds so the bell shows something in mock mode.
    return [
      { id: "complaint-12", kind: "COMPLAINT", title: "New complaint", body: "Layla Hassan · PROVIDER — Service delivered late", createdAt: new Date(Date.now() - 5*60*1000).toISOString(), targetRoute: "complaints" },
      { id: "verification-3", kind: "VERIFICATION", title: "Provider awaiting verification", body: "Hala Skin Studio · Heliopolis", createdAt: new Date(Date.now() - 42*60*1000).toISOString(), targetRoute: "verifications" },
      { id: "moderation-7", kind: "REPORTED_REVIEW", title: "Review reported", body: "Reported: abusive language toward provider", createdAt: new Date(Date.now() - 2*3600*1000).toISOString(), targetRoute: "moderation" },
      { id: "dispute-2838", kind: "DISPUTE", title: "Payment dispute", body: "BK-2838 · Dalia Saad → Maadi Hammam", createdAt: new Date(Date.now() - 4*3600*1000).toISOString(), targetRoute: "bookings" }
    ];
  }
  if (path.split("?")[0] === "/admin/reviews/moderation") return mock.reviewReports;
  if (path.match(/^\/admin\/reviews\/moderation\/[^/]+\/resolve/) && options.method === "POST") {
    const id = path.split("/")[4];
    mock.reviewReports = mock.reviewReports.filter((r) => String(r.moderationCaseId) !== String(id));
    return { success: true };
  }
  if (path.split("?")[0] === "/admin/chat/moderation") return mock.chatReports;
  if (path.match(/^\/admin\/chat\/moderation\/[^/]+\/resolve/) && options.method === "POST") {
    const id = path.split("/")[4];
    mock.chatReports = mock.chatReports.filter((r) => String(r.moderationCaseId) !== String(id));
    return { success: true };
  }
  if (path.startsWith("/admin/reviews/") && path.includes("/visibility")) return { success: true };
  if (path.startsWith("/admin/verification/counts")) return { pending: 4, approved: 484, rejected: 12, suspended: 3 };
  if (path.startsWith("/admin/analytics/bookings")) {
    const days = Number(new URLSearchParams(path.split("?")[1] || "").get("days")) || 14;
    return Array.from({ length: days }, (_, i) => {
      const total = 60 + Math.round(Math.sin(i / 2) * 20) + i * 6;
      return { date: `2026-08-${String(18 + i).padStart(2, "0")}`, completed: Math.round(total * 0.82), cancelled: Math.round(total * 0.18), total };
    });
  }
  if (path.startsWith("/admin/bookings/") && (path.includes("/force-cancel") || path.includes("/resolve-dispute"))) return { success: true };
  if (path.startsWith("/admin/bookings/") && path.includes("/chat")) {
    return [
      { id: 1, sender: { fullName: "Hana Kamal", role: "CUSTOMER" }, message: "Hi, are you on the way?", createdAt: "2026-09-01T15:40:00" },
      { id: 2, sender: { fullName: "Nadia Studio", role: "PROVIDER" }, message: "Yes, 10 minutes away.", createdAt: "2026-09-01T15:42:00" }
    ];
  }
  if (path.startsWith("/admin/settings/booking-rules")) {
    if (options.method === "PATCH") {
      const qs = new URLSearchParams(path.split("?")[1] || "");
      if (qs.get("cancellationCutoffHours")) mock.bookingRules.cancellationCutoffHours = Number(qs.get("cancellationCutoffHours"));
      if (qs.get("providerCancelPenaltyPercent")) mock.bookingRules.providerCancelPenaltyPercent = Number(qs.get("providerCancelPenaltyPercent"));
      if (qs.get("responseWindowMinutes")) mock.bookingRules.responseWindowMinutes = Number(qs.get("responseWindowMinutes"));
    }
    return { ...mock.bookingRules };
  }
  if (path.startsWith("/terms/latest")) {
    return { id: 1, version: "1.1.0", type: "CUSTOMER_TERMS", active: true,
      contentEn: "AIWA connects customers with verified beauty & grooming providers across Egypt. By using AIWA you agree to the booking, cancellation, home-service safety, and cash-payment terms set out here.", contentAr: "" };
  }
  if (path === "/support/contact") {
    const s = mock.supportSettings;
    const enabled = (s.numbers || []).filter((n) => n.enabled);
    const primary = enabled.find((n) => n.primary) || enabled[0];
    return {
      whatsappNumber: primary?.number || s.whatsappNumber,
      whatsappNumberDisplay: primary?.displayNumber || s.whatsappNumberDisplay,
      supportEmail: s.supportEmail, availabilityHoursEn: s.availabilityHoursEn,
      whatsappEnabled: s.whatsappEnabled, numbers: enabled
    };
  }
  if (path.match(/^\/admin\/providers\/\d+\/staff$/)) {
    return [
      { id: 1, providerId: 11, fullName: "Salma Adel", title: "Senior Stylist", phone: "+201007770001", skills: "Balayage, Color correction", active: true },
      { id: 2, providerId: 11, fullName: "Rania Fathy", title: "Stylist", phone: "+201007770002", skills: "Haircuts, Blowouts", active: true },
      { id: 3, providerId: 11, fullName: "Dina Kamal", title: "Junior Stylist", phone: "+201007770003", skills: "Haircuts", active: false }
    ];
  }
  if (path.match(/^\/admin\/providers\/\d+\/settings$/)) {
    const id = Number(path.split("/")[3]);
    const o = mock.providerOverrides[id] || {};
    const plat = mock.bookingRules;
    return {
      providerId: id, providerName: (mock.settlementRows.find((r) => r.providerId === id) || {}).providerName || `Provider ${id}`,
      commissionOverridePercent: o.commissionOverridePercent ?? null,
      effectiveCommissionPercent: o.commissionOverridePercent ?? mock.commissionPercent ?? 10,
      platformCommissionPercent: mock.commissionPercent ?? 10,
      cancellationCutoffHoursOverride: o.cancellationCutoffHoursOverride ?? null,
      providerCancelPenaltyPercentOverride: o.providerCancelPenaltyPercentOverride ?? null,
      responseWindowMinutesOverride: o.responseWindowMinutesOverride ?? null,
      effectiveCancellationCutoffHours: o.cancellationCutoffHoursOverride ?? plat.cancellationCutoffHours,
      effectiveProviderCancelPenaltyPercent: o.providerCancelPenaltyPercentOverride ?? plat.providerCancelPenaltyPercent,
      effectiveResponseWindowMinutes: o.responseWindowMinutesOverride ?? plat.responseWindowMinutes,
      platformCancellationCutoffHours: plat.cancellationCutoffHours,
      platformProviderCancelPenaltyPercent: plat.providerCancelPenaltyPercent,
      platformResponseWindowMinutes: plat.responseWindowMinutes,
      homeServiceTravelFee: o.homeServiceTravelFee ?? null
    };
  }
  if (path.match(/^\/admin\/providers\/\d+\/travel-fee/) && options.method === "PATCH") {
    const id = Number(path.split("/")[3]);
    const qs = new URLSearchParams(path.split("?")[1] || "");
    const o = (mock.providerOverrides[id] = mock.providerOverrides[id] || {});
    o.homeServiceTravelFee = qs.get("clear") === "true" ? null : Number(qs.get("amount"));
    return mockRequest(`/admin/providers/${id}/settings`, {});
  }
  if (path.match(/^\/admin\/providers\/\d+\/commission/) && options.method === "PATCH") {
    const id = Number(path.split("/")[3]);
    const qs = new URLSearchParams(path.split("?")[1] || "");
    const o = (mock.providerOverrides[id] = mock.providerOverrides[id] || {});
    o.commissionOverridePercent = qs.get("clear") === "true" ? null : Number(qs.get("percent"));
    const row = mock.settlementRows.find((r) => r.providerId === id);
    if (row) { row.commissionOverridePercent = o.commissionOverridePercent; row.commissionPercent = o.commissionOverridePercent ?? (mock.commissionPercent ?? 10); }
    return mockRequest(`/admin/providers/${id}/settings`, {});
  }
  if (path.match(/^\/admin\/providers\/\d+\/booking-rules/) && options.method === "PATCH") {
    const id = Number(path.split("/")[3]);
    const qs = new URLSearchParams(path.split("?")[1] || "");
    const o = (mock.providerOverrides[id] = mock.providerOverrides[id] || {});
    const clear = (qs.get("clear") || "").split(",").filter(Boolean);
    const apply = (key, param) => {
      if (clear.includes(param)) o[key] = null;
      else if (qs.get(param) != null) o[key] = Number(qs.get(param));
    };
    apply("cancellationCutoffHoursOverride", "cancellationCutoffHours");
    apply("providerCancelPenaltyPercentOverride", "providerCancelPenaltyPercent");
    apply("responseWindowMinutesOverride", "responseWindowMinutes");
    return mockRequest(`/admin/providers/${id}/settings`, {});
  }
  if (path.startsWith("/admin/settings/commission")) {
    if (options.method === "PATCH") {
      const match = path.match(/percent=([0-9.]+)/);
      mock.commissionPercent = match ? Number(match[1]) : mock.commissionPercent;
      return { commissionPercent: mock.commissionPercent };
    }
    return { commissionPercent: mock.commissionPercent ?? 10 };
  }
  if (path === "/admin/settlements/overview") {
    const rows = mock.settlementRows;
    return {
      commissionPercent: mock.commissionPercent ?? 20,
      totalOwed: rows.reduce((s, r) => s + r.balanceOwed, 0),
      providerCount: rows.filter((r) => r.balanceOwed > 0).length
    };
  }
  if (path.split("?")[0] === "/admin/settlements/providers") return mock.settlementRows;
  if (path.match(/^\/admin\/settlements\/provider\/\d+$/)) {
    const id = Number(path.split("/").pop());
    const row = mock.settlementRows.find((r) => r.providerId === id) || mock.settlementRows[0];
    return {
      providerId: row.providerId, providerName: row.providerName, settlementPaused: row.settlementPaused,
      status: row.status,
      commissionPercent: row.commissionPercent ?? mock.commissionPercent ?? 10,
      commissionOverridePercent: row.commissionOverridePercent ?? null,
      platformCommissionPercent: mock.commissionPercent ?? 10,
      totalOwed: row.balanceOwed, dueDate: row.dueDate,
      entries: [
        { id: 1, serviceName: "Haircut & Style", customerName: "Nour Hassan", bookingId: 5, bookingAmount: 350, commissionPercent: 15, commissionAmount: 52.5, status: "DUE", createdAt: "2026-09-08T16:10:00" },
        { id: 2, serviceName: "Balayage", customerName: "Hana Kamal", bookingId: 1, bookingAmount: 2200, commissionPercent: 15, commissionAmount: 330, status: "DUE", createdAt: "2026-09-07T18:40:00" },
        { id: 3, serviceName: "Hair Treatment", customerName: "Layla Hassan", bookingId: 9, bookingAmount: 450, commissionPercent: 15, commissionAmount: 67.5, status: "OVERDUE", createdAt: "2026-05-14T14:20:00" }
      ]
    };
  }
  if (path.match(/\/payout-report$/)) {
    const row = mock.settlementRows.find((r) => r.providerId === Number(path.split("/")[4]));
    return { reportedAt: null, total: row?.balanceOwed ?? 0, entryCount: 3 };
  }
  if (path.match(/\/confirm-payout(\?|$)/) && options.method === "POST") {
    const id = Number(path.split("/")[4]);
    const row = mock.settlementRows.find((r) => r.providerId === id);
    if (row) { row.balanceOwed = 0; row.grossAmount = 0; row.status = "SETTLED"; row.settlementPaused = false; }
    return { providerId: id, providerName: row?.providerName, status: "SETTLED", totalOwed: 0, settlementPaused: false, commissionPercent: mock.commissionPercent ?? 20, entries: [] };
  }
  if (path.match(/\/settlement-pause/) && options.method === "PATCH") return { success: true };
  if (path.startsWith("/terms?") || path === "/terms") {
    const qs = new URLSearchParams(path.split("?")[1] || "");
    const posted = options.method === "POST" && options.body ? JSON.parse(options.body) : {};
    const type = posted.type || qs.get("type") || "CUSTOMER_TERMS";
    if (options.method === "POST") {
      const v = { id: Date.now(), version: posted.version, type, active: true, createdAt: new Date().toISOString(), contentEn: posted.contentEn, contentAr: posted.contentAr || "" };
      mock.termsVersions.forEach((t) => { if ((t.type || "CUSTOMER_TERMS") === type) t.active = false; });
      mock.termsVersions.unshift(v);
      return v;
    }
    return mock.termsVersions.filter((t) => (t.type || "CUSTOMER_TERMS") === type);
  }
  if (path.startsWith("/admin/safety")) {
    const resolve = path.match(/^\/admin\/safety\/(\d+)\/resolve/);
    if (resolve && options.method === "POST") {
      const ev = mock.safety.find((s) => String(s.id) === resolve[1]);
      const notes = (options.body ? JSON.parse(options.body).notes : "") || "";
      if (ev) Object.assign(ev, { resolved: true, resolvedAt: new Date().toISOString(), resolvedByName: mock.user.fullName, resolutionNotes: notes });
      return ev;
    }
    const status = new URLSearchParams(path.split("?")[1] || "").get("status") || "OPEN";
    return mock.safety.filter((s) => status === "ALL" || (status === "RESOLVED" ? s.resolved : !s.resolved));
  }
  if (path === "/support/admin/settings") {
    if (options.method === "PATCH") {
      const body = options.body ? JSON.parse(options.body) : {};
      if (Array.isArray(body.numbers)) {
        const cleaned = body.numbers
          .map((n) => ({ label: (n.label || "").trim(), number: (n.number || "").trim(),
            displayNumber: (n.displayNumber || "").trim() || (n.number || "").trim(),
            primary: !!n.primary, enabled: n.enabled !== false }))
          .filter((n) => n.number);
        const enabled = cleaned.filter((n) => n.enabled);
        if (!cleaned.length) { const e = new Error("Add at least one support number"); e.status = 400; throw e; }
        if (!enabled.length) { const e = new Error("At least one support number must be enabled"); e.status = 400; throw e; }
        const primary = enabled.find((n) => n.primary) || enabled[0];
        cleaned.forEach((n) => { n.primary = n === primary; });
        mock.supportSettings.numbers = cleaned;
        mock.supportSettings.whatsappNumber = primary.number;
        mock.supportSettings.whatsappNumberDisplay = primary.displayNumber;
      }
      if (body.availabilityHoursEn != null) mock.supportSettings.availabilityHoursEn = body.availabilityHoursEn;
      if (body.supportEmail != null) mock.supportSettings.supportEmail = body.supportEmail;
      if (body.whatsappEnabled != null) mock.supportSettings.whatsappEnabled = body.whatsappEnabled;
    }
    return JSON.parse(JSON.stringify(mock.supportSettings));
  }
  if (path.split("?")[0] === "/admin/settlements") return mock.settlements;
  if (path.split("?")[0] === "/admin/bookings") return mock.bookings;
  if (path === "/admin/bookings/stats") return { today: 38, inProgress: 6, openDisputes: 1, cancelRate7d: 4.2 };
  if (path.split("?")[0] === "/admin/reviews") return mock.reviews;
  if (path.split("?")[0] === "/admin/flags") return mock.complaints.filter((item) => item.priority === "High").map((item, index) => ({
    id: item.id,
    targetProviderName: item.provider,
    targetProviderId: 20 + index,
    targetUserName: item.customer,
    targetUserId: 30 + index,
    description: item.subject,
    reporterName: item.customer,
    when: item.when
  }));

  return { success: true };
}

export { mock, USE_MOCKS, API_BASE_URL };
