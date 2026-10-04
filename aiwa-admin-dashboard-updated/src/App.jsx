import React, { useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  ArrowLeft,
  BadgeCheck,
  Ban,
  Banknote,
  Bell,
  Calendar,
  CalendarCheck,
  CalendarSearch,
  Check,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Download,
  FileSearch,
  ScrollText,
  ExternalLink,
  Eye,
  EyeOff,
  Flag,
  IdCard,
  ImageOff,
  LayoutDashboard,
  LogOut,
  Inbox,
  Maximize2,
  Menu,
  MessageSquareWarning,
  MoreHorizontal,
  Pencil,
  Plus,
  RotateCw,
  ScanFace,
  Search,
  Settings,
  ShieldAlert,
  ShieldCheck,
  Siren,
  Star,
  Trash2,
  TrendingDown,
  TrendingUp,
  UserCog,
  UserPlus,
  Users,
  X,
  XCircle
} from "lucide-react";
import { api, clearTokens, getAccessToken, mock, setTokens, TOKEN_STORAGE_KEYS, USE_MOCKS } from "./api";

/* String → component map for icons that arrive as strings from the API/mock. */
const iconMap = {
  BadgeCheck,
  Banknote,
  Calendar,
  CalendarCheck,
  Download,
  Eye,
  EyeOff,
  Flag,
  ImageOff,
  LayoutDashboard,
  MessageSquareWarning,
  MoreHorizontal,
  Search,
  Settings,
  ShieldAlert,
  ScrollText,
  Star,
  Trash2,
  TrendingUp,
  UserCog,
  UserPlus,
  Users,
  XCircle
};

function Icon({ name, size = 18 }) {
  const Component = typeof name === "string" ? iconMap[name] : name;
  if (!Component) return null;
  return <Component size={size} strokeWidth={1.9} />;
}

const navItems = [
  { id: "dashboard", label: "Dashboard", icon: LayoutDashboard },
  { id: "safety", label: "Safety (SOS)", icon: Siren },
  { id: "verifications", label: "Verifications", icon: BadgeCheck },
  { id: "complaints", label: "Complaints", icon: Flag },
  { id: "flags", label: "Flags", icon: ShieldAlert },
  { id: "users", label: "Users & providers", icon: Users },
  { id: "bookings", label: "Bookings", icon: CalendarCheck },
  { id: "reviews", label: "Reviews", icon: Star },
  { id: "moderation", label: "Photo moderation", icon: ImageOff },
  { id: "chat-reports", label: "Chat reports", icon: MessageSquareWarning },
  { id: "settlements", label: "Settlements", icon: Banknote },
  { id: "audit", label: "Audit log", icon: ScrollText },
  { id: "settings", label: "Policies & support", icon: Settings }
];

/* ─────────────────────────── Toasts + action runner ─────────────────────────── */
const toastListeners = new Set();
function toast(message, kind = "ok") {
  const item = { id: `${Date.now()}-${Math.random()}`, message, kind };
  toastListeners.forEach((fn) => fn(item));
}
let onAuthExpired = () => {};

/* ── Admin permission tiers ──────────────────────────────────────────────
   SUPPORT  — complaints, flags, warnings, content moderation, provider
              verification, customer/provider account suspension.
   FINANCE  — settlements, payouts, commission rate, booking disputes.
   SUPER_ADMIN — other admins & permissions, booking rules, policies,
              support settings, permanent deletion. Implies SUPPORT+FINANCE.
   Every admin can view every screen; these gate the actions.            */
let currentPermissions = [];
function can(permission) {
  if (USE_MOCKS) return true;
  return currentPermissions.includes("SUPER_ADMIN") || currentPermissions.includes(permission);
}
/** Test-only: seed the module-level permission list without spinning up <App>.
 *  Production code goes through the App's useEffect on line ~333 instead. */
export function __setPermissionsForTest(perms) { currentPermissions = Array.isArray(perms) ? perms : []; }
const PERMISSION_LABEL = { SUPPORT: "Support", FINANCE: "Finance", SUPER_ADMIN: "Super admin" };
function ReadOnlyNote({ need }) {
  if (can(need)) return null;
  return (
    <InlineBanner
      tone="info"
      title="View only"
      body={`Acting here needs the ${PERMISSION_LABEL[need] || need} permission. Ask a super admin to grant it or make the change.`}
    />
  );
}

/* Global confirm dialog — replaces window.confirm with the AIWA sheet.
 * opts.input = { label, placeholder } adds a required text field whose value
 * is passed to onConfirm (resolution notes, cancel reasons). opts.icon swaps
 * the default warning glyph. */
const confirmListeners = new Set();
function setConfirm(opts) {
  confirmListeners.forEach((fn) => fn(opts));
}
export function ConfirmHost() {
  const [state, setState] = useState(null);
  const [text, setText] = useState("");
  useEffect(() => {
    const listener = (opts) => { setText(""); setState(opts); };
    confirmListeners.add(listener);
    return () => confirmListeners.delete(listener);
  }, []);
  if (!state) return null;
  const close = () => setState(null);
  const Glyph = state.icon || AlertTriangle;
  const blocked = state.input && text.trim().length === 0;
  return (
    <div className="modal-backdrop" onClick={close}>
      <div className="confirm-card" onClick={(e) => e.stopPropagation()} role="alertdialog" aria-modal="true">
        <span className={`confirm-icon ${state.tone === "danger" ? "danger" : "plum"}`}>
          <Glyph size={20} />
        </span>
        {state.eyebrow && <p className="eyebrow">{state.eyebrow}</p>}
        <h2>{state.title}</h2>
        {state.body && <p>{state.body}</p>}
        {state.input && (
          <label className="field-label" style={{ display: "grid", gap: 6, textAlign: "left" }}>
            {state.input.label}
            <textarea className="field-note" rows={3} autoFocus value={text} maxLength={2000}
              placeholder={state.input.placeholder} onChange={(e) => setText(e.target.value)} />
          </label>
        )}
        <div className="modal-actions">
          <button className="btn btn-secondary" onClick={close}>{state.cancelLabel || "Cancel"}</button>
          <button
            className={`btn ${state.tone === "danger" ? "btn-danger" : "btn-primary"}`}
            disabled={blocked}
            onClick={() => { const value = text.trim(); close(); Promise.resolve().then(() => state.onConfirm(value)); }}
          >
            {state.confirmLabel || "Confirm"}
          </button>
        </div>
      </div>
    </div>
  );
}

/** Runs an async action with unified feedback: toast on success/error, logout on 401. */
async function runAction(fn, { success, failure } = {}) {
  try {
    const result = await fn();
    if (success) toast(success, "ok");
    // After any successful mutation, refresh every subscribed useLoad + the
    // notification bell so the UI reflects the new server state — including
    // notifications for the thing the user just resolved disappearing.
    refreshApp();
    return result;
  } catch (err) {
    if (err?.status === 401) {
      toast("Session expired. Please sign in again.", "error");
      onAuthExpired();
    } else if (err?.status === 403) {
      toast(err?.message || "You don't have permission to perform this action.", "error");
    } else {
      toast(failure || err?.message || "Action failed. Please try again.", "error");
    }
    throw err;
  }
}

function Toaster() {
  const [items, setItems] = useState([]);
  useEffect(() => {
    const listener = (item) => {
      setItems((current) => {
        // Dedupe: if the newest toast on screen already has this exact message
        // and kind, replace it (extend its lifetime) instead of stacking a
        // duplicate. Prevents the "10 copies of the same error piled up"
        // situation when a user retries a failing action repeatedly.
        const last = current[current.length - 1];
        if (last && last.message === item.message && last.kind === item.kind) {
          return current.slice(0, -1).concat(item);
        }
        return [...current, item];
      });
      setTimeout(() => setItems((current) => current.filter((entry) => entry.id !== item.id)), 3600);
    };
    toastListeners.add(listener);
    return () => toastListeners.delete(listener);
  }, []);
  if (items.length === 0) return null;
  return (
    <div className="toast-stack" role="status" aria-live="polite">
      {items.map((item) => (
        <div key={item.id} className={`toast ${item.kind === "error" ? "error" : "ok"}`}>
          {item.kind === "error" ? <X size={15} /> : <Check size={15} />}
          <span>{item.message}</span>
        </div>
      ))}
    </div>
  );
}

/* Small inline loading + empty helpers used across tables. */
function LoadingRow({ label = "Loading…" }) {
  return <div className="empty-row loading-row"><span className="skel-dot" /> {label}</div>;
}

/* Shimmer skeleton rows — the design system's "no spinners, pulse/shimmer only" rule. */
function SkeletonRows({ cols = 5, rows = 5 }) {
  return (
    <div className="skeleton-rows" aria-hidden="true">
      {Array.from({ length: rows }).map((_, r) => (
        <div className="skeleton-row" key={r} style={{ gridTemplateColumns: `repeat(${cols}, 1fr)` }}>
          {Array.from({ length: cols }).map((_, c) => (
            <span className="skel" key={c} style={{ width: c === 0 ? "78%" : "54%" }} />
          ))}
        </div>
      ))}
    </div>
  );
}

/* Full-panel empty / error state — icon + title + body + optional action. */
function StateBlock({ variant = "empty", icon, tone, title, body, actionLabel, onAction }) {
  const isError = variant === "error";
  const Ico = icon || (isError ? AlertTriangle : Inbox);
  return (
    <div className="state-block">
      <span className={`state-icon ${isError ? "danger" : tone || "plum"}`}><Ico size={24} /></span>
      <strong>{title || (isError ? "Couldn't load this" : "Nothing here yet")}</strong>
      {body && <p>{body}</p>}
      {onAction && (
        <button className="btn btn-primary sm" onClick={onAction}>
          {isError ? <RotateCw size={14} /> : null} {actionLabel || (isError ? "Try again" : "Refresh")}
        </button>
      )}
    </div>
  );
}

/* ─────────────────────────── Shared UX primitives (match design system) ─────────────────────────── */
function Toolbar({ query, onQuery, placeholder = "Search…", filters = [], activeFilter, onFilter, right }) {
  return (
    <div className="toolbar">
      <div className="toolbar-search">
        <Search size={15} />
        <input value={query} onChange={(event) => onQuery(event.target.value)} placeholder={placeholder} aria-label={placeholder} />
      </div>
      {filters.length > 0 && (
        <div className="toolbar-filters">
          {filters.map((filter) => (
            <button key={filter} className={`chip ${activeFilter === filter ? "active" : ""}`} onClick={() => onFilter(filter)}>{filter}</button>
          ))}
        </div>
      )}
      {right && <div className="toolbar-right">{right}</div>}
    </div>
  );
}

/** First, last and a 3-page window around the current page, "…" for gaps:
 *  1 … 4 5 6 … 12. */
export function pageWindow(page, totalPages) {
  const keep = new Set([1, totalPages, page - 1, page, page + 1]);
  const out = [];
  for (let p = 1; p <= totalPages; p++) {
    if (!keep.has(p)) continue;
    if (out.length && p - out[out.length - 1] > 1) out.push("…");
    out.push(p);
  }
  return out;
}

function Pagination({ page, totalPages, onPage }) {
  if (totalPages <= 1) return null;
  return (
    <div className="pagination">
      <button className="pg-btn" disabled={page <= 1} onClick={() => onPage(page - 1)} aria-label="Previous page"><ChevronLeft size={15} /></button>
      {pageWindow(page, totalPages).map((p, i) => p === "…"
        ? <span key={`gap-${i}`} className="pg-info" aria-hidden="true">…</span>
        : <button key={p} className={`pg-btn ${p === page ? "active" : ""}`} aria-current={p === page ? "page" : undefined}
            aria-label={`Page ${p}`} onClick={() => onPage(p)}>{p}</button>)}
      <button className="pg-btn" disabled={page >= totalPages} onClick={() => onPage(page + 1)} aria-label="Next page"><ChevronRight size={15} /></button>
    </div>
  );
}

function StatTiles({ tiles }) {
  return (
    <div className="stat-tiles">
      {tiles.map((tile) => (
        <article className="stat-tile" key={tile.label}>
          <p className="eyebrow">{tile.label}</p>
          <strong>{tile.value}</strong>
          <span className="dim">{tile.sub}</span>
        </article>
      ))}
    </div>
  );
}

export function Tag({ tone = "plum", children }) {
  return <span className={`tag-pill ${tone}`}>{children}</span>;
}

export function InlineBanner({ tone = "info", title, body }) {
  return (
    <div className={`inline-banner ${tone}`}>
      {title && <strong>{title}</strong>}
      <span>{body}</span>
    </div>
  );
}

// CR-22: until /auth/me answers, the signed-in admin is nobody (no permissions)
// rather than the mock super admin.
const LOADING_SESSION = { user: { permissions: [] }, loading: true };

export default function App() {
  const [session, setSession] = useState(() => (USE_MOCKS ? { user: mock.user } : getAccessToken() ? LOADING_SESSION : null));
  const [profileError, setProfileError] = useState(false);
  const [profileTry, setProfileTry] = useState(0);
  const [route, setRoute] = useState("dashboard");
  const [sidebarOpen, setSidebarOpen] = useState(false);

  useEffect(() => {
    window.scrollTo(0, 0);
    document.documentElement.scrollLeft = 0;
    document.body.scrollLeft = 0;
  }, [route]);

  // Publish the app-level setRoute so PageHeader's NotificationBell can
  // navigate to any screen when a notification item is clicked.
  useEffect(() => {
    pageHeaderOnRoute = (next) => setRoute(next);
    return () => { pageHeaderOnRoute = () => {}; };
  }, []);

  // Let any API 401 (expired/invalid token) drop the session back to login.
  // Reset route too — otherwise the next login (same tab, no refresh) drops
  // the admin right back on whatever page the previous session left behind.
  useEffect(() => {
    onAuthExpired = () => { clearTokens(); setSession(null); setRoute("dashboard"); };
    return () => { onAuthExpired = () => {}; };
  }, []);

  // On reload the session starts empty and loading; hydrate the real signed-in
  // user (correct id + permissions) from the token. Only a 401 means the token
  // is no longer good (drop to login); a 5xx or a network blip keeps the
  // session and shows a retry (CR-22).
  useEffect(() => {
    if (USE_MOCKS || !getAccessToken()) return;
    let alive = true;
    setProfileError(false);
    api.me()
      .then((me) => {
        if (!alive) return;
        if (me?.id != null) setSession({ user: me }); else setProfileError(true);
      })
      .catch((err) => {
        if (!alive) return;
        if (err?.status === 401) { clearTokens(); setSession(null); setRoute("dashboard"); } else setProfileError(true);
      });
    return () => { alive = false; };
  }, [profileTry]);

  // CR-18: another tab signed out (this tab follows) or signed in / refreshed
  // (this tab re-reads who is signed in). Storage events only reach other tabs.
  useEffect(() => {
    const onStorage = (event) => {
      if (USE_MOCKS || !(event.key === null || TOKEN_STORAGE_KEYS.includes(event.key))) return;
      if (!getAccessToken()) { setSession(null); setRoute("dashboard"); } else setProfileTry((n) => n + 1);
    };
    window.addEventListener("storage", onStorage);
    return () => window.removeEventListener("storage", onStorage);
  }, []);

  // Publish the signed-in admin's permissions for the module-level `can()` helper.
  // Set while rendering, not in an effect: the screens below read it during this
  // same render, so permissions that arrive with /auth/me show up at once (CR-22).
  currentPermissions = Array.isArray(session?.user?.permissions) ? session.user.permissions : [];
  useEffect(() => () => { currentPermissions = []; }, []);

  if (!session) {
    return (
      <>
        <LoginScreen onLogin={(nextSession) => setSession(nextSession)} />
        <Toaster />
      </>
    );
  }

  return (
    <div className="app-shell">
      <Sidebar
        route={route}
        user={session.user}
        open={sidebarOpen}
        onClose={() => setSidebarOpen(false)}
        onProfile={() => { setRoute("me"); setSidebarOpen(false); }}
        onRoute={(nextRoute) => {
          setRoute(nextRoute);
          setSidebarOpen(false);
        }}
        onLogout={() => {
          api.logout(); // CR-18: clears the tokens first; the server call is best-effort
          setSession(null);
          setRoute("dashboard"); // next login starts fresh, not on the page you left
        }}
      />
      <main className="main-panel">
        <MobileBar onMenu={() => setSidebarOpen(true)} />
        <TopBar />
        {profileError && session.loading && (
          <div className="inline-banner danger" role="alert">
            <strong>Could not load your profile</strong>
            <span>Actions stay hidden until it loads. Check your connection and try again.</span>
            <button className="btn btn-secondary sm" onClick={() => setProfileTry((n) => n + 1)}>Retry</button>
          </div>
        )}
        {route === "dashboard" && <Dashboard onRoute={setRoute} />}
        {route === "safety" && <Safety />}
        {route === "verifications" && <Verifications />}
        {route === "complaints" && <Complaints />}
        {route === "flags" && <Flags />}
        {route === "users" && <UsersPage currentUser={session.user} />}
        {route === "bookings" && <Bookings />}
        {route === "reviews" && <Reviews />}
        {route === "moderation" && <Moderation />}
        {route === "chat-reports" && <ChatReports />}
        {route === "settlements" && <Settlements />}
        {route === "audit" && <AuditLog />}
        {route === "settings" && <Policies />}
        {route === "me" && (
          <MyProfile
            currentUser={session.user}
            onBack={() => setRoute("dashboard")}
            onSelfPatch={(patch) => setSession((s) => ({ ...s, user: { ...s.user, ...patch } }))}
          />
        )}
      </main>
      <Toaster />
      <ConfirmHost />
    </div>
  );
}

/* ─────────────────────────── Login ─────────────────────────── */
export function LoginScreen({ onLogin }) {
  // Seed credentials only in mock mode (any login works there); never ship
  // a prefilled real account (OPS-8).
  const [email, setEmail] = useState(USE_MOCKS ? "admin@aiwa.com" : "");
  const [password, setPassword] = useState(USE_MOCKS ? "AdminPassword123!" : "");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [mfaToken, setMfaToken] = useState(null);
  const [code, setCode] = useState("");

  async function submit(event) {
    event.preventDefault();
    setLoading(true);
    setError("");
    try {
      const result = await api.login({ email, password });
      if (result.mfaRequired) {
        setMfaToken(result.mfaToken);
      } else {
        setTokens(result);
        onLogin({ user: result.user || LOADING_SESSION.user });
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function submitCode(event) {
    event.preventDefault();
    setLoading(true);
    setError("");
    try {
      const result = await api.verifyMfa(mfaToken, code);
      setTokens(result);
      onLogin({ user: result.user || LOADING_SESSION.user });
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  if (mfaToken) {
    return (
      <div className="login-screen">
        <form className="login-card" onSubmit={submitCode}>
          <div className="brand-row">
            <span className="brand-word">AIWA<span className="dot">.</span></span>
            <span className="role-tag">Admin</span>
          </div>
          <p className="eyebrow" style={{ marginTop: 18 }}>Two-factor authentication</p>
          <h1>Enter your code</h1>
          <p className="muted small">Open your authenticator app and enter the current 6-digit code.</p>
          <label>
            Authentication code
            <input
              value={code}
              onChange={(event) => setCode(event.target.value.replace(/\D/g, "").slice(0, 6))}
              inputMode="numeric"
              autoComplete="one-time-code"
              autoFocus
              required
            />
          </label>
          {error && <div className="form-error">{error}</div>}
          <button className="btn btn-primary" disabled={loading || code.length !== 6}>
            {loading ? "Verifying…" : "Verify"}
          </button>
          <button
            type="button"
            className="btn btn-ghost"
            style={{ marginTop: 8 }}
            onClick={() => { setMfaToken(null); setCode(""); setError(""); }}
          >
            Back to sign in
          </button>
        </form>
      </div>
    );
  }

  return (
    <div className="login-screen">
      <form className="login-card" onSubmit={submit}>
        <div className="brand-row">
          <span className="brand-word">AIWA<span className="dot">.</span></span>
          <span className="role-tag">Admin</span>
        </div>
        <p className="eyebrow" style={{ marginTop: 18 }}>Secure workspace</p>
        <h1>Sign in to dashboard</h1>
        <label>
          Email
          <input value={email} onChange={(event) => setEmail(event.target.value)} type="email" required />
        </label>
        <label>
          Password
          <input value={password} onChange={(event) => setPassword(event.target.value)} type="password" required />
        </label>
        {error && <div className="form-error">{error}</div>}
        <button className="btn btn-primary" disabled={loading}>
          {loading ? "Signing in…" : "Sign in"}
        </button>
        {USE_MOCKS && <p className="muted small">Mock mode is active. Connect the backend by setting <code>VITE_USE_MOCKS=false</code>.</p>}
      </form>
    </div>
  );
}

/* ─────────────────────────── Chrome ─────────────────────────── */
/** Per-screen counts of what still needs handling, from the admin inbox
 *  (GET /admin/inbox groups items by targetRoute). The inbox caps each source
 *  at 20, so a full source shows "20+". */
// CR-19: screens that must follow a badge (the SOS queue) subscribe here; the
// badge poll tells them when that screen's count changed.
const badgeChangeListeners = new Set();

export function useNavBadges() {
  const [badges, setBadges] = useState({});
  useEffect(() => {
    let lastSafety = null;
    const load = () => api.inbox(100)
      .then((rows) => {
        const counts = {};
        for (const row of rows || []) counts[row.targetRoute] = (counts[row.targetRoute] || 0) + 1;
        const safety = counts.safety || 0;
        if (lastSafety !== null && lastSafety !== safety) badgeChangeListeners.forEach((fn) => { try { fn("safety"); } catch {} });
        lastSafety = safety;
        setBadges(Object.fromEntries(Object.entries(counts).map(([k, n]) => [k, n >= 20 ? "20+" : n])));
      })
      .catch(() => { /* badges are a hint; the screens show the real lists */ });
    load();
    const t = setInterval(load, 60_000);
    appRefreshListeners.add(load);
    return () => { clearInterval(t); appRefreshListeners.delete(load); };
  }, []);
  return badges;
}

function Sidebar({ route, user, open, onClose, onRoute, onLogout, onProfile }) {
  const badges = useNavBadges();
  return (
    <>
      <button className={`overlay ${open ? "show" : ""}`} onClick={onClose} aria-label="Close menu" />
      <aside className={`sidebar ${open ? "open" : ""}`}>
        <div className="brand-row sidebar-brand">
          <span className="brand-word light">AIWA<span className="dot">.</span></span>
          <span className="role-tag">Admin</span>
        </div>
        <nav className="nav-list">
          {navItems.map((item) => {
            const active = item.id === route;
            return (
              <button key={item.id} className={`nav-item ${active ? "active" : ""}`} onClick={() => onRoute(item.id)}>
                <span className="nav-icon"><Icon name={item.icon} size={16} /></span>
                <span className="nav-label">{item.label}</span>
                {badges[item.id] ? <b>{badges[item.id]}</b> : null}
              </button>
            );
          })}
        </nav>
        <button
          type="button"
          className={`admin-card ${route === "me" ? "active" : ""}`}
          onClick={onProfile}
          title="View my profile"
        >
          <Avatar name={user?.fullName || "Admin"} palette="rose" size={32} />
          <div>
            <strong>Admin · {user?.fullName || "…"}</strong>
            <span>{user?.location || user?.email || "Signed in"}</span>
          </div>
          <ChevronRight className="admin-card-chevron" size={15} />
        </button>
        <button className="logout-button" onClick={onLogout}>
          <LogOut size={16} />
          <span className="nav-label">Logout</span>
        </button>
      </aside>
    </>
  );
}

function MobileBar({ onMenu }) {
  // Mobile-only: just the hamburger + brand. The refresh + notification
  // controls live inside <PageHeader> now so they sit inline with each page's
  // own action row (Export, filters, etc.) instead of floating in dead space.
  return (
    <div className="mobile-bar">
      <button className="menu-button" onClick={onMenu} aria-label="Open menu"><Menu size={20} /></button>
      <span className="brand-word">AIWA<span className="dot">.</span></span>
    </div>
  );
}

/**
 * Live inbox dropdown. Fetches the admin inbox — a unified feed of things
 * that need attention across the whole app: new complaints, provider signups
 * awaiting verification, reported reviews and chat messages, disputed
 * bookings. Polls every 60s. The badge shows the TOTAL number of items
 * needing attention (matches the visible list count) — an admin's mental
 * model is "how many things do I still have to handle", not "what have I
 * looked at since". Items are clickable and jump to the right screen.
 */
function NotificationBell({ onRoute }) {
  const [open, setOpen] = useState(false);
  const [items, setItems] = useState([]);
  // Re-tick every 60s so relative timestamps ("2m ago", "1h ago") stay live
  // even when there's no new data arriving.
  const [, setNowTick] = useState(0);

  const fetchItems = React.useCallback(() => {
    api.inbox(15)
      .then((rows) => setItems(rows || []))
      .catch(() => { /* silent — bell just shows nothing */ });
  }, []);

  useEffect(() => {
    fetchItems();
    const t = setInterval(() => { fetchItems(); setNowTick((n) => n + 1); }, 60_000);
    return () => clearInterval(t);
  }, [fetchItems]);

  // Also refetch whenever the user triggers a global refresh.
  useEffect(() => {
    appRefreshListeners.add(fetchItems);
    return () => appRefreshListeners.delete(fetchItems);
  }, [fetchItems]);

  // Close on click-outside / Escape.
  useEffect(() => {
    if (!open) return;
    const onDown = (e) => { if (!e.target.closest(".notification-bell")) setOpen(false); };
    const onKey = (e) => { if (e.key === "Escape") setOpen(false); };
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => { document.removeEventListener("mousedown", onDown); document.removeEventListener("keydown", onKey); };
  }, [open]);

  // Badge count matches what the user will see when they open the panel —
  // no lastSeenId dance, no drifting mismatch between chip and list.
  const displayCount = items.length;

  function toggle() { setOpen((o) => !o); }

  return (
    <div className="notification-bell">
      <button
        className="top-bar-btn"
        onClick={toggle}
        aria-label={displayCount > 0 ? `Notifications, ${displayCount} unread` : "Notifications"}
        title="Notifications"
      >
        <Bell size={17} />
        {displayCount > 0 && <span className="notification-badge">{displayCount > 9 ? "9+" : displayCount}</span>}
      </button>
      {open && (
        <div className="notification-panel" role="dialog" aria-label="Notifications">
          <div className="notification-panel-head">
            <strong>Notifications</strong>
          </div>
          <div className="notification-panel-body">
            {items.length === 0 && (
              <p className="muted small" style={{ padding: "18px 16px", margin: 0 }}>
                Nothing needs your attention right now.
              </p>
            )}
            {items.map((it) => (
              <button
                key={it.id}
                type="button"
                className="notification-item"
                onClick={() => {
                  // Optimistic remove — the user has acknowledged this item by
                  // clicking through to act on it. If they don't actually
                  // resolve the underlying thing, the next 60s poll (or the
                  // manual Refresh button) will bring it back. This kills the
                  // "notification lingered until I refreshed the page" bug.
                  setItems((current) => current.filter((entry) => entry.id !== it.id));
                  setOpen(false);
                  if (it.targetRoute && onRoute) onRoute(it.targetRoute);
                }}
              >
                <div className="notification-item-title">
                  <span className={`notification-kind-dot ${kindDotClass(it.kind)}`} />
                  {it.title}
                </div>
                <div className="notification-item-body">{it.body}</div>
                <div className="notification-item-meta">{formatRelative(it.createdAt) || it.when}</div>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// Colour dot per inbox kind — quick visual scan of what's what.
function kindDotClass(kind) {
  switch (kind) {
    case "SOS":             return "danger";
    case "SETTLEMENT_REPORTED": return "gold";
    case "COMPLAINT":       return "rose";
    case "VERIFICATION":    return "gold";
    case "REPORTED_REVIEW": return "plum";
    case "REPORTED_CHAT":   return "plum";
    case "REPORTED_PHOTO":  return "plum";
    case "DISPUTE":         return "danger";
    default:                return "plum";
  }
}

/** Human relative time — "just now", "5m ago", "2h ago", "yesterday", "3d ago",
 *  and finally a full date for anything older than a week. Falls back to null
 *  on bad input so the caller can substitute the pre-formatted string. */
function formatRelative(value) {
  if (!value) return null;
  const then = new Date(value);
  if (Number.isNaN(then.getTime())) return null;
  const diffSec = Math.round((Date.now() - then.getTime()) / 1000);
  if (diffSec < 45) return "just now";
  if (diffSec < 90) return "1m ago";
  const min = Math.round(diffSec / 60);
  if (min < 60) return `${min}m ago`;
  const hr = Math.round(diffSec / 3600);
  if (hr < 24) return `${hr}h ago`;
  const days = Math.round(diffSec / 86400);
  if (days === 1) return "yesterday";
  if (days < 7) return `${days}d ago`;
  return then.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

function PageHeader({ eyebrow, title, right }) {
  return (
    <div className="page-header">
      <div>
        <p className="eyebrow">{eyebrow}</p>
        <h1>{title}</h1>
      </div>
      {right && <div className="page-header-actions">{right}</div>}
    </div>
  );
}

// The active app-level route setter, published by <App> so the always-mounted
// TopBar (and therefore the notification bell) can jump to any screen when a
// notification item is clicked.
let pageHeaderOnRoute = () => {};

/**
 * Refresh + notification bell rendered ONCE at the top of the main panel.
 * Living at App level (not inside <PageHeader>, which is remounted per route)
 * means the bell keeps its state — including optimistically-removed items —
 * when the user clicks a notification and navigates to a different screen.
 */
function TopBar() {
  return (
    <div className="top-actions-row">
      <RefreshButton />
      <NotificationBell onRoute={pageHeaderOnRoute} />
    </div>
  );
}

function RefreshButton() {
  const [spinning, setSpinning] = useState(false);
  function handleClick() {
    setSpinning(true);
    refreshApp();
    toast("Refreshed", "ok");
    setTimeout(() => setSpinning(false), 700);
  }
  return (
    <button
      className="top-bar-btn"
      onClick={handleClick}
      aria-label="Refresh"
      title="Refresh"
    >
      <RotateCw size={17} className={spinning ? "spinning" : ""} />
    </button>
  );
}

function formatToday() {
  const now = new Date();
  const weekday = new Intl.DateTimeFormat("en-US", { weekday: "long" }).format(now);
  const month = new Intl.DateTimeFormat("en-US", { month: "long" }).format(now);
  return `${weekday}, ${month} ${now.getDate()} · ${now.getFullYear()}`;
}

/* "Sep 8" — for chart axis labels. */
function shortDate(value) {
  if (!value) return "";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value).slice(-2);
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

/* Compact date — used across settlement + policy screens. */
function formatWhen(value) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return date.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

/* ─────────────────────────── Dashboard ─────────────────────────── */
const RANGE_OPTIONS = [7, 14, 30, 90];
/** Recent-activity glyph per audit tone (normalizeAudit). */
const ACTIVITY_ICON = { success: Check, danger: Ban, warn: AlertTriangle, info: ScrollText };

function Dashboard({ onRoute }) {
  const { data, loading } = useLoad(api.dashboard, mock.dashboard);
  const [series, setSeries] = useState([]);
  const [audit, setAudit] = useState([]);
  const [range, setRange] = useState(14);
  const [exporting, setExporting] = useState(false);
  const [refreshTick, setRefreshTick] = useState(0);

  // Global refresh broadcast — re-fetch chart + audit alongside the useLoad
  // dashboard call. Without this, hitting the top-bar Refresh only updates
  // the stat cards; the chart and Recent activity list stay stale.
  useEffect(() => {
    const listener = () => setRefreshTick((t) => t + 1);
    appRefreshListeners.add(listener);
    return () => appRefreshListeners.delete(listener);
  }, []);

  useEffect(() => {
    let alive = true;
    api.analyticsBookings(range).then((rows) => { if (alive) setSeries(rows); }).catch(() => { if (alive) setSeries([]); });
    return () => { alive = false; };
  }, [range, refreshTick]);

  useEffect(() => {
    let alive = true;
    api.audit("", 0, 6).then((result) => { if (alive) setAudit(result.items || []); }).catch(() => {});
    return () => { alive = false; };
  }, [refreshTick]);

  async function exportBookings() {
    setExporting(true);
    try {
      await runAction(() => api.exportBookings(range), { success: "Bookings exported", failure: "Could not export bookings" });
    } catch { /* toast shown */ } finally { setExporting(false); }
  }

  // Aggregate the daily series into ~weekly buckets for ranges longer than 3 weeks,
  // so the chart stays readable at 30 / 90 days (matches the design's weekly view).
  const buckets = useMemo(() => {
    if (series.length === 0) return [];
    if (series.length <= 21) {
      return series.map((p) => ({ completed: p.completed, cancelled: p.cancelled, total: p.total, label: shortDate(p.date) }));
    }
    const out = [];
    for (let i = 0; i < series.length; i += 7) {
      const week = series.slice(i, i + 7);
      out.push({
        completed: week.reduce((s, p) => s + p.completed, 0),
        cancelled: week.reduce((s, p) => s + p.cancelled, 0),
        total: week.reduce((s, p) => s + p.total, 0),
        label: shortDate(week[0].date)
      });
    }
    return out;
  }, [series]);

  const chartMax = Math.max(1, ...buckets.map((b) => b.completed + b.cancelled));
  const seriesTotal = series.reduce((sum, point) => sum + point.total, 0);
  const weekly = series.length > 21;

  const pv = data.pendingVerification ?? 0;
  const oc = data.openComplaints ?? 0;
  const od = data.openDisputes ?? 0;
  const os = data.overdueSettlements ?? 0;
  const sos = data.openSos ?? 0;
  const attention = [
    { key: "sos", tone: "danger", icon: Siren, count: sos, label: `open SOS alert${sos === 1 ? "" : "s"} — act now`, route: "safety" },
    { key: "verifications", tone: "gold", icon: BadgeCheck, count: pv, label: `provider${pv === 1 ? "" : "s"} awaiting verification`, route: "verifications" },
    { key: "complaints", tone: "danger", icon: Flag, count: oc, label: `open complaint${oc === 1 ? "" : "s"}`, route: "complaints" },
    { key: "disputes", tone: "danger", icon: AlertTriangle, count: od, label: `payment dispute${od === 1 ? "" : "s"} to resolve`, route: "bookings" },
    { key: "settlements", tone: "warn", icon: Banknote, count: os, label: `provider${os === 1 ? "" : "s"} with overdue settlement`, route: "settlements" }
  ].filter((item) => item.count > 0);

  return (
    <section className="page-content">
      <PageHeader
        eyebrow={formatToday()}
        title="Dashboard"
        right={
          <>
            <label className="chip select-chip">
              <Calendar size={14} />
              <select value={range} onChange={(e) => setRange(Number(e.target.value))} aria-label="Date range">
                {RANGE_OPTIONS.map((d) => <option key={d} value={d}>Last {d} days</option>)}
              </select>
            </label>
            <button className="btn btn-primary sm" onClick={exportBookings} disabled={exporting}>
              <Download size={15} /> {exporting ? "Exporting…" : "Export"}
            </button>
          </>
        }
      />
      {loading && (data.stats || []).length === 0 && <LoadingRow label="Loading dashboard…" />}

      <div className="stat-grid">
        {data.stats.map((stat) => (
          <article className="stat-card" key={stat.label}>
            <div className="stat-head">
              <p className="eyebrow">{stat.label}</p>
              <span className="icon-box"><Icon name={stat.icon} size={15} /></span>
            </div>
            <strong>{stat.value}</strong>
            {stat.delta && (
              <span className="positive" style={stat.delta.startsWith("-") ? { color: "var(--danger-700)" } : undefined}>
                {stat.delta.startsWith("-") ? <TrendingDown size={12} /> : <TrendingUp size={12} />} {stat.delta}
              </span>
            )}
            {stat.sub && <span className="stat-sub">{stat.sub}</span>}
          </article>
        ))}
      </div>

      {attention.length > 0 && (
        <div className="attention-panel">
          <p className="eyebrow panel-title">Needs attention</p>
          <div className="attention-list">
            {attention.map((item) => (
              <button key={item.key} className="attention-row" onClick={() => onRoute(item.route)}>
                <span className={`attention-icon ${item.tone}`}><item.icon size={15} /></span>
                <span className="attention-count">{item.count}</span>
                <span className="attention-text">{item.label}</span>
                <ChevronRight size={15} className="qa-chevron" />
              </button>
            ))}
          </div>
        </div>
      )}

      <div className="two-column">
        <article className="panel">
          <div className="panel-head">
            <div>
              <p className="eyebrow">Bookings · last {range} days{weekly ? " · weekly" : ""}</p>
              <h2>{seriesTotal.toLocaleString()}</h2>
            </div>
            <div className="legend">
              <span><i className="dot deep" /> Completed</span>
              <span><i className="dot rose" /> Cancelled</span>
            </div>
          </div>
          <div className="bar-chart-wrap">
            <div className="bar-chart">
              <i className="gridline" style={{ bottom: "25%" }} />
              <i className="gridline" style={{ bottom: "50%" }} />
              <i className="gridline" style={{ bottom: "75%" }} />
              {buckets.length === 0 && <span className="dim" style={{ fontSize: 13, alignSelf: "center", margin: "auto" }}>No booking data yet.</span>}
              {buckets.map((b, i) => {
                const scale = 160 / chartMax;
                const hasData = b.completed > 0 || b.cancelled > 0;
                return (
                  <div className="bar-col" key={i} title={`${b.label}: ${b.completed} completed · ${b.cancelled} cancelled`}>
                    <div className="bar-stack">
                      {b.completed > 0 && <i className="bar completed" style={{ height: Math.max(3, b.completed * scale) }} />}
                      {b.cancelled > 0 && <i className="bar cancelled" style={{ height: Math.max(3, b.cancelled * scale) }} />}
                      {!hasData && <i className="bar empty" />}
                    </div>
                  </div>
                );
              })}
            </div>
            <div className="bar-axis">
              {(() => {
                // ~6 evenly-spaced labels max so they never crowd on small screens.
                const step = Math.max(1, Math.ceil(buckets.length / 6));
                const last = buckets.length - 1;
                return buckets.map((b, i) => {
                  const show = i % step === 0 || (i === last && last % step >= step - 1);
                  return <span key={i}>{show ? b.label : ""}</span>;
                });
              })()}
            </div>
          </div>
        </article>

        <article className="panel">
          <p className="eyebrow panel-title">Recent activity</p>
          <div className="activity-list">
            {audit.length === 0 && <span className="dim" style={{ fontSize: 13 }}>No recorded admin activity yet.</span>}
            {audit.map((entry) => (
              <div className="activity-item" key={entry.id}>
                <span className={`activity-icon ${entry.tone}`}><Icon name={ACTIVITY_ICON[entry.tone] || ScrollText} size={14} /></span>
                <div>
                  <strong>{prettyStatus(entry.action)} · {entry.target}</strong>
                  <span>{entry.actor} · {entry.when}</span>
                </div>
              </div>
            ))}
          </div>
          <button className="btn btn-ghost sm" style={{ marginTop: 10 }} onClick={() => onRoute("audit")}>View full audit log</button>
        </article>
      </div>

      <div className="quick-grid">
        <QuickLink tone="warn" icon={BadgeCheck} title={`${pv} provider${pv === 1 ? "" : "s"} awaiting review`} sub="SLA target: 24h" onClick={() => onRoute("verifications")} />
        <QuickLink tone="danger" icon={Flag} title={`${oc} open complaint${oc === 1 ? "" : "s"}`} sub={`${data.highPriorityComplaints ?? 0} marked high priority`} onClick={() => onRoute("complaints")} />
        <QuickLink tone="info" icon={UserCog} title="Manage users" sub={`${(data.totalAccounts ?? 0).toLocaleString()} accounts`} onClick={() => onRoute("users")} />
      </div>
    </section>
  );
}

function QuickLink({ tone, icon: IconComponent, title, sub, onClick }) {
  return (
    <button className="quick-action" onClick={onClick}>
      <span className={`quick-badge ${tone}`}><IconComponent size={20} strokeWidth={1.9} /></span>
      <span className="qa-body">
        <strong>{title}</strong>
        <small>{sub}</small>
      </span>
      <ChevronRight size={18} className="qa-chevron" />
    </button>
  );
}

/* ─────────────────────────── Verifications ─────────────────────────── */
const VERIFICATION_TABS = [
  { key: "PENDING", label: "Pending", status: "PENDING_VERIFICATION", countKey: "pending" },
  { key: "APPROVED", label: "Approved", status: "APPROVED", countKey: "approved" },
  { key: "REJECTED", label: "Rejected", status: "REJECTED", countKey: "rejected" },
  { key: "SUSPENDED", label: "Suspended", status: "SUSPENDED", countKey: "suspended" }
];

function Verifications() {
  const [tab, setTab] = useState("PENDING");
  const [byTab, setByTab] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [selected, setSelected] = useState(null);
  const [counts, setCounts] = useState(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [page, setPage] = useState(1);
  const [query, setQuery] = useState("");

  const data = byTab[tab] || [];
  const filtered = data.filter((p) => matchesQuery(p, query, ["name", "category", "city", "submitted"]));
  const totalPages = Math.max(1, Math.ceil(filtered.length / LIST_PAGE_SIZE));
  const safePage = Math.min(page, totalPages);
  const pageRows = filtered.slice((safePage - 1) * LIST_PAGE_SIZE, safePage * LIST_PAGE_SIZE);

  useEffect(() => { setPage(1); }, [tab, query]);

  useEffect(() => {
    let alive = true;
    api.verificationCounts().then((result) => { if (alive) setCounts(result); }).catch(() => {});
    return () => { alive = false; };
  }, [reloadKey]);

  useEffect(() => {
    let alive = true;
    setError("");
    setLoading(true);
    const loader = tab === "PENDING"
      ? api.verifications()
      : api.verificationByStatus(VERIFICATION_TABS.find((t) => t.key === tab).status);
    loader
      .then((rows) => { if (alive) setByTab((current) => ({ ...current, [tab]: rows })); })
      .catch((err) => { if (alive) setError(err.message || "Request failed"); })
      .finally(() => { if (alive) setLoading(false); });
    return () => { alive = false; };
  }, [tab, reloadKey]);

  function refreshAll() {
    setByTab({});
    setReloadKey((k) => k + 1);
  }

  async function approve(id) {
    await runAction(() => api.approveProvider(id), { success: "Provider approved" });
    setSelected(null);
    refreshAll();
  }

  async function reject(id, reason) {
    await runAction(() => api.rejectProvider(id, reason), { success: "Provider rejected" });
    setSelected(null);
    refreshAll();
  }

  async function requestInfo(id, message) {
    await runAction(() => api.requestProviderInfo(id, message), { success: "Information requested from provider" });
    setSelected(null);
    refreshAll();
  }

  async function suspend(id) {
    await runAction(() => api.suspendProvider(id), { success: "Provider suspended" });
    setSelected(null);
    refreshAll();
  }

  async function reactivate(id) {
    await runAction(() => api.reactivateProvider(id), { success: "Provider reactivated" });
    setSelected(null);
    refreshAll();
  }

  const current = selected ? data.find((item) => item.id === selected) : null;
  if (current) {
    return (
      <VerificationDetail
        provider={current}
        onBack={() => setSelected(null)}
        onApprove={approve}
        onReject={reject}
        onRequestInfo={requestInfo}
        onSuspend={suspend}
        onReactivate={reactivate}
      />
    );
  }

  const emptyCopy = {
    PENDING: "No providers are waiting for review right now.",
    APPROVED: "No providers have been approved yet.",
    REJECTED: "No providers have been rejected.",
    SUSPENDED: "No providers are currently suspended."
  };

  return (
    <section className="page-content">
      <PageHeader
        eyebrow="Queue · SLA 24h"
        title="Verifications"
        right={
          <>
            {VERIFICATION_TABS.map((t) => (
              <button key={t.key} className={`chip ${tab === t.key ? "active" : ""}`} onClick={() => setTab(t.key)}>
                {t.label}{counts ? ` (${counts[t.countKey] ?? 0})` : ""}
              </button>
            ))}
          </>
        }
      />
      <ReadOnlyNote need="SUPPORT" />
      <SearchBar value={query} onChange={setQuery} placeholder="Search provider, category, city, submitted…" />
      <article className="table-card">
        <div className="table-scroll">
          <div className="table header verifications">
            <span>Provider</span><span>Category</span><span>City</span><span>Documents</span><span>Submitted</span><span />
          </div>
          {pageRows.map((provider) => (
            <div className="table row verifications clickable" key={provider.id} onClick={() => setSelected(provider.id)}>
              <ProfileCell name={provider.name} palette={provider.palette} flag={provider.flag} />
              <span>{provider.category}</span>
              <span>{provider.city}</span>
              <span className="dim">{provider.documents}</span>
              <span className="dim">{provider.submitted}</span>
              <span className="cell-end">
                <button className="btn btn-primary sm" onClick={(e) => { e.stopPropagation(); setSelected(provider.id); }}>
                  {tab === "PENDING" ? "Review" : "Open"}
                </button>
              </span>
            </div>
          ))}
          {loading && <SkeletonRows cols={6} />}
          {error && !loading && <StateBlock variant="error" body={`Could not load the verification queue: ${error}`} onAction={refreshAll} />}
          {!loading && !error && filtered.length === 0 && (
            <StateBlock variant="empty" icon={BadgeCheck}
              title={query ? "No matches" : (tab === "PENDING" ? "Queue is clear" : "Nothing here")}
              body={query ? `Nothing matches "${query}".` : emptyCopy[tab]} />
          )}
        </div>
      </article>
      {!loading && !error && <ListFooter page={safePage} pageSize={LIST_PAGE_SIZE} total={filtered.length} totalPages={totalPages} onPage={setPage} />}
    </section>
  );
}

/* Loads one private verification document as a blob and renders it, with click-to-zoom. */
function DocumentCard({ label, icon: DocIcon, path, onOpen }) {
  const [state, setState] = useState({ loading: !!path, src: null, error: !path });

  useEffect(() => {
    if (!path) { setState({ loading: false, src: null, error: true }); return; }
    let alive = true;
    let url = null;
    setState({ loading: true, src: null, error: false });
    api.verificationDocUrl(path)
      .then((objUrl) => { url = objUrl; if (alive) setState({ loading: false, src: objUrl, error: !objUrl }); })
      .catch(() => { if (alive) setState({ loading: false, src: null, error: true }); });
    return () => { alive = false; if (url) URL.revokeObjectURL(url); };
  }, [path]);

  return (
    <div className="document-card">
      <button
        className="document-preview"
        onClick={() => state.src && onOpen({ src: state.src, label })}
        disabled={!state.src}
        title={state.src ? "Click to enlarge" : undefined}
      >
        {state.loading && <span className="shimmer-fill" />}
        {!state.loading && state.src && <img src={state.src} alt={label} />}
        {!state.loading && !state.src && (
          <>
            <DocIcon size={36} strokeWidth={1.6} />
            <span className="encrypted">{state.error ? "Not available" : "No file"}</span>
          </>
        )}
      </button>
      <div className="doc-foot">
        <span>{label}</span>
        {state.src && <button className="ext" onClick={() => onOpen({ src: state.src, label })}><Maximize2 size={14} /></button>}
      </div>
    </div>
  );
}

function DocumentLightbox({ src, label, onClose }) {
  useEffect(() => {
    const onKey = (e) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);
  return (
    <div className="modal-backdrop lightbox" onClick={onClose}>
      <div className="lightbox-body" onClick={(e) => e.stopPropagation()}>
        <div className="lightbox-head">
          <span>{label}</span>
          <button className="modal-close" onClick={onClose}><X size={18} /></button>
        </div>
        <img src={src} alt={label} />
      </div>
    </div>
  );
}

function VerificationDetail({ provider, onBack, onApprove, onReject, onRequestInfo, onSuspend, onReactivate }) {
  const [decision, setDecision] = useState(null);
  const [note, setNote] = useState(provider.verificationNote || "");
  const [savedNote, setSavedNote] = useState(provider.verificationNote || "");
  const [rejectReason, setRejectReason] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [lightbox, setLightbox] = useState(null);

  const status = String(provider.status || "PENDING").toUpperCase();
  const isPending = status === "PENDING" || status === "NEEDS_RESUBMIT";

  async function confirm() {
    if (decision === "reject" && rejectReason.trim().length < 4) {
      toast("Enter a rejection reason to send to the provider.", "error");
      return;
    }
    setSubmitting(true);
    try {
      if (decision === "approve") await onApprove(provider.id);
      else await onReject(provider.id, rejectReason.trim());
    } catch { /* toast shown */ } finally { setSubmitting(false); }
  }

  function requestInfo() {
    setConfirm({
      eyebrow: "Provider verification",
      title: `Ask ${provider.name} for more info?`,
      body: "They stay in the pending queue and get this message as a notification.",
      input: { label: "Message to the provider", placeholder: "e.g. The ID back photo is blurry — please retake it in good light." },
      confirmLabel: "Send request",
      onConfirm: async (message) => {
        setSubmitting(true);
        try { await onRequestInfo(provider.id, message); } catch { /* toast shown */ } finally { setSubmitting(false); }
      }
    });
  }

  /** Internal note: admins only, never sent to the provider. */
  async function saveNote() {
    setSubmitting(true);
    try {
      await runAction(() => api.saveVerificationNote(provider.id, note.trim()), { success: "Note saved" });
      setSavedNote(note.trim());
    } catch { /* toast shown */ } finally { setSubmitting(false); }
  }
  const noteField = (
    <div>
      <textarea
        className="field-note"
        placeholder="Internal note (visible to admins only)…"
        value={note}
        onChange={(event) => setNote(event.target.value)}
      />
      {note.trim() !== savedNote && (
        <button className="btn btn-ghost sm" onClick={saveNote} disabled={submitting} style={{ marginTop: 6 }}>Save note</button>
      )}
    </div>
  );

  function confirmSuspend() {
    setConfirm({
      title: "Suspend this provider?",
      body: "They stop receiving new bookings immediately and their profile is hidden from search until you reactivate them. Their upcoming bookings that have not started are cancelled and the customers are notified.",
      confirmLabel: "Suspend provider",
      tone: "danger",
      onConfirm: async () => {
        setSubmitting(true);
        try { await onSuspend(provider.id); } catch { /* toast shown */ } finally { setSubmitting(false); }
      }
    });
  }

  function confirmReactivate() {
    setConfirm({
      title: "Reactivate this provider?",
      body: "Their profile becomes visible again and they can receive bookings.",
      confirmLabel: "Reactivate provider",
      onConfirm: async () => {
        setSubmitting(true);
        try { await onReactivate(provider.id); } catch { /* toast shown */ } finally { setSubmitting(false); }
      }
    });
  }

  const dp = provider.documentPaths || {};
  const docs = [
    { label: "National ID — front", icon: IdCard, path: dp.nationalIdFrontPath },
    { label: "National ID — back", icon: IdCard, path: dp.nationalIdBackPath },
    { label: "Live selfie", icon: ScanFace, path: dp.selfiePath }
  ];
  const bp = provider.business || {};
  const rows = [
    ["Owner full name", provider.ownerName || "—"],
    ["Business name", provider.name],
    ["Category", provider.category],
    ["City / district", provider.city],
    ["Coordinates", bp.coordinates || "Not set"],
    ["Services declared", bp.services || "None yet"],
    ["Gallery photos", bp.gallery],
    ["Accepted terms", bp.terms || "Not accepted"],
    ["Documents", provider.documents],
    ["Submitted", provider.submitted],
    ["Current status", prettyStatus(status)]
  ];
  if ((status === "REJECTED" || status === "NEEDS_RESUBMIT") && provider.risk && provider.risk !== "Low") {
    rows.push([status === "REJECTED" ? "Rejection reason" : "Info requested", provider.risk]);
  }

  const decisionCopy = {
    APPROVED: "This provider is verified and live. They can receive bookings now.",
    REJECTED: "This application was rejected. You can re-review and approve it, or ask for more information.",
    SUSPENDED: "This provider is suspended and cannot receive new bookings."
  };

  return (
    <section className="page-content">
      <button className="detail-back" onClick={onBack}><ArrowLeft size={14} /> Back to queue</button>

      <div className="detail-hero">
        <div className="detail-hero-id">
          <Avatar name={provider.name} palette={provider.palette} size={64} />
          <div>
            <p className="eyebrow">Provider verification</p>
            <h1>{provider.name}</h1>
            <div className="sub">{provider.category} · {provider.city} · Submitted {provider.submitted}</div>
          </div>
        </div>
        <Status status={status} dot />
      </div>

      {/* Wrap identity documents in a proper card block (matches Business
          profile / Decision blocks below) so the eyebrow label has real
          breathing room and the section feels anchored instead of the label
          floating above bare document cards. */}
      <article className="detail-block">
        <p className="eyebrow" style={{ margin: "0 0 14px" }}>Identity documents</p>
        <div className="document-grid">
          {docs.map((doc) => (
            <DocumentCard key={doc.label} label={doc.label} icon={doc.icon} path={doc.path} onOpen={setLightbox} />
          ))}
        </div>
      </article>
      {lightbox && <DocumentLightbox src={lightbox.src} label={lightbox.label} onClose={() => setLightbox(null)} />}

      <div className="detail-cols">
        <article className="detail-block">
          <p className="eyebrow">Business profile</p>
          <div className="kv-list">
            {rows.map(([key, value]) => (
              <div className="kv-row" key={key}>
                <span className="k">{key}</span>
                <span className="v">{value}</span>
              </div>
            ))}
          </div>
        </article>

        <article className="detail-block decision">
          <p className="eyebrow">{isPending ? "Decision" : "Manage provider"}</p>

          {!can("SUPPORT") && <ReadOnlyNote need="SUPPORT" />}

          {can("SUPPORT") && !isPending && (
            <InlineBanner
              tone={status === "APPROVED" ? "success" : status === "SUSPENDED" ? "warn" : "danger"}
              body={decisionCopy[status] || "No further action needed."}
            />
          )}

          {can("SUPPORT") && isPending && (
            <>
              {noteField}
              {decision === "reject" && (
                <div>
                  <p className="eyebrow" style={{ marginBottom: 6 }}>Rejection reason · sent to provider</p>
                  <textarea
                    className="field-note reject"
                    placeholder="e.g. ID back image is unclear — please resubmit."
                    value={rejectReason}
                    onChange={(event) => setRejectReason(event.target.value)}
                  />
                </div>
              )}
              <div className="decision-actions">
                <button className={`btn full ${decision === "approve" ? "btn-primary" : "btn-secondary"}`} onClick={() => setDecision("approve")}>
                  <Check size={16} /> Approve provider
                </button>
                <button className={`btn full ${decision === "reject" ? "btn-danger" : "btn-secondary"}`} onClick={() => setDecision("reject")}>
                  <X size={16} /> Reject with reason
                </button>
                <button className="btn btn-ghost full" onClick={requestInfo} disabled={submitting}>Request more info</button>
              </div>
              {decision && (
                <button className="btn btn-primary full" onClick={confirm} disabled={submitting}>
                  {submitting ? "Working…" : `Confirm ${decision === "approve" ? "approval" : "rejection"}`}
                </button>
              )}
            </>
          )}

          {can("SUPPORT") && status === "APPROVED" && (
            <div className="decision-actions" style={{ marginTop: 12 }}>
              <button className="btn btn-danger full" onClick={confirmSuspend} disabled={submitting}>
                <ShieldAlert size={16} /> Suspend provider
              </button>
            </div>
          )}

          {can("SUPPORT") && status === "SUSPENDED" && (
            <div className="decision-actions" style={{ marginTop: 12 }}>
              <button className="btn btn-primary full" onClick={confirmReactivate} disabled={submitting}>
                <Check size={16} /> Reactivate provider
              </button>
            </div>
          )}

          {can("SUPPORT") && status === "REJECTED" && (
            <div className="decision-actions" style={{ marginTop: 12 }}>
              <button className="btn btn-primary full" onClick={() => onApprove(provider.id)} disabled={submitting}>
                <Check size={16} /> Approve provider
              </button>
              {noteField}
              <button className="btn btn-ghost full" onClick={requestInfo} disabled={submitting}>Request more info</button>
            </div>
          )}
        </article>
      </div>
    </section>
  );
}

/* ─────────────────────────── Complaints ─────────────────────────── */
const LIST_PAGE_SIZE = 10;

/**
 * Case-insensitive multi-token text match against an arbitrary list of fields.
 * Empty query → matches everything. Whitespace-separated tokens all have to
 * match somewhere (AND semantics) so longer queries narrow rather than widen.
 * Field values are stringified and joined into a single haystack per item.
 */
function matchesQuery(item, query, fields) {
  const tokens = String(query || "").trim().toLowerCase().split(/\s+/).filter(Boolean);
  if (tokens.length === 0) return true;
  const haystack = fields
    .map((f) => item?.[f])
    .filter((v) => v != null)
    .map((v) => (Array.isArray(v) ? v.join(" ") : String(v)))
    .join(" ")
    .toLowerCase();
  return tokens.every((t) => haystack.includes(t));
}

/**
 * Standalone search input that visually matches the app's other search boxes
 * (magnifying glass icon, rounded, cream). Used on pages that don't need the
 * full <Toolbar> (no filter chips, or chips already live in the PageHeader).
 */
function SearchBar({ value, onChange, placeholder = "Search…" }) {
  return (
    <div className="toolbar-search" style={{ marginBottom: 14 }}>
      <Search size={15} />
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        aria-label={placeholder}
      />
      {value && (
        <button type="button" className="btn btn-ghost sm" onClick={() => onChange("")} aria-label="Clear search" style={{ marginLeft: 4 }}>
          Clear
        </button>
      )}
    </div>
  );
}

function ListFooter({ page, pageSize, total, totalPages, onPage }) {
  if (total === 0) return null;
  return (
    <div className="table-footer">
      <span className="dim">{(page - 1) * pageSize + 1}–{Math.min(page * pageSize, total)} of {total}</span>
      <Pagination page={page} totalPages={totalPages} onPage={onPage} />
    </div>
  );
}

function Complaints() {
  const { data, setData, error, loading, reload } = useLoad(api.complaints, mock.complaints);
  const [filter, setFilter] = useState("ALL");
  const [query, setQuery] = useState("");
  const [busyId, setBusyId] = useState(null);
  const [page, setPage] = useState(1);

  useEffect(() => { setPage(1); }, [filter, query]);

  function resolve(complaint) {
    setConfirm({
      eyebrow: [complaint.category, complaint.bookingId ? `Booking #${complaint.bookingId}` : null].filter(Boolean).join(" · ") || "Complaint",
      title: `Resolve ${complaint.customer}'s complaint?`,
      body: complaint.description || complaint.subject,
      input: { label: "Resolution notes", placeholder: "What was done — saved on the complaint for other admins…" },
      confirmLabel: "Mark resolved",
      onConfirm: async (notes) => {
        setBusyId(complaint.id);
        try {
          await runAction(() => api.resolveComplaint(complaint.id, notes), { success: "Complaint resolved" });
          setData((current) => current.map((item) => (item.id === complaint.id ? { ...item, status: "RESOLVED", adminNotes: notes } : item)));
        } catch { /* toast shown */ } finally { setBusyId(null); }
      }
    });
  }

  function flag(complaint) {
    setConfirm({
      title: `Escalate ${complaint.customer}'s complaint?`,
      body: "It moves to the Flags queue for trust & safety review. The provider is not notified.",
      confirmLabel: "Escalate to Flags",
      onConfirm: async () => {
        setBusyId(complaint.id);
        try {
          await runAction(() => api.flagComplaint(complaint.id), { success: "Complaint escalated to Flags" });
          setData((current) => current.map((item) => (item.id === complaint.id ? { ...item, priority: "High", flagged: true } : item)));
        } catch { /* toast shown */ } finally { setBusyId(null); }
      }
    });
  }

  const rows = data
    .filter((item) => filter === "ALL" || item.status === filter)
    .filter((item) => matchesQuery(item, query, ["customer", "provider", "subject", "priority", "status", "when"]));
  const totalPages = Math.max(1, Math.ceil(rows.length / LIST_PAGE_SIZE));
  const safePage = Math.min(page, totalPages);
  const pageRows = rows.slice((safePage - 1) * LIST_PAGE_SIZE, safePage * LIST_PAGE_SIZE);
  const chip = (id, label) => (
    <button className={`chip ${filter === id ? "active" : ""}`} onClick={() => setFilter(id)}>{label}</button>
  );

  return (
    <section className="page-content">
      <PageHeader
        eyebrow="Customer reports"
        title="Complaints"
        right={<>{chip("ALL", `All (${data.length})`)}{chip("OPEN", "Open")}{chip("UNDER_REVIEW", "In review")}{chip("RESOLVED", "Resolved")}</>}
      />
      <ReadOnlyNote need="SUPPORT" />
      <SearchBar value={query} onChange={setQuery} placeholder="Search customer, provider, subject, priority, status…" />
      <article className="table-card">
        <div className="table-scroll">
          <div className="table header complaints">
            <span>Customer</span><span>Provider</span><span>Subject</span><span>Priority</span><span>Status</span><span>When</span><span />
          </div>
          {pageRows.map((complaint) => (
            <div className="table row complaints" key={complaint.id}>
              <span className="strong-cell">{complaint.customer}</span>
              <span>{complaint.provider}</span>
              <span>{complaint.subject}</span>
              <Priority value={complaint.priority} />
              <Status status={complaint.status} />
              <span className="dim">{complaint.when}</span>
              <span className="cell-end" style={{ gap: 6 }}>
                {can("SUPPORT") && complaint.status !== "RESOLVED" && !complaint.flagged && (
                  <button className="btn btn-ghost sm" onClick={() => flag(complaint)} disabled={busyId === complaint.id}>
                    <ShieldAlert size={13} /> Escalate
                  </button>
                )}
                <button className="btn btn-ghost sm" onClick={() => resolve(complaint)} title={complaint.adminNotes || undefined} disabled={!can("SUPPORT") || complaint.status === "RESOLVED" || busyId === complaint.id}>
                  {complaint.status === "RESOLVED" ? "Resolved" : busyId === complaint.id ? "…" : "Resolve"}
                </button>
              </span>
            </div>
          ))}
          {loading && <SkeletonRows cols={7} />}
          {error && !loading && <StateBlock variant="error" body={`Could not load complaints: ${error}`} onAction={reload} />}
          {!loading && !error && rows.length === 0 && <StateBlock variant="empty" icon={Flag} title="No complaints" body="Nothing matches this filter right now." />}
        </div>
      </article>
      {!loading && !error && <ListFooter page={safePage} pageSize={LIST_PAGE_SIZE} total={rows.length} totalPages={totalPages} onPage={setPage} />}
    </section>
  );
}

/* ─────────────────────────── Flags ─────────────────────────── */
const FLAGS = [
  { id: "f1", type: "provider", name: "Yousef Beauty", reason: "Refused to honor agreed price", reporter: "Customer", when: "4 hours ago" },
  { id: "f2", type: "customer", name: "Karim Helmi", reason: "Rude / unsafe behavior toward staff", reporter: "Provider", when: "1 day ago" },
  { id: "f3", type: "provider", name: "Hala Skin Studio", reason: "Identity feels suspicious", reporter: "Customer", when: "2 days ago" }
];

export function Flags() {
  const { data, setData, error, loading, reload } = useLoad(api.flags, FLAGS);
  const [openId, setOpenId] = useState(null);
  const [query, setQuery] = useState("");
  const [busyId, setBusyId] = useState(null);
  const [page, setPage] = useState(1);
  useEffect(() => { setPage(1); }, [query]);

  const filtered = data.filter((f) => matchesQuery(f, query, ["type", "name", "reason", "reporter"]));
  const totalPages = Math.max(1, Math.ceil(filtered.length / LIST_PAGE_SIZE));
  const safePage = Math.min(page, totalPages);
  const pageRows = filtered.slice((safePage - 1) * LIST_PAGE_SIZE, safePage * LIST_PAGE_SIZE);

  // Every action here contacts a real person or closes out a complaint — no
  // silent one-tap fires. Even Dismiss goes through a confirm because it's a
  // policy decision (marks the underlying complaint resolved with no action).
  function dismiss(flag) {
    setConfirm({
      title: `Dismiss this flag?`,
      body: `Marks the complaint against ${flag.name} as reviewed with no action taken. The row goes away and the complaint is closed.`,
      confirmLabel: "Dismiss flag",
      tone: "plum",
      onConfirm: () => doDismiss(flag)
    });
  }
  async function doDismiss(flag) {
    setBusyId(flag.id);
    try {
      await runAction(() => api.resolveComplaint(flag.id, "Reviewed — no action taken"), { success: "Flag dismissed" });
      setData((current) => current.filter((entry) => entry.id !== flag.id));
      setOpenId(null);
    } catch { /* toast shown */ } finally { setBusyId(null); }
  }

  function warn(flag) {
    if (flag.targetUserId == null) { toast("This flag has no target user to warn.", "error"); return; }
    setConfirm({
      title: `Send a warning to ${flag.name}?`,
      body: `They will receive a notification saying they've been warned in relation to: "${flag.reason}". This is on the record and cannot be recalled.`,
      confirmLabel: "Send warning",
      tone: "danger",
      onConfirm: () => doWarn(flag)
    });
  }
  async function doWarn(flag) {
    setBusyId(flag.id);
    try {
      await runAction(() => api.warnUser(flag.targetUserId, flag.reason), { success: `Warning sent to ${flag.name}` });
      // Taking action on a flag is how it gets resolved — without this it comes
      // right back on the next refresh even though it was just handled.
      await api.resolveComplaint(flag.id, `Warned ${flag.name}`).catch(() => {});
      setData((current) => current.filter((entry) => entry.id !== flag.id));
      setOpenId(null);
    } catch { /* toast shown */ } finally { setBusyId(null); }
  }

  function suspend(flag) {
    const isProvider = flag.targetProviderId != null;
    if (!isProvider && flag.targetUserId == null) { toast("This flag has no account to suspend.", "error"); return; }
    setConfirm({
      title: `Suspend ${flag.name}?`,
      body: isProvider
        ? "Their profile is hidden until an admin reactivates them. Their upcoming bookings that have not started are cancelled and the customers are notified."
        : "They will lose access to the app until an admin reactivates the account.",
      confirmLabel: "Suspend",
      tone: "danger",
      onConfirm: () => doSuspend(flag, isProvider)
    });
  }

  async function doSuspend(flag, isProvider) {
    setBusyId(flag.id);
    try {
      await runAction(
        () => (isProvider ? api.suspendProvider(flag.targetProviderId) : api.deactivateUser(flag.targetUserId)),
        { success: `${flag.name} suspended` }
      );
      // Same reason as warn(): mark the underlying complaint resolved + unflagged
      // so it doesn't reappear in this list on the next load.
      await api.resolveComplaint(flag.id, `Suspended ${flag.name}`).catch(() => {});
      setData((current) => current.filter((entry) => entry.id !== flag.id));
      setOpenId(null);
    } catch { /* toast shown */ } finally { setBusyId(null); }
  }

  return (
    <section className="page-content">
      <PageHeader eyebrow="Trust & safety" title="Flags" />
      <ReadOnlyNote need="SUPPORT" />
      <SearchBar value={query} onChange={setQuery} placeholder="Search type, name, reason, reporter…" />
      <article className="table-card">
        <div className="table-scroll">
          <div className="table header flags">
            <span>Type</span><span>Flagged party</span><span>Reason</span><span>Reported by</span><span />
          </div>
          {pageRows.map((flag) => {
            const isOpen = openId === flag.id;
            return (
              <React.Fragment key={flag.id}>
                <div className={`table row flags ${isOpen ? "no-border" : ""}`}>
                  <span><RolePill role={flag.type} /></span>
                  <span className="strong-cell">{flag.name}</span>
                  <span>{flag.reason}</span>
                  <span className="dim">{flag.reporter}</span>
                  <span className="cell-end">
                    <button className="btn btn-ghost sm" onClick={() => setOpenId(isOpen ? null : flag.id)}>{isOpen ? "Close" : "Review"}</button>
                  </span>
                </div>
                {isOpen && (
                  <div className="flag-actions">
                    <button className="btn btn-secondary sm" disabled={!can("SUPPORT") || flag.targetUserId == null || busyId === flag.id}
                      title={flag.targetUserId == null ? "No target user to warn on this flag" : ""}
                      onClick={() => warn(flag)}>
                      Send warning
                    </button>
                    <button className="btn btn-danger sm" disabled={!can("SUPPORT") || busyId === flag.id} onClick={() => suspend(flag)}>
                      Suspend / ban
                    </button>
                    <button className="btn btn-ghost sm" disabled={!can("SUPPORT") || busyId === flag.id} onClick={() => dismiss(flag)}>Dismiss</button>
                  </div>
                )}
              </React.Fragment>
            );
          })}
          {loading && <SkeletonRows cols={5} />}
          {error && !loading && <StateBlock variant="error" body={`Could not load flags: ${error}`} onAction={reload} />}
          {!loading && !error && filtered.length === 0 && (
            <StateBlock variant="empty" icon={ShieldAlert} title={query ? "No matches" : "No active flags"}
              body={query ? `Nothing matches "${query}".` : "Flagged providers and customers appear here for review."} />
          )}
        </div>
      </article>
      {!loading && !error && <ListFooter page={safePage} pageSize={LIST_PAGE_SIZE} total={filtered.length} totalPages={totalPages} onPage={setPage} />}
    </section>
  );
}

/* ─────────────────────────── Users ─────────────────────────── */
const PERMISSION_META = {
  SUPER_ADMIN: { label: "Super admin", tone: "plum" },
  FINANCE: { label: "Finance", tone: "gold" },
  SUPPORT: { label: "Support", tone: "info" }
};

function UsersPage({ currentUser }) {
  const [data, setData] = useState([]);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [reloadKey, setReloadKey] = useState(0);
  const reload = () => setReloadKey((k) => k + 1);
  const [filter, setFilter] = useState("ALL");
  const [query, setQuery] = useState("");
  const [modalOpen, setModalOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(null);
  const [menuPos, setMenuPos] = useState(null);
  const [permsFor, setPermsFor] = useState(null);
  const [profileFor, setProfileFor] = useState(null);
  const [blockedNote, setBlockedNote] = useState(null);
  const [busyId, setBusyId] = useState(null);
  const [page, setPage] = useState(1);

  const PAGE_SIZE = 10;
  const isSuper = USE_MOCKS || (currentUser?.permissions || []).includes("SUPER_ADMIN");

  // Role filter, search (name / email / phone) and paging run on the server
  // (GET /admin/users), debounced — the list used to stop at 500 rows (OPS-8).
  useEffect(() => {
    let alive = true;
    setLoading(true);
    setError("");
    const handle = setTimeout(() => {
      api.users({ role: filter === "ALL" ? undefined : filter, query, page: page - 1, size: PAGE_SIZE })
        .then((result) => { if (alive) { setData(result.items); setTotalPages(result.totalPages); setTotal(result.total); } })
        .catch((err) => { if (alive) { setError(err.message || "Could not load users"); setData([]); } })
        .finally(() => { if (alive) setLoading(false); });
    }, 200);
    return () => { alive = false; clearTimeout(handle); };
  }, [filter, query, page, reloadKey]);

  useEffect(() => {
    appRefreshListeners.add(reload);
    return () => appRefreshListeners.delete(reload);
  }, []);

  useEffect(() => { setPage(1); }, [filter, query]);
  const rows = data;
  const pageRows = data;
  const safePage = Math.min(page, totalPages);

  async function createAdmin(payload) {
    const created = await api.createAdmin(payload);
    setData((current) => [
      { id: created?.id ?? `admin-${Date.now()}`, fullName: payload.fullName, email: payload.email,
        bookings: "—", joined: "Today", status: "ACTIVE", role: "ADMIN", palette: "gold",
        permissions: created?.permissions ?? payload.permissions ?? [] },
      ...current
    ]);
    setModalOpen(false);
    toast("Admin created", "ok");
  }

  async function activateUser(user) {
    setMenuOpen(null);
    setBusyId(user.id);
    try {
      // A provider whose account is still active but whose verification was suspended
      // needs the verification reactivated, not an account reactivation.
      const providerSuspended = user.active !== false && user.providerStatus === "SUSPENDED" && user.providerProfileId;
      if (providerSuspended) {
        await runAction(() => api.reactivateProvider(user.providerProfileId), { success: `${user.fullName} reactivated` });
        setData((current) => current.map((item) => (item.id === user.id ? { ...item, status: "ACTIVE", providerStatus: "APPROVED" } : item)));
      } else {
        await runAction(() => api.reactivateUser(user.id), { success: `${user.fullName} reactivated` });
        setData((current) => current.map((item) => (item.id === user.id ? { ...item, status: "ACTIVE" } : item)));
      }
    } catch { /* toast */ } finally { setBusyId(null); }
  }

  function requestDeactivate(user) {
    setMenuOpen(null);
    // The "last active super admin" rule is enforced by the backend; with a
    // paged list the panel can't count them itself (doDeactivate shows it).
    setConfirm({
      title: user.role === "ADMIN" ? "Deactivate admin?" : "Suspend account?",
      body: `${user.fullName} will be signed out and blocked until reactivated.`
        + (user.role === "PROVIDER" ? " Their upcoming bookings that have not started are cancelled and the customers are notified." : ""),
      confirmLabel: user.role === "ADMIN" ? "Deactivate" : "Suspend",
      tone: "danger",
      onConfirm: () => doDeactivate(user)
    });
  }

  async function doDeactivate(user) {
    setBusyId(user.id);
    try {
      await runAction(() => api.deactivateUser(user.id), { success: `${user.fullName} deactivated` });
      setData((current) => current.map((item) => (item.id === user.id ? { ...item, status: "SUSPENDED" } : item)));
    } catch (err) {
      if (/last active super admin/i.test(err.message || "")) setBlockedNote(err.message);
    } finally { setBusyId(null); }
  }

  function requestDelete(user) {
    setMenuOpen(null);
    setConfirm({
      title: "Delete account?",
      body: `${user.fullName}'s personal data is erased (name, contacts, addresses, ID documents, photos) and the account is closed. Past bookings stay as "Deleted user". This cannot be undone.`,
      confirmLabel: "Delete",
      tone: "danger",
      onConfirm: async () => {
        setBusyId(user.id);
        try {
          await runAction(() => api.deleteUser(user.id), { success: `${user.fullName} deleted` });
          setData((current) => current.filter((item) => item.id !== user.id));
        } catch { /* toast */ } finally { setBusyId(null); }
      }
    });
  }

  async function savePermissions(user, permissions) {
    setBusyId(user.id);
    try {
      const updated = await api.updateAdminPermissions(user.id, permissions);
      setData((current) => current.map((item) => (item.id === user.id ? { ...item, permissions: updated?.permissions ?? permissions } : item)));
      toast("Permissions updated", "ok");
      setPermsFor(null);
    } catch (err) {
      toast(err.message || "Could not update permissions", "error");
    } finally { setBusyId(null); }
  }

  const chip = (id, label) => (
    <button className={`chip ${filter === id ? "active" : ""}`} onClick={() => setFilter(id)}>{label}</button>
  );

  function openMenu(userId, event) {
    event.stopPropagation();
    if (menuOpen === userId) { setMenuOpen(null); return; }
    const rect = event.currentTarget.getBoundingClientRect();
    const MENU_W = 200;
    const MENU_H = 210;
    const flipUp = rect.bottom + MENU_H > window.innerHeight;
    setMenuPos({
      top: flipUp ? Math.max(8, rect.top - MENU_H - 6) : rect.bottom + 6,
      left: Math.max(8, rect.right - MENU_W)
    });
    setMenuOpen(userId);
  }

  useEffect(() => {
    if (menuOpen == null) return;
    const close = () => setMenuOpen(null);
    window.addEventListener("scroll", close, true);
    window.addEventListener("resize", close);
    return () => {
      window.removeEventListener("scroll", close, true);
      window.removeEventListener("resize", close);
    };
  }, [menuOpen]);

  function applyStatus(id, status, extra) {
    setData((current) => current.map((item) => (item.id === id ? { ...item, status, ...(extra || {}) } : item)));
  }

  function applyUserPatch(id, patch) {
    setData((current) => current.map((item) => (item.id === id ? { ...item, ...patch } : item)));
  }

  if (profileFor) {
    return (
      <ProfileView
        user={profileFor}
        currentUser={currentUser}
        onBack={() => { setProfileFor(null); reload(); }}
        onStatusChange={(status, extra) => applyStatus(profileFor.id, status, extra)}
        onUserChange={applyUserPatch}
      />
    );
  }

  return (
    <section className="page-content" onClick={() => setMenuOpen(null)}>
      <PageHeader
        eyebrow="Accounts"
        title="Users & providers"
        right={
          <>
            {chip("ALL", "All")}
            {chip("CUSTOMER", "Customers")}
            {chip("PROVIDER", "Providers")}
            {chip("ADMIN", "Admins")}
            {isSuper && <button className="btn btn-primary sm" onClick={() => setModalOpen(true)}><UserPlus size={15} /> Add admin</button>}
          </>
        }
      />

      {blockedNote && (
        <div style={{ marginBottom: 14 }}>
          <InlineBanner tone="warn" title="Blocked" body={blockedNote} />
          <button className="btn btn-ghost sm" style={{ marginTop: 6 }} onClick={() => setBlockedNote(null)}>Dismiss</button>
        </div>
      )}

      {/* Search across every visible column — name, email, phone, role,
          bookings, joined, status, and (for admins) permission labels. */}
      <div className="toolbar-search" style={{ marginBottom: 14 }}>
        <Search size={15} />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search name, email or phone…"
          aria-label="Search users"
        />
        {query && (
          <button
            type="button"
            className="btn btn-ghost sm"
            onClick={() => setQuery("")}
            aria-label="Clear search"
            style={{ marginLeft: 4 }}
          >
            Clear
          </button>
        )}
      </div>

      <article className="table-card">
        <div className="table-scroll">
          <div className="table header users">
            <span>Name / email</span><span>Role</span><span>Bookings</span><span>Joined</span><span>Status</span><span />
          </div>
          {loading && <SkeletonRows cols={6} />}
          {error && !loading && <StateBlock variant="error" body={`Could not load users: ${error}`} onAction={reload} />}
          {!loading && !error && rows.length === 0 && (
            <StateBlock
              variant="empty"
              title="No users here"
              body={query
                ? `Nothing matches "${query}"${filter !== "ALL" ? ` in ${filter.toLowerCase()}s` : ""}.`
                : "No accounts match this filter yet."}
            />
          )}
          {!loading && !error && pageRows.map((user) => (
            <div className="table row users" key={user.id}>
              <div className="user-identity">
                <ProfileCell name={user.fullName} subtitle={user.email} palette={user.palette} />
                {user.role === "ADMIN" && (user.permissions || []).length > 0 && (
                  <div className="perm-tags">
                    {user.permissions.map((p) => (
                      <Tag key={p} tone={PERMISSION_META[p]?.tone || "plum"}>{(PERMISSION_META[p]?.label || p).replace("_", " ")}</Tag>
                    ))}
                  </div>
                )}
              </div>
              <span><RolePill role={user.role} /></span>
              <span className="mono">{user.bookings}</span>
              <span className="dim">{user.joined}</span>
              <Status status={user.status} />
              <span className="cell-end">
                <button
                  className="circle-button"
                  aria-label={`Actions for ${user.fullName}`}
                  disabled={busyId === user.id}
                  onClick={(event) => openMenu(user.id, event)}
                >
                  <MoreHorizontal size={16} />
                </button>
                {menuOpen === user.id && menuPos && (
                  <div
                    className="row-menu floating"
                    style={{ position: "fixed", top: menuPos.top, left: menuPos.left }}
                    onClick={(event) => event.stopPropagation()}
                  >
                    <button className="row-menu-item" onClick={() => { setMenuOpen(null); setProfileFor(user); }}>
                      <Eye size={14} /> View profile
                    </button>
                    {can("SUPPORT") && (user.status === "ACTIVE"
                      ? <button className="row-menu-item danger" onClick={() => requestDeactivate(user)}>
                          <Ban size={14} /> {user.role === "ADMIN" ? "Deactivate" : "Suspend"}
                        </button>
                      : <button className="row-menu-item good" onClick={() => activateUser(user)}>
                          <Check size={14} /> {user.active !== false && user.providerStatus === "SUSPENDED" ? "Reactivate provider" : "Reactivate"}
                        </button>)}
                    {user.role === "ADMIN" && isSuper && (
                      <button className="row-menu-item" onClick={() => { setMenuOpen(null); setPermsFor(user); }}>
                        <ShieldAlert size={14} /> Edit permissions
                      </button>
                    )}
                    {can("SUPER_ADMIN") && (
                      <button className="row-menu-item danger" onClick={() => requestDelete(user)}>
                        <Trash2 size={14} /> Delete
                      </button>
                    )}
                  </div>
                )}
              </span>
            </div>
          ))}
        </div>
      </article>

      {!loading && !error && rows.length > 0 && (
        <div className="table-footer">
          <span className="dim">
            {(safePage - 1) * PAGE_SIZE + 1}–{(safePage - 1) * PAGE_SIZE + rows.length} of {total}
          </span>
          <Pagination page={safePage} totalPages={totalPages} onPage={setPage} />
        </div>
      )}

      {modalOpen && <AddAdminModal onClose={() => setModalOpen(false)} onCreate={createAdmin} />}
      {permsFor && <PermissionsModal user={permsFor} busy={busyId === permsFor.id} onClose={() => setPermsFor(null)} onSave={(perms) => savePermissions(permsFor, perms)} />}
    </section>
  );
}

/* ─────────────────────────── Profile view (customer / provider / admin) ─────────────────────────── */
/* Recent bookings / reviews / complaints for a customer or provider account. */
function ActivityBlock({ activity, isProvider }) {
  const [tab, setTab] = useState("bookings");
  if (!activity) {
    return (
      <article className="detail-block" style={{ marginTop: 14 }}>
        <p className="eyebrow">Activity</p>
        <SkeletonRows cols={1} rows={3} />
      </article>
    );
  }
  const bookings = activity.bookings || [];
  const reviews = activity.reviews || [];
  const complaints = activity.complaints || [];
  const tabs = [
    ["bookings", `Bookings (${bookings.length})`],
    ["reviews", `Reviews (${reviews.length})`],
    ["complaints", `Complaints (${complaints.length})`]
  ];

  return (
    <article className="detail-block" style={{ marginTop: 14 }}>
      <p className="eyebrow">Activity</p>
      <div className="policy-tabs activity-block-tabs">
        {tabs.map(([id, label]) => (
          <button key={id} className={`chip ${tab === id ? "active" : ""}`} onClick={() => setTab(id)}>{label}</button>
        ))}
      </div>

      {tab === "bookings" && (bookings.length === 0
        ? <p className="muted">No bookings on this account.</p>
        : <div className="activity-rows">
            {bookings.map((b) => (
              <div className="activity-mini" key={b.id}>
                <div>
                  <strong>{b.service}</strong>
                  <span className="dim"> · {isProvider ? "for " : "with "}{b.counterparty}</span>
                </div>
                <div className="activity-mini-meta">
                  <Status status={b.status} />
                  <span className="mono">{money(b.amount)}</span>
                  <span className="dim">{formatWhen(b.date || b.createdAt)}</span>
                </div>
              </div>
            ))}
          </div>)}

      {tab === "reviews" && (reviews.length === 0
        ? <p className="muted">This account hasn't written any reviews.</p>
        : <div className="activity-rows">
            {reviews.map((r) => (
              <div className="activity-mini" key={r.id}>
                <div>
                  <strong>{r.providerName}</strong> <Stars value={r.rating} />
                  {r.hidden && <Tag tone="plum">Hidden</Tag>}
                  <p className="review-text" style={{ margin: "4px 0 0" }}>{"“" + (r.comment || "") + "”"}</p>
                </div>
                <span className="dim">{formatWhen(r.createdAt)}</span>
              </div>
            ))}
          </div>)}

      {tab === "complaints" && (complaints.length === 0
        ? <p className="muted">This account hasn't filed any complaints.</p>
        : <div className="activity-rows">
            {complaints.map((c) => (
              <div className="activity-mini" key={c.id}>
                <div><strong>{c.subject}</strong> {c.flagged && <Tag tone="danger">Escalated</Tag>}</div>
                <div className="activity-mini-meta">
                  <Status status={c.status} />
                  <span className="dim">{formatWhen(c.createdAt)}</span>
                </div>
              </div>
            ))}
          </div>)}
    </article>
  );
}

/* The signed-in admin's own profile — opened from the sidebar account card. */
function MyProfile({ currentUser, onBack, onSelfPatch }) {
  const [user, setUser] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    let alive = true;
    setError("");
    api.userDetail(currentUser.id)
      .then((u) => { if (alive) setUser(u); })
      .catch((e) => { if (alive) setError(e.message || "Could not load your profile."); });
    return () => { alive = false; };
  }, [currentUser.id]);

  if (error) {
    return (
      <section className="page-content">
        <button className="detail-back" onClick={onBack}><ArrowLeft size={14} /> Back to dashboard</button>
        <StateBlock variant="error" body={error} onAction={onBack} />
      </section>
    );
  }
  if (!user) {
    return <section className="page-content"><SkeletonRows cols={2} rows={4} /></section>;
  }
  return (
    <ProfileView
      user={user}
      currentUser={currentUser}
      selfView
      onBack={onBack}
      onStatusChange={() => {}}
      onUserChange={(_id, patch) => onSelfPatch && onSelfPatch(patch)}
    />
  );
}

export function ProfileView({ user: userProp, onBack, onStatusChange, onUserChange, currentUser, selfView = false }) {
  const [user, setUser] = useState(userProp);
  const isProvider = user.role === "PROVIDER" && user.providerProfileId != null;
  const isAdmin = user.role === "ADMIN";
  const isSelf = selfView || (currentUser?.id != null && String(currentUser.id) === String(user.id));
  const [provider, setProvider] = useState(null);
  const [accountActive, setAccountActive] = useState(user.active !== false);
  const [verification, setVerification] = useState(user.providerStatus || null);
  const [loading, setLoading] = useState(isProvider);
  const [activity, setActivity] = useState(null);
  const [busy, setBusy] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [permsOpen, setPermsOpen] = useState(false);
  const [tempPw, setTempPw] = useState(null);

  // Editing another admin's account (details, permissions, password) needs super admin.
  const canManageThis = isAdmin ? (USE_MOCKS || (currentUser?.permissions || []).includes("SUPER_ADMIN")) : can("SUPPORT");
  // Your own profile: a super admin can still fix their own contact details
  // (the backend allows a super admin to edit an admin record), but nobody
  // changes their own permissions, resets their own password here, or
  // suspends themselves.
  const canEditDetails = canManageThis; // for an admin target this means super admin
  const canEditPermissions = !isSelf && isAdmin && canManageThis;
  const canResetPassword = !isSelf && canManageThis;
  const showAccountActions = !isSelf;

  async function saveDetails(fields) {
    setBusy(true);
    try {
      const updated = await runAction(() => api.editUser(user.id, fields), { success: "Details updated" });
      const merged = { ...user, ...updated, fullName: updated.fullName || user.fullName, email: updated.email || user.email, phone: updated.phone ?? user.phone };
      setUser(merged);
      onUserChange && onUserChange(user.id, { fullName: merged.fullName, email: merged.email, phone: merged.phone });
      setEditOpen(false);
    } catch { /* toast */ } finally { setBusy(false); }
  }

  async function savePermissions(perms) {
    setBusy(true);
    try {
      const updated = await api.updateAdminPermissions(user.id, perms);
      const next = updated?.permissions ?? perms;
      setUser((u) => ({ ...u, permissions: next }));
      onUserChange && onUserChange(user.id, { permissions: next });
      toast("Permissions updated", "ok");
      setPermsOpen(false);
    } catch (err) { toast(err.message || "Could not update permissions", "error"); }
    finally { setBusy(false); }
  }

  function resetPassword() {
    setConfirm({
      title: `Reset ${user.fullName}'s password?`,
      body: "A one-time temporary password is generated. Their current password stops working immediately — give them the new one to sign in with.",
      confirmLabel: "Reset password",
      tone: "danger",
      onConfirm: async () => {
        setBusy(true);
        try {
          const res = await runAction(() => api.resetUserPassword(user.id), { success: "Temporary password created" });
          if (res?.temporaryPassword) setTempPw(res.temporaryPassword);
        } catch { /* toast */ } finally { setBusy(false); }
      }
    });
  }

  const [staffList, setStaffList] = useState(null);

  useEffect(() => {
    if (!isProvider) return;
    let alive = true;
    setLoading(true);
    api.providerDetail(user.providerProfileId)
      .then((p) => { if (alive) { setProvider(p); setVerification(p.verificationStatus); } })
      .catch(() => {})
      .finally(() => { if (alive) setLoading(false); });
    // Admin-only listing — includes inactive/departed staff, unlike the
    // provider object above (which rides the public booking-flow endpoint).
    api.providerStaff(user.providerProfileId)
      .then((rows) => { if (alive) setStaffList(rows); })
      .catch(() => { if (alive) setStaffList([]); });
    return () => { alive = false; };
  }, [isProvider, user.providerProfileId]);

  useEffect(() => {
    if (isAdmin) return;
    let alive = true;
    api.userActivity(user.id).then((a) => { if (alive) setActivity(a); }).catch(() => { if (alive) setActivity({ bookings: [], reviews: [], complaints: [] }); });
    return () => { alive = false; };
  }, [isAdmin, user.id]);

  const verificationSuspended = isProvider && verification === "SUSPENDED";
  // The badge shown to the admin: account suspension or verification suspension both read as "Suspended".
  const displayStatus = !accountActive ? "SUSPENDED" : verificationSuspended ? "SUSPENDED" : "ACTIVE";

  function pushStatus(nextAccountActive, nextVerification) {
    const next = !nextAccountActive ? "SUSPENDED"
      : nextVerification === "SUSPENDED" ? "SUSPENDED" : "ACTIVE";
    onStatusChange && onStatusChange(next, { active: nextAccountActive, providerStatus: nextVerification });
  }

  function toggleAccount() {
    const active = accountActive;
    setConfirm({
      title: active ? `${user.role === "ADMIN" ? "Deactivate" : "Suspend"} ${user.fullName}'s account?` : `Reactivate ${user.fullName}'s account?`,
      body: active
        ? "They are signed out and can't use the app until reactivated. This is separate from provider verification and any settlement pause."
        : "They regain full access to the app.",
      confirmLabel: active ? (user.role === "ADMIN" ? "Deactivate" : "Suspend") : "Reactivate",
      tone: active ? "danger" : "plum",
      onConfirm: async () => {
        setBusy(true);
        try {
          await runAction(
            () => (active ? api.deactivateUser(user.id) : api.reactivateUser(user.id)),
            { success: active ? `${user.fullName} ${user.role === "ADMIN" ? "deactivated" : "suspended"}` : `${user.fullName} reactivated` }
          );
          setAccountActive(!active);
          pushStatus(!active, verification);
        } catch { /* toast */ } finally { setBusy(false); }
      }
    });
  }

  function toggleVerification() {
    const suspend = verification !== "SUSPENDED";
    setConfirm({
      title: suspend ? `Suspend ${user.fullName} as a provider?` : `Reactivate ${user.fullName} as a provider?`,
      body: suspend
        ? "Their profile is hidden from search and they stop receiving new bookings until reactivated. Their account login is unaffected."
        : "Their profile becomes visible again and they can receive bookings.",
      confirmLabel: suspend ? "Suspend provider" : "Reactivate provider",
      tone: suspend ? "danger" : "plum",
      onConfirm: async () => {
        setBusy(true);
        try {
          await runAction(
            () => (suspend ? api.suspendProvider(user.providerProfileId) : api.reactivateProvider(user.providerProfileId)),
            { success: suspend ? `${user.fullName} suspended` : `${user.fullName} reactivated` }
          );
          const next = suspend ? "SUSPENDED" : "APPROVED";
          setVerification(next);
          setProvider((p) => (p ? { ...p, verificationStatus: next } : p));
          pushStatus(accountActive, next);
        } catch { /* toast */ } finally { setBusy(false); }
      }
    });
  }

  // Same confirm as the Settlements screen (OPS-10): pausing stops a provider's income.
  function toggleBookingPause() {
    const paused = provider?.settlementPaused;
    setConfirm({
      tone: paused ? "plum" : "danger",
      eyebrow: "New bookings",
      title: paused ? `Resume bookings for ${user.fullName}?` : `Pause new bookings for ${user.fullName}?`,
      body: paused
        ? "They can receive new bookings again straight away."
        : "They stay listed but can't take new bookings until the balance is settled. Existing jobs continue.",
      confirmLabel: paused ? "Resume bookings" : "Pause bookings",
      onConfirm: async () => {
        setBusy(true);
        try {
          await runAction(() => api.setSettlementPause(user.providerProfileId, !paused),
            { success: paused ? "Bookings resumed" : "New bookings paused" });
          setProvider((p) => ({ ...p, settlementPaused: !paused }));
        } catch { /* toast */ } finally { setBusy(false); }
      }
    });
  }

  return (
    <section className="page-content">
      <button className="detail-back" onClick={onBack}><ArrowLeft size={14} /> {selfView ? "Back to dashboard" : "Back to users"}</button>

      <div className="detail-hero">
        <div className="detail-hero-id">
          <Avatar name={user.fullName} palette={user.palette} size={64} />
          <div>
            <p className="eyebrow">{user.role.toLowerCase()} profile</p>
            <h1>{user.fullName}</h1>
            <div className="sub">
              {user.email !== "-" ? user.email : user.phone || "—"}
              {isProvider && provider ? ` · ${provider.address || ""}` : ""}
            </div>
          </div>
        </div>
        <div style={{ display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap" }}>
          <Status status={displayStatus} />
          {isProvider && verificationSuspended && <Tag tone="danger">Provider suspended</Tag>}
          {isProvider && !accountActive && <Tag tone="danger">Account suspended</Tag>}
          {isProvider && provider?.settlementPaused && <Tag tone="warn">Bookings paused</Tag>}
        </div>
      </div>

      {loading && <SkeletonRows cols={2} rows={3} />}

      {!loading && (
        <div className="detail-cols">
          <div>
            <article className="detail-block">
              <div className="detail-block-head">
                <p className="eyebrow">Account</p>
                {canEditDetails && (
                  <button className="btn btn-ghost sm" onClick={() => setEditOpen(true)}>
                    <Settings size={13} /> Edit
                  </button>
                )}
              </div>
              <div className="kv-list">
                <div className="kv-row"><span className="k">Name</span><span className="v">{user.fullName}</span></div>
                <div className="kv-row"><span className="k">Role</span><span className="v"><RolePill role={user.role} /></span></div>
                <div className="kv-row"><span className="k">Email</span><span className="v">{user.email !== "-" ? user.email : "—"}</span></div>
                <div className="kv-row"><span className="k">Phone</span><span className="v">{user.phone || "—"}</span></div>
                <div className="kv-row"><span className="k">Joined</span><span className="v">{user.joined}</span></div>
                {!isAdmin && <div className="kv-row"><span className="k">Bookings</span><span className="v mono">{user.bookings}</span></div>}
                {user.role === "ADMIN" && (
                  <div className="kv-row"><span className="k">Permissions</span><span className="v">
                    {(user.permissions || []).length
                      ? user.permissions.map((p) => <Tag key={p} tone={PERMISSION_META[p]?.tone || "plum"}>{(PERMISSION_META[p]?.label || p)}</Tag>)
                      : "—"}
                  </span></div>
                )}
              </div>
            </article>

            {isProvider && provider && (
              <article className="detail-block" style={{ marginTop: 14 }}>
                <p className="eyebrow">Business</p>
                <div className="kv-list">
                  <div className="kv-row"><span className="k">Verification</span><span className="v"><Status status={provider.verificationStatus} /></span></div>
                  <div className="kv-row"><span className="k">Category</span><span className="v">{prettyStatus(provider.primaryCategory || "—")}</span></div>
                  <div className="kv-row"><span className="k">Rating</span><span className="v"><Stars value={Math.round(provider.averageRating || 0)} /> <span className="dim">{Number(provider.averageRating || 0).toFixed(1)} · {provider.totalReviews || 0} reviews</span></span></div>
                  <div className="kv-row"><span className="k">Type</span><span className="v">{prettyStatus(provider.providerType || "—")}</span></div>
                  <div className="kv-row"><span className="k">Bookings paused</span><span className="v">{provider.settlementPaused ? "Yes — settlement due" : "No"}</span></div>
                </div>
                {provider.services?.length > 0 && (
                  <div style={{ marginTop: 14 }}>
                    <p className="eyebrow" style={{ marginBottom: 8 }}>Services</p>
                    {provider.services.map((s) => (
                      <div className="kv-row" key={s.id}>
                        <span className="k">{s.name}</span>
                        <span className="v mono">EGP {Number(s.price || 0).toFixed(0)} · {s.durationMinutes}m</span>
                      </div>
                    ))}
                  </div>
                )}
                {provider.providerType === "SHOP" && (
                  <div style={{ marginTop: 14 }}>
                    <p className="eyebrow" style={{ marginBottom: 8 }}>
                      Staff{staffList?.length ? ` (${staffList.length})` : ""}
                    </p>
                    {staffList != null && !staffList.length && <p className="muted">No staff added yet.</p>}
                    {staffList?.map((s) => (
                      <div className="kv-row" key={s.id}>
                        <span className="k">
                          {s.fullName}
                          {s.title ? <span className="dim"> · {s.title}</span> : null}
                          {!s.active && <span style={{ marginLeft: 6 }}><Tag tone="danger">Inactive</Tag></span>}
                        </span>
                        <span className="v mono">{s.phone || "—"}</span>
                      </div>
                    ))}
                  </div>
                )}
              </article>
            )}

            {isProvider && provider && (
              <div style={{ marginTop: 14 }}>
                <ProviderOverridesCard providerId={user.providerProfileId} />
              </div>
            )}

            {!isAdmin && <ActivityBlock activity={activity} isProvider={isProvider} />}
          </div>

          <article className="detail-block">
            <p className="eyebrow">Actions</p>

            {isSelf && (
              <p className="muted" style={{ margin: "0 0 4px" }}>
                This is your own account.{canEditDetails ? " Update your name, email or phone from the Account card." : ""} Permission changes, password resets and account suspension are done by another super admin.
              </p>
            )}

            {isSelf && isAdmin && <TotpSetupCard />}

            {!isSelf && !can("SUPPORT") && !can("FINANCE") && <ReadOnlyNote need="SUPPORT" />}

            {showAccountActions && can("SUPPORT") && (
              <>
                <p className="muted" style={{ margin: "0 0 10px" }}>
                  Account access — signs the person out of the app entirely.
                </p>
                <button className={`btn full ${accountActive ? "btn-danger" : "btn-primary"}`} disabled={busy} onClick={toggleAccount}>
                  {accountActive ? <Ban size={15} /> : <Check size={15} />}
                  {accountActive ? (user.role === "ADMIN" ? " Deactivate account" : " Suspend account") : " Reactivate account"}
                </button>
              </>
            )}

            {!isSelf && isProvider && provider && (
              <>
                {can("SUPPORT") && (
                  <>
                    <div className="hr" />
                    <p className="eyebrow">Provider verification</p>
                    <p className="muted" style={{ margin: "0 0 10px" }}>
                      Suspending hides the profile from search and stops new bookings. Login still works.
                    </p>
                    <button
                      className={`btn full ${verificationSuspended ? "btn-primary" : "btn-danger"}`}
                      disabled={busy || (verification !== "APPROVED" && verification !== "SUSPENDED")}
                      onClick={toggleVerification}
                    >
                      {verificationSuspended ? <><Check size={15} /> Reactivate provider</> : <><ShieldAlert size={15} /> Suspend provider</>}
                    </button>
                  </>
                )}

                {can("FINANCE") && (
                  <>
                    <div className="hr" />
                    <p className="eyebrow">Bookings</p>
                    <p className="muted" style={{ margin: "0 0 10px" }}>
                      Pausing blocks new bookings until the provider settles their balance. The account stays active either way.
                    </p>
                    <button className={`btn full ${provider.settlementPaused ? "btn-primary" : "btn-secondary"}`} disabled={busy} onClick={toggleBookingPause}>
                      {provider.settlementPaused ? "Resume new bookings" : "Pause new bookings"}
                    </button>
                  </>
                )}
              </>
            )}

            {(canEditPermissions || canResetPassword) && (
              <>
                <div className="hr" />
                <p className="eyebrow">Access &amp; security</p>
                {canEditPermissions && (
                  <button className="btn btn-secondary full" disabled={busy} onClick={() => setPermsOpen(true)} style={{ marginBottom: 8 }}>
                    <ShieldAlert size={15} /> Edit permissions
                  </button>
                )}
                {canResetPassword && (
                  <>
                    <p className="muted" style={{ margin: "0 0 10px" }}>
                      Generates a one-time temporary password for a locked-out user.
                    </p>
                    <button className="btn btn-secondary full" disabled={busy} onClick={resetPassword}>
                      <RotateCw size={15} /> Reset password
                    </button>
                  </>
                )}
              </>
            )}
          </article>
        </div>
      )}

      {editOpen && (
        <EditUserModal user={user} busy={busy} onClose={() => setEditOpen(false)} onSave={saveDetails} />
      )}
      {permsOpen && (
        <PermissionsModal user={user} busy={busy} onClose={() => setPermsOpen(false)} onSave={savePermissions} />
      )}
      {tempPw && (
        <TempPasswordModal name={user.fullName} password={tempPw} onClose={() => setTempPw(null)} />
      )}
    </section>
  );
}

/* Two-factor (TOTP) setup/disable for the signed-in admin's own account. */
/**
 * Small live-updating clock showing the server's time so a user setting up
 * TOTP can immediately see whether their phone is out of sync. Uses one
 * server round-trip (to learn the offset from the browser clock) then ticks
 * locally so we don't hammer the endpoint every second.
 */
function ServerClockHint() {
  const [offsetMs, setOffsetMs] = useState(null);
  const [toleranceSeconds, setToleranceSeconds] = useState(30); // replaced by the server's own value
  const [now, setNow] = useState(Date.now());

  useEffect(() => {
    let alive = true;
    const t0 = Date.now();
    api.totpServerTime()
      .then((d) => {
        if (!alive) return;
        const rttGuess = (Date.now() - t0) / 2;
        setOffsetMs(d.epochMillis - Date.now() + rttGuess);
        if (d.driftToleranceSeconds > 0) setToleranceSeconds(d.driftToleranceSeconds);
      })
      .catch(() => { /* silent — the hint just won't show */ });
    const tick = setInterval(() => setNow(Date.now()), 1000);
    return () => { alive = false; clearInterval(tick); };
  }, []);

  if (offsetMs == null) return null;
  // Cairo time — this is what the user sees on their phone (Egypt is
  // Africa/Cairo, UTC+2 with DST). Matching timezones removes one layer of
  // mental arithmetic when comparing to Google Authenticator's phone clock.
  const cairoTime = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Africa/Cairo",
    year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", second: "2-digit",
    hour12: false
  }).format(new Date(now + offsetMs));
  return (
    <div
      className="muted small"
      style={{
        margin: "0 0 12px",
        padding: "8px 10px",
        borderRadius: 8,
        background: "var(--cream)",
        border: "1px dashed var(--divider)",
        fontFamily: "var(--font-mono)",
        fontSize: 12
      }}
    >
      Server time (Cairo): <strong>{cairoTime}</strong>
      <br />
      <span style={{ fontFamily: "var(--font-body)" }}>
        Your phone's clock must be within {toleranceSeconds} seconds of this — otherwise every code will be rejected.
      </span>
    </div>
  );
}

export function TotpSetupCard() {
  const [status, setStatus] = useState(null); // null = loading
  const [error, setError] = useState("");
  const [setupData, setSetupData] = useState(null); // { secret, otpAuthUri } while mid-setup
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  // DR-017: changing 2FA needs the current password (and code when it's on).
  const [password, setPassword] = useState("");
  const [currentCode, setCurrentCode] = useState("");

  useEffect(() => {
    let alive = true;
    api.totpStatus()
      .then((s) => { if (alive) setStatus(!!s?.enabled); })
      .catch((e) => { if (alive) setError(e.message || "Could not load two-factor status."); });
    return () => { alive = false; };
  }, []);

  async function startSetup() {
    setBusy(true);
    setError("");
    try {
      const data = await api.totpSetup(password, currentCode);
      setSetupData(data);
      setPassword("");
      setCurrentCode("");
    } catch (e) {
      toast(e.message || "Could not start setup", "error");
    } finally {
      setBusy(false);
    }
  }

  async function confirmSetup(e) {
    e.preventDefault();
    setBusy(true);
    try {
      await runAction(() => api.totpEnable(code), { success: "Two-factor authentication enabled" });
      setStatus(true);
      setSetupData(null);
      setCode("");
    } catch { /* toast */ } finally { setBusy(false); }
  }

  function disable() {
    setConfirm({
      title: "Turn off two-factor authentication?",
      body: "You'll only need your password to sign in after this. You can turn it back on any time.",
      confirmLabel: "Turn off",
      tone: "danger",
      onConfirm: async () => {
        setBusy(true);
        try {
          await runAction(() => api.totpDisable(password, currentCode), { success: "Two-factor authentication disabled" });
          setStatus(false);
          setPassword("");
          setCurrentCode("");
        } catch { /* toast */ } finally { setBusy(false); }
      }
    });
  }

  return (
    <>
      <div className="hr" />
      <p className="eyebrow">Two-factor authentication</p>

      {status === null && !error && <p className="muted" style={{ margin: "0 0 10px" }}>Loading…</p>}
      {error && <p className="muted" style={{ margin: "0 0 10px" }}>{error}</p>}

      {status === false && !setupData && (
        <>
          <p className="muted" style={{ margin: "0 0 10px" }}>
            Require a 6-digit authenticator app code, in addition to your password, when you sign in.
          </p>
          <label className="stack-label" style={{ marginTop: 0, marginBottom: 10 }}>
            Your current password
            <input type="password" autoComplete="current-password" value={password}
              onChange={(ev) => setPassword(ev.target.value)} />
          </label>
          <button className="btn btn-secondary full" disabled={busy || !password} onClick={startSetup}>
            <ShieldAlert size={15} /> Set up two-factor authentication
          </button>
        </>
      )}

      {setupData && (
        <form onSubmit={confirmSetup}>
          <p className="muted" style={{ margin: "0 0 10px" }}>
            Add this account to your authenticator app (Google Authenticator, Authy, 1Password…), then enter the 6-digit code it shows.
          </p>

          {/* Clock-skew is the #1 cause of "code rejected" for TOTP. Show the
              server's current time live so a user whose phone is more than
              ~30s out of sync can eyeball the mismatch and fix their clock
              instead of retyping codes over and over. */}
          <ServerClockHint />


          {/* Secret in a bordered block with a Copy button — the whole reason
              the user is on this screen is to paste this into their app.
              Reusing the .temp-pw pattern (same as TempPasswordModal): mono,
              wraps long strings, contains a copy-to-clipboard button. */}
          <p className="eyebrow" style={{ margin: "0 0 6px" }}>Secret</p>
          <div className="temp-pw" style={{ marginBottom: 12 }}>
            <code>{setupData.secret}</code>
            <button
              type="button"
              className="btn btn-secondary sm"
              onClick={() => {
                try {
                  navigator.clipboard.writeText(setupData.secret);
                  toast("Secret copied to clipboard", "ok");
                } catch { /* ignore — user can still select the text */ }
              }}
            >
              Copy
            </button>
          </div>

          {/* Uses the app's `.stack-label` pattern (label above input) so the
              input inherits the same rounded / bordered / focus-glow styling
              as the rest of the form fields — plain <input> without a wrapping
              class gets almost no styling and looks like a raw browser default. */}
          <label className="stack-label" style={{ marginTop: 0, marginBottom: 14 }}>
            Code from your app
            <input
              value={code}
              onChange={(ev) => setCode(ev.target.value.replace(/\D/g, "").slice(0, 6))}
              inputMode="numeric"
              autoComplete="one-time-code"
              placeholder="6-digit code"
              required
              // A 6-digit OTP: big monospaced with wide letter-spacing reads
              // as a code, not a name — matches how auth apps display it.
              style={{
                fontFamily: "var(--font-mono)",
                fontSize: 20,
                letterSpacing: "0.35em",
                textAlign: "center",
                padding: "14px 12px"
              }}
            />
          </label>

          {/* Two full-width stacked buttons — primary action on top so it's the
              first thing the user sees, secondary underneath. Avoids the
              modal-actions flex layout which stretches oddly in narrow columns. */}
          <button className="btn btn-primary full" disabled={busy || code.length !== 6}>
            {busy ? "Confirming…" : "Confirm & enable"}
          </button>
          <button
            type="button"
            className="btn btn-ghost full"
            style={{ marginTop: 8 }}
            onClick={() => { setSetupData(null); setCode(""); }}
          >
            Cancel
          </button>
        </form>
      )}

      {status === true && (
        <>
          <p className="muted" style={{ margin: "0 0 10px" }}>
            <Check size={13} style={{ verticalAlign: "-2px" }} /> Enabled — a code from your authenticator app is required at sign-in.
          </p>
          <label className="stack-label" style={{ marginTop: 0, marginBottom: 10 }}>
            Your current password
            <input type="password" autoComplete="current-password" value={password}
              onChange={(ev) => setPassword(ev.target.value)} />
          </label>
          <label className="stack-label" style={{ marginTop: 0, marginBottom: 10 }}>
            Current code from your app
            <input inputMode="numeric" autoComplete="one-time-code" value={currentCode} placeholder="6-digit code"
              onChange={(ev) => setCurrentCode(ev.target.value.replace(/\D/g, "").slice(0, 6))} />
          </label>
          <button className="btn btn-danger full" disabled={busy || !password || currentCode.length !== 6} onClick={disable}>
            Turn off two-factor authentication
          </button>
        </>
      )}
    </>
  );
}

/* Admin edits a user's contact details. */
function EditUserModal({ user, busy, onClose, onSave }) {
  const [fullName, setFullName] = useState(user.fullName || "");
  const [email, setEmail] = useState(user.email && user.email !== "-" ? user.email : "");
  const [phone, setPhone] = useState(user.phone || "");
  const dirty = fullName.trim() !== (user.fullName || "")
    || email.trim() !== (user.email && user.email !== "-" ? user.email : "")
    || phone.trim() !== (user.phone || "");

  function submit(e) {
    e.preventDefault();
    if (fullName.trim().length < 2) { toast("Enter a valid name.", "error"); return; }
    if (!email.trim() && !phone.trim()) { toast("Keep at least an email or a phone.", "error"); return; }
    onSave({ fullName: fullName.trim(), email: email.trim(), phone: phone.trim() });
  }

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <form className="modal-card" onClick={(e) => e.stopPropagation()} onSubmit={submit}>
        <button type="button" className="modal-close" onClick={onClose}><X size={18} /></button>
        <p className="eyebrow">Account</p>
        <h2>Edit {user.fullName}</h2>
        <label>Full name<input value={fullName} onChange={(e) => setFullName(e.target.value)} /></label>
        <label>Email<input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="—" /></label>
        <label>Phone<input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="+20…" /></label>
        <div className="modal-actions">
          <button type="button" className="btn btn-secondary" onClick={onClose}>Cancel</button>
          <button className="btn btn-primary" disabled={busy || !dirty}>{busy ? "Saving…" : "Save changes"}</button>
        </div>
      </form>
    </div>
  );
}

/* Shows a freshly generated temporary password once, with copy. */
function TempPasswordModal({ name, password, onClose }) {
  const [copied, setCopied] = useState(false);
  function copy() {
    try { navigator.clipboard.writeText(password); setCopied(true); setTimeout(() => setCopied(false), 2000); } catch { /* ignore */ }
  }
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-card" onClick={(e) => e.stopPropagation()}>
        <button type="button" className="modal-close" onClick={onClose}><X size={18} /></button>
        <p className="eyebrow">Password reset</p>
        <h2>Temporary password for {name}</h2>
        <p className="muted" style={{ margin: "0 0 12px" }}>
          Give this to the user now — it won't be shown again. They should change it after signing in.
        </p>
        <div className="temp-pw">
          <code>{password}</code>
          <button className="btn btn-secondary sm" onClick={copy}>{copied ? <><Check size={14} /> Copied</> : <>Copy</>}</button>
        </div>
        <div className="modal-actions">
          <button className="btn btn-primary" onClick={onClose}>Done</button>
        </div>
      </div>
    </div>
  );
}

/* Edit an admin's permissions */
function PermissionsModal({ user, busy, onClose, onSave }) {
  const [selected, setSelected] = useState(user.permissions || []);
  const toggle = (id) => setSelected((cur) => (cur.includes(id) ? cur.filter((x) => x !== id) : [...cur, id]));
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <form className="modal-card" onClick={(e) => e.stopPropagation()} onSubmit={(e) => { e.preventDefault(); if (selected.length) onSave(selected); }}>
        <button type="button" className="modal-close" onClick={onClose}><X size={18} /></button>
        <p className="eyebrow">Access control</p>
        <h2>{user.fullName}'s permissions</h2>
        <PermissionPicker selected={selected} onToggle={toggle} />
        {selected.length === 0 && <div className="form-error">Select at least one permission.</div>}
        <div className="modal-actions">
          <button type="button" className="btn btn-secondary" onClick={onClose}>Cancel</button>
          <button className="btn btn-primary" disabled={busy || selected.length === 0}>{busy ? "Saving…" : "Save"}</button>
        </div>
      </form>
    </div>
  );
}

function PermissionPicker({ selected, onToggle }) {
  const opts = [
    { id: "SUPPORT", label: "Support", hint: "Chat moderation, complaints, flags" },
    { id: "FINANCE", label: "Finance", hint: "Payment disputes, settlements" },
    { id: "SUPER_ADMIN", label: "Super admin", hint: "Create admins, manage permissions" }
  ];
  return (
    <div className="perm-options">
      {opts.map((opt) => {
        const on = selected.includes(opt.id);
        return (
          <button type="button" key={opt.id} className={`perm-option ${on ? "on" : ""}`} onClick={() => onToggle(opt.id)}>
            <span className="perm-check">{on && <Check size={11} />}</span>
            <span>
              <span className="perm-label">{opt.label}</span>
              <span className="perm-hint">{opt.hint}</span>
            </span>
          </button>
        );
      })}
    </div>
  );
}

/* ─────────────────────────── Placeholder (roadmap) ─────────────────────────── */
function Placeholder({ title, icon: IconCmp }) {
  return (
    <section className="page-content">
      <PageHeader eyebrow="Coming next" title={title} />
      <article className="placeholder-card">
        <span className="placeholder-icon"><IconCmp size={28} /></span>
        <p className="placeholder-lead">This section is on the roadmap.</p>
        <p className="placeholder-body">
          The Dashboard, Verifications, Complaints, Flags, Users, Moderation and
          Settlements surfaces are functional — tell me which to build out next and
          I'll wire it up.
        </p>
      </article>
    </section>
  );
}

/* ─────────────────────────── Bookings ─────────────────────────── */
const BOOKINGS_PAGE_SIZE = 6;

/* Lifecycle timeline from the timestamps the booking actually carries. */
function fmtStamp(value) {
  if (!value) return "";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value);
  return d.toLocaleString("en-US", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });
}
function BookingTimeline({ booking }) {
  const events = [];
  if (booking.createdAt) events.push({ label: "Requested", when: booking.createdAt, tone: "info" });
  if (booking.proposedDate) events.push({ label: "New time proposed", when: null, tone: "warn", note: `${formatWhen(booking.proposedDate)} ${booking.proposedStartTime || ""}`.trim() });
  if (booking.checkedInAt) events.push({ label: "Provider checked in", when: booking.checkedInAt, tone: "success" });
  if (booking.cancelledAt) {
    events.push({
      label: `Cancelled${booking.cancelledBy ? ` by ${String(booking.cancelledBy).toLowerCase()}` : ""}`,
      when: booking.cancelledAt, tone: "danger", note: booking.cancellationReason || null
    });
  }
  events.push({ label: `Now: ${prettyStatus(booking.status)}`, when: null, tone: booking.status === "COMPLETED" ? "success" : booking.status === "CANCELLED" || booking.status === "NO_SHOW" || booking.status === "REJECTED" ? "danger" : "plum", current: true });

  return (
    <div className="booking-timeline">
      {events.map((e, i) => (
        <div className={`bt-node ${e.current ? "current" : ""}`} key={i}>
          <span className={`bt-dot ${e.tone}`} />
          <div className="bt-body">
            <strong>{e.label}</strong>
            {e.when && <span className="dim"> · {fmtStamp(e.when)}</span>}
            {e.note && <span className="bt-note">{e.note}</span>}
          </div>
        </div>
      ))}
    </div>
  );
}

function Bookings() {
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState("All");
  const [page, setPage] = useState(1);
  const [data, setData] = useState([]);
  const [totalPages, setTotalPages] = useState(1);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [reloadKey, setReloadKey] = useState(0);
  const [exporting, setExporting] = useState(false);
  const reload = () => setReloadKey((k) => k + 1);

  // Search, filter and paging run on the server (GET /admin/bookings), debounced.
  useEffect(() => {
    let alive = true;
    setLoading(true);
    setError("");
    const handle = setTimeout(() => {
      api.bookings({ query, filter, page: page - 1, size: BOOKINGS_PAGE_SIZE })
        .then((result) => { if (alive) { setData(result.items); setTotalPages(result.totalPages); } })
        .catch((err) => { if (alive) { setError(err.message || "Could not load bookings"); setData([]); } })
        .finally(() => { if (alive) setLoading(false); });
    }, 200);
    return () => { alive = false; clearTimeout(handle); };
  }, [query, filter, page, reloadKey]);

  useEffect(() => {
    let alive = true;
    api.bookingStats().then((next) => { if (alive) setStats(next); }).catch(() => {});
    return () => { alive = false; };
  }, [reloadKey]);

  useEffect(() => {
    appRefreshListeners.add(reload);
    return () => appRefreshListeners.delete(reload);
  }, []);

  async function exportCsv() {
    setExporting(true);
    try {
      await runAction(() => api.exportBookingList(query, filter), { success: "Bookings exported", failure: "Could not export bookings" });
    } catch { /* toast shown */ } finally { setExporting(false); }
  }
  const [openId, setOpenId] = useState(null);
  const [busyId, setBusyId] = useState(null);
  const [chat, setChat] = useState({ id: null, messages: null, loading: false });
  const [disputeFor, setDisputeFor] = useState(null);
  const [resolved, setResolved] = useState({});

  const filters = ["All", "Disputes", "Cancelled", "No-show", "Completed"];

  const patch = (id, changes) => setData((current) => current.map((row) => (row.id === id ? { ...row, ...changes } : row)));

  function forceCancel(booking) {
    setConfirm({
      title: `Force-cancel ${booking.ref}?`,
      body: "The booking is voided immediately and both parties are notified.",
      input: { label: "Reason · logged and sent to both parties", placeholder: "e.g. Provider reported a safety concern at the address." },
      confirmLabel: "Force cancel",
      tone: "danger",
      onConfirm: async (reason) => {
        setBusyId(booking.id);
        try {
          await runAction(() => api.forceCancelBooking(booking.id, reason), { success: `${booking.ref} cancelled` });
          patch(booking.id, { status: "CANCELLED", dispute: false });
        } catch { /* toast shown */ } finally { setBusyId(null); }
      }
    });
  }

  async function resolveDispute(booking, outcome, reason) {
    setBusyId(booking.id);
    try {
      await runAction(() => api.resolveDispute(booking.id, outcome, reason), { success: `Dispute resolved — ${DISPUTE_OUTCOME_LABEL[outcome]}` });
      const next = { dispute: false };
      if (outcome === "PAID") next.paymentStatus = "CASH_CONFIRMED";
      else if (outcome === "NO_SHOW") { next.paymentStatus = "UNPAID"; next.status = "NO_SHOW"; }
      else if (outcome === "CANCEL") { next.paymentStatus = "UNPAID"; next.status = "CANCELLED"; }
      else next.paymentStatus = "UNPAID";
      patch(booking.id, next);
      setResolved((cur) => ({ ...cur, [booking.id]: DISPUTE_OUTCOME_LABEL[outcome] }));
      setDisputeFor(null);
    } catch { /* toast shown */ } finally { setBusyId(null); }
  }

  async function viewChat(booking) {
    setChat({ id: booking.id, messages: null, loading: true });
    try {
      const messages = await api.bookingChat(booking.id);
      setChat({ id: booking.id, messages, loading: false });
    } catch (err) {
      setChat({ id: null, messages: null, loading: false });
      toast(err.message || "Could not load chat", "error");
    }
  }

  const isActive = (status) => ["PENDING", "ACCEPTED", "ON_THE_WAY", "ARRIVED", "IN_PROGRESS"].includes(status);

  const safePage = Math.min(page, totalPages);
  const pageRows = data;
  const disputes = stats?.openDisputes ?? 0;

  function changeFilter(next) { setFilter(next); setPage(1); setOpenId(null); }
  function changeQuery(next) { setQuery(next); setPage(1); }
  function clearFilters() { setQuery(""); setFilter("All"); setPage(1); }

  return (
    <section className="page-content">
      <PageHeader eyebrow="Operations" title="Bookings monitor"
        right={disputes > 0 ? <Tag tone="danger">{disputes} open dispute{disputes === 1 ? "" : "s"}</Tag> : null} />

      <StatTiles tiles={[
        { label: "Today", value: String(stats?.today ?? "—"), sub: "bookings" },
        { label: "In progress", value: String(stats?.inProgress ?? "—"), sub: "right now" },
        { label: "Disputes", value: String(stats?.openDisputes ?? "—"), sub: "need review" },
        { label: "Cancel rate", value: stats ? `${Number(stats.cancelRate7d).toFixed(1)}%` : "—", sub: "last 7 days" }
      ]} />

      <Toolbar query={query} onQuery={changeQuery} placeholder="Search booking, customer, provider…"
        filters={filters} activeFilter={filter} onFilter={changeFilter}
        right={
          <button className="btn btn-secondary sm" onClick={exportCsv} disabled={exporting}>
            <Download size={14} /> {exporting ? "Exporting…" : "Export CSV"}
          </button>
        } />
      {!can("FINANCE") && (
        <InlineBanner tone="info" title="View only" body="Resolving disputes and force-cancelling bookings needs the Finance permission." />
      )}

      <article className="table-card">
        <div className="table-scroll">
          <div className="table header bookings-monitor">
            <span>Ref</span><span>Customer</span><span>Provider</span><span>Service</span><span>When</span><span>Amount</span><span>Status</span>
          </div>
          {loading && <SkeletonRows cols={7} />}
          {error && !loading && <StateBlock variant="error" body={`Could not load bookings: ${error}`} onAction={reload} />}
          {!loading && !error && pageRows.length === 0 && (query || filter !== "All"
            ? <StateBlock variant="empty" icon={CalendarSearch} title="No bookings match" body="Try a different search term or clear the filters." actionLabel="Clear filters" onAction={clearFilters} />
            : <StateBlock variant="empty" icon={CalendarCheck} title="No bookings yet" body="Bookings appear here as customers make them." />)}
          {pageRows.map((booking) => (
            <div key={booking.id}>
              <div className="table row bookings-monitor clickable" onClick={() => setOpenId(openId === booking.id ? null : booking.id)}>
                <span className="mono ref-cell">{booking.ref}</span>
                <span className="strong-cell">{booking.customer}</span>
                <span>{booking.provider}</span>
                <span>{booking.service}</span>
                <span className="dim">{booking.date}</span>
                <span className="mono">{booking.total}</span>
                <span className="status-cell">
                  <Status status={booking.status} />
                  {booking.dispute && <Tag tone="danger">Dispute</Tag>}
                </span>
              </div>
              {openId === booking.id && (
                <div className="row-detail">
                  <div className="row-detail-grid">
                    <div><p className="eyebrow">Payment</p><span className="mono">{booking.paymentStatus}</span></div>
                    <div><p className="eyebrow">Commission</p><span className="mono">{booking.commissionAmount != null ? `EGP ${booking.commissionAmount.toFixed(2)}` : "Withheld"}</span></div>
                    <div><p className="eyebrow">Location</p><span className="mono">{booking.homeService ? "Home service" : "On-site"}</span></div>
                    <div><p className="eyebrow">When</p><span className="mono">{booking.date}</span></div>
                  </div>
                  {booking.travelFee != null && booking.travelFee > 0 && (
                    <div className="price-breakdown" style={{ display: "flex", gap: 24, flexWrap: "wrap", padding: "8px 0", borderTop: "1px dashed var(--plum-200)", marginTop: 4 }}>
                      <span className="dim">Service: <span className="mono">EGP {(booking.amount - booking.travelFee).toFixed(2)}</span></span>
                      <span className="dim">Travel: <span className="mono">EGP {booking.travelFee.toFixed(2)}</span></span>
                      <span><strong>Total: <span className="mono">EGP {booking.amount.toFixed(2)}</span></strong></span>
                    </div>
                  )}
                  <BookingTimeline booking={booking} />
                  {booking.penaltyApplied && <InlineBanner tone="warn" body={penaltyFlag(booking)} />}
                  {booking.rejectionReason && <InlineBanner tone="warn" title="Provider rejected" body={booking.rejectionReason} />}
                  {booking.dispute && !resolved[booking.id] && <InlineBanner tone="danger" title="Payment disputed" body="Customer reports the cash payment was not made. Commission is withheld until resolved." />}
                  {resolved[booking.id] && <InlineBanner tone="success" title={`Resolved · ${resolved[booking.id]}`} body="Both parties were notified and the audit log was updated." />}
                  <div className="detail-actions">
                    <button className="btn btn-secondary sm" disabled={busyId === booking.id || chat.loading} onClick={() => viewChat(booking)}>
                      <MessageSquareWarning size={14} /> View chat
                    </button>
                    {can("FINANCE") && booking.dispute && !resolved[booking.id] && (
                      <button className="btn btn-primary sm" disabled={busyId === booking.id} onClick={() => setDisputeFor(booking)}>
                        <AlertTriangle size={14} /> Resolve dispute
                      </button>
                    )}
                    {can("FINANCE") && isActive(booking.status) && (
                      <button className="btn btn-danger sm" disabled={busyId === booking.id} onClick={() => forceCancel(booking)}>
                        <XCircle size={14} /> Force cancel
                      </button>
                    )}
                  </div>
                  {chat.id === booking.id && (
                    <div className="chat-thread">
                      {chat.loading && <span className="dim">Loading chat…</span>}
                      {!chat.loading && chat.messages && chat.messages.length === 0 && <span className="dim">No messages in this booking.</span>}
                      {!chat.loading && chat.messages && chat.messages.map((message) => (
                        <div className="chat-msg" key={message.id}>
                          <span className="chat-sender">{message.sender?.fullName || "User"}</span>
                          <span className="chat-text">{message.message}</span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      </article>
      <Pagination page={safePage} totalPages={totalPages} onPage={setPage} />
      {disputeFor && (
        <DisputeResolutionSheet
          booking={disputeFor}
          busy={busyId === disputeFor.id}
          onClose={() => setDisputeFor(null)}
          onResolve={(outcome, reason) => resolveDispute(disputeFor, outcome, reason)}
        />
      )}
    </section>
  );
}

/** Kit flag copy: "Provider cancelled — penalty applied". */
function penaltyFlag(booking) {
  const who = booking.status === "NO_SHOW" ? "No-show" : booking.cancelledBy
    ? `${String(booking.cancelledBy).charAt(0)}${String(booking.cancelledBy).slice(1).toLowerCase()} cancelled`
    : "Cancelled";
  return `${who} — penalty applied`;
}

const DISPUTE_OUTCOME_LABEL = { PAID: "paid", UNPAID: "unpaid", NO_SHOW: "no-show", CANCEL: "cancelled" };

const DISPUTE_OUTCOMES = [
  { id: "PAID", icon: Banknote, tone: "good", label: "Mark as paid", hint: "Commission is charged as usual." },
  { id: "UNPAID", icon: XCircle, tone: "warn", label: "Mark as unpaid", hint: "No commission charged." },
  { id: "NO_SHOW", icon: Ban, tone: "warn", label: "Record no-show", hint: "Applies the standard no-show penalty." },
  { id: "CANCEL", icon: X, tone: "danger", label: "Cancel booking", hint: "Voids the booking entirely, reason logged." }
];

/* Payment dispute resolution — Evidence / Chat / History tabs + 4 outcomes. */
function DisputeResolutionSheet({ booking, busy, onClose, onResolve }) {
  const [tab, setTab] = useState("evidence");
  const [picked, setPicked] = useState(null);
  const [chat, setChat] = useState(null);

  useEffect(() => {
    let alive = true;
    if (tab === "chat" && chat === null) {
      api.bookingChat(booking.id).then((messages) => { if (alive) setChat(messages || []); }).catch(() => { if (alive) setChat([]); });
    }
    return () => { alive = false; };
  }, [tab, chat, booking.id]);

  const [reason, setReason] = useState("");
  const needsReason = picked === "CANCEL";

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="dispute-sheet" onClick={(e) => e.stopPropagation()} role="dialog" aria-modal="true">
        <button type="button" className="modal-close" onClick={onClose}><X size={18} /></button>
        <p className="eyebrow" style={{ color: "var(--danger-700)" }}>Payment dispute · {booking.ref}</p>
        <h2>{booking.customer} vs. {booking.provider}</h2>
        <p className="dispute-sub">{booking.service} · {booking.total} · {booking.date}</p>

        <div className="dispute-tabs">
          {[["evidence", "Evidence"], ["chat", "Chat"], ["history", "History"]].map(([id, label]) => (
            <button key={id} className={`chip ${tab === id ? "active" : ""}`} onClick={() => setTab(id)}>{label}</button>
          ))}
        </div>

        {tab === "evidence" && (
          <div className="dispute-panel">
            <strong>No photo evidence submitted</strong>
            <p>Neither party attached a receipt or photo. Resolve using the chat transcript and booking history, or ask both parties for more detail first.</p>
          </div>
        )}
        {tab === "chat" && (
          <div className="dispute-panel chat">
            {chat === null && <span className="dim">Loading chat…</span>}
            {chat && chat.length === 0 && <span className="dim">No messages in this booking.</span>}
            {chat && chat.map((message) => (
              <div className={`dispute-msg ${String(message.sender?.role || "").toLowerCase() === "provider" ? "right" : "left"}`} key={message.id}>
                <span className="who">{message.sender?.role || message.sender?.fullName || "User"}</span>
                {message.message}
              </div>
            ))}
          </div>
        )}
        {tab === "history" && <BookingTimeline booking={booking} />}

        <div className="field-label">Resolution</div>
        <div className="dispute-outcomes">
          {DISPUTE_OUTCOMES.map((o) => {
            const Ico = o.icon;
            return (
              <button type="button" key={o.id} className={`dispute-outcome ${picked === o.id ? "on" : ""}`} onClick={() => setPicked(o.id)}>
                <Ico size={16} />
                <span>
                  <span className="do-label">{o.label}</span>
                  <span className="do-hint">{o.hint}</span>
                </span>
              </button>
            );
          })}
        </div>

        {needsReason && (
          <label className="field-label" style={{ display: "grid", gap: 6 }}>
            Cancellation reason · logged and sent to both parties
            <textarea className="field-note" rows={3} value={reason} maxLength={500} onChange={(e) => setReason(e.target.value)}
              placeholder="e.g. Neither party can confirm the visit took place." />
          </label>
        )}

        <div className="modal-actions">
          <button className="btn btn-secondary" onClick={onClose}>Cancel</button>
          <button className="btn btn-primary" disabled={!picked || busy || (needsReason && !reason.trim())}
            onClick={() => onResolve(picked, needsReason ? reason.trim() : undefined)}>
            <Check size={15} /> {busy ? "Resolving…" : "Confirm resolution"}
          </button>
        </div>
      </div>
    </div>
  );
}

/* ─────────────────────────── Reviews ─────────────────────────── */
function downloadCsv(filename, header, records) {
  const escape = (value) => {
    const text = value == null ? "" : String(value);
    return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
  };
  const csv = [header.join(","), ...records.map((row) => row.map(escape).join(","))].join("\n");
  const url = URL.createObjectURL(new Blob([csv], { type: "text/csv" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

const REVIEW_FILTERS = ["Reported", "Low rating", "All"];

function Reviews() {
  const reports = useLoad(api.reviewReports, mock.reviewReports);
  const all = useLoad(api.reviews, mock.reviews);
  const [filter, setFilter] = useState("Reported");
  const [query, setQuery] = useState("");
  const [busyId, setBusyId] = useState(null);

  const isReported = filter === "Reported";
  const loading = isReported ? reports.loading : all.loading;
  const error = isReported ? reports.error : all.error;

  const [page, setPage] = useState(1);
  useEffect(() => { setPage(1); }, [filter, query]);

  const rows = useMemo(() => {
    const q = query.trim().toLowerCase();
    const match = (record) => !q || [record.from, record.to, record.text, record.reason].some((value) => String(value || "").toLowerCase().includes(q));
    if (isReported) return reports.data.filter(match);
    const base = filter === "Low rating" ? all.data.filter((review) => Number(review.rating) > 0 && Number(review.rating) <= 2) : all.data;
    return base.filter(match);
  }, [isReported, filter, query, reports.data, all.data]);

  const totalPages = Math.max(1, Math.ceil(rows.length / LIST_PAGE_SIZE));
  const safePage = Math.min(page, totalPages);
  const pageRows = rows.slice((safePage - 1) * LIST_PAGE_SIZE, safePage * LIST_PAGE_SIZE);

  async function resolveReport(report, action) {
    setBusyId(report.id);
    try {
      await runAction(() => api.resolveReviewReport(report.id, action), {
        success: action === "KEEP" ? "Report dismissed — review kept" : action === "HIDE" ? "Review hidden" : "Review removed"
      });
      reports.setData((current) => current.filter((entry) => entry.id !== report.id));
      if (action !== "KEEP") all.reload();
    } catch { /* toast shown */ } finally { setBusyId(null); }
  }

  function confirmResolve(report, action) {
    if (action === "KEEP") { resolveReport(report, action); return; }
    setConfirm({
      title: action === "HIDE" ? "Hide this review?" : "Remove this review?",
      body: "It disappears from the provider's public profile and their average rating is recalculated immediately.",
      confirmLabel: action === "HIDE" ? "Hide review" : "Remove review",
      tone: "danger",
      onConfirm: () => resolveReport(report, action)
    });
  }

  function hidePlainReview(review) {
    setConfirm({
      title: "Hide this review?",
      body: "It is removed from the provider's public profile and their average rating is recalculated immediately.",
      confirmLabel: "Hide review",
      tone: "danger",
      onConfirm: async () => {
        setBusyId(review.id);
        try {
          await runAction(() => api.setReviewVisibility(review.id, true), { success: "Review hidden" });
          all.setData((current) => current.filter((entry) => entry.id !== review.id));
        } catch { /* toast shown */ } finally { setBusyId(null); }
      }
    });
  }

  function exportCsv() {
    if (isReported) {
      downloadCsv("reported-reviews.csv", ["Author", "Provider", "Rating", "Reason", "Hidden", "Comment", "Reported"],
        rows.map((r) => [r.from, r.to, r.rating, r.reason, r.hidden ? "yes" : "no", r.text, r.when]));
    } else {
      downloadCsv("reviews.csv", ["Author", "Provider", "Rating", "Comment"],
        rows.map((r) => [r.from, r.to, r.rating, r.text]));
    }
  }

  const queueCount = reports.data.length;

  return (
    <section className="page-content">
      <PageHeader
        eyebrow="Content review"
        title="Reviews moderation"
        right={
          <>
            <Tag tone={queueCount ? "danger" : "plum"}>{queueCount} in queue</Tag>
            <button className="btn btn-secondary sm" onClick={exportCsv} disabled={rows.length === 0}>
              <Download size={14} /> Export CSV
            </button>
          </>
        }
      />
      <Toolbar
        query={query}
        onQuery={setQuery}
        placeholder="Search reviews, author, provider…"
        filters={REVIEW_FILTERS}
        activeFilter={filter}
        onFilter={setFilter}
      />
      <ReadOnlyNote need="SUPPORT" />

      {loading && <div className="review-list"><SkeletonRows cols={2} rows={3} /></div>}
      {error && !loading && (
        <StateBlock variant="error" body={`Could not load reviews: ${error}`} onAction={() => (isReported ? reports.reload() : all.reload())} />
      )}
      {!loading && !error && rows.length === 0 && (
        <StateBlock
          variant="empty"
          icon={isReported && !query ? ShieldCheck : Star}
          tone={isReported && !query ? "gold" : undefined}
          title={isReported && !query ? "Queue is clear" : query ? "No matches" : "No reviews"}
          body={isReported && !query ? "Every reported review has been handled. New reports appear here automatically." : "Nothing matches this search."}
        />
      )}

      <div className="review-list">
        {pageRows.map((review) => (
          <article className={`review-card ${isReported ? "reported" : ""}`} key={review.id}>
            <Avatar name={review.from} size={44} palette="plum" />
            <div className="review-body">
              <div className="review-meta">
                <span className="strong-cell">{review.from}</span>
                <ChevronRight size={12} />
                <span className="dim">{review.to}</span>
                <Stars value={review.rating} />
                {isReported && <Tag tone="danger">{review.reason}</Tag>}
                {isReported && review.hidden && <Tag tone="plum">Already hidden</Tag>}
                {!isReported && review.status && review.status !== "VISIBLE" && (
                  <Tag tone={review.status === "REPORTED" ? "danger" : "plum"}>{prettyStatus(review.status)}</Tag>
                )}
                {!isReported && Number(review.rating) > 0 && Number(review.rating) <= 2 && <Tag tone="warn">Low rating</Tag>}
              </div>
              <p className="review-text">{"“" + (review.text || "") + "”"}</p>
              {isReported && (
                <InlineBanner tone="warn" body="Removing or hiding this review recalculates the provider's average rating immediately." />
              )}
            </div>
            {can("SUPPORT") && (
              <div className="review-actions">
                {isReported ? (
                  <>
                    <button className="btn btn-danger sm" disabled={busyId === review.id} onClick={() => confirmResolve(review, "REMOVE")}>
                      <Trash2 size={14} /> Remove review
                    </button>
                    <button className="btn btn-secondary sm" disabled={busyId === review.id || review.hidden} onClick={() => confirmResolve(review, "HIDE")}>
                      <EyeOff size={14} /> Hide only
                    </button>
                    <button className="btn btn-ghost sm" disabled={busyId === review.id} onClick={() => confirmResolve(review, "KEEP")}>
                      <Check size={14} /> Keep · dismiss
                    </button>
                  </>
                ) : (
                  <button className="btn btn-danger sm" disabled={busyId === review.id} onClick={() => hidePlainReview(review)}>
                    <EyeOff size={14} /> Hide review
                  </button>
                )}
              </div>
            )}
          </article>
        ))}
      </div>
      {!loading && !error && <ListFooter page={safePage} pageSize={LIST_PAGE_SIZE} total={rows.length} totalPages={totalPages} onPage={setPage} />}
    </section>
  );
}

/* ─────────────────────────── Moderation ─────────────────────────── */
/* ─────────────────────────── Safety (SOS queue) ─────────────────────────── */
/* GET /admin/safety + POST /admin/safety/{id}/resolve. The other party is never
 * told about an SOS, so this queue (and the on-call SMS) is how support hears. */
export function Safety() {
  const [status, setStatus] = useState("OPEN");
  // Keyed so each filter mounts a fresh loader (useLoad only refetches on reload).
  return <SafetyQueue key={status} status={status} setStatus={setStatus} />;
}

// CR-19: how often the open SOS list reloads by itself.
const SAFETY_REFRESH_MS = 15_000;

function SafetyQueue({ status, setStatus }) {
  const { data, setData, error, loading, reload } = useLoad(() => api.safetyQueue(status), mock.safety);
  // While the Open filter is shown, reload quietly (no skeleton, typed notes
  // stay) every 15 s and whenever the sidebar badge count changes.
  useEffect(() => {
    if (status !== "OPEN") return undefined;
    let alive = true;
    const refresh = () => api.safetyQueue("OPEN")
      .then((rows) => { if (alive && rows) setData(rows); })
      .catch((err) => { if (alive && err?.status === 401) onAuthExpired(); });
    const timer = setInterval(refresh, SAFETY_REFRESH_MS);
    const onBadge = (route) => { if (route === "safety") refresh(); };
    badgeChangeListeners.add(onBadge);
    return () => { alive = false; clearInterval(timer); badgeChangeListeners.delete(onBadge); };
  }, [status, setData]);
  const [notes, setNotes] = useState({});
  const [busyId, setBusyId] = useState(null);

  async function resolve(ev) {
    const text = (notes[ev.id] || "").trim();
    if (!text) { toast("Write what was done before closing the alert.", "error"); return; }
    setBusyId(ev.id);
    try {
      await runAction(() => api.resolveSafety(ev.id, text), { success: "SOS closed" });
      setData((current) => status === "OPEN" ? current.filter((e) => e.id !== ev.id) : current);
    } catch { /* toast shown */ } finally { setBusyId(null); }
  }

  const chip = (value, label) => (
    <button key={value} className={`chip ${status === value ? "active" : ""}`} onClick={() => setStatus(value)}>{label}</button>
  );

  return (
    <section className="page-content">
      <PageHeader
        eyebrow="Trust & safety"
        title="Safety (SOS)"
        right={<Tag tone={status === "OPEN" && data.length ? "danger" : "plum"}>{status === "OPEN" ? `${data.length} open` : `${data.length} shown`}</Tag>}
      />
      {status === "OPEN" && !loading && !error && data.length > 0 && (() => {
        // DR-006: the oldest open alert is the one most at risk of being missed.
        const oldest = data.reduce((a, b) => (new Date(a.createdAt) <= new Date(b.createdAt) ? a : b));
        return (
          <InlineBanner tone="danger" title={`Oldest open alert: ${formatRelative(oldest.createdAt) || oldest.when}`}
            body={`Booking #${oldest.bookingId}, raised by ${oldest.actorName}. Alerts are listed newest first.`} />
        );
      })()}
      <ReadOnlyNote need="SUPPORT" />
      <div className="policy-tabs">{chip("OPEN", "Open")}{chip("RESOLVED", "Resolved")}{chip("ALL", "All")}</div>

      {loading && <div className="review-list"><SkeletonRows cols={2} rows={2} /></div>}
      {error && !loading && <StateBlock variant="error" body={`Could not load SOS alerts: ${error}`} onAction={reload} />}
      {!loading && !error && data.length === 0 && (
        <StateBlock variant="empty" icon={Siren}
          title={status === "OPEN" ? "No open SOS alerts" : "Nothing here"}
          body={status === "OPEN" ? "New alerts appear here and in the bell, and on-call staff get an SMS." : "No SOS alerts match this filter."} />
      )}

      <div className="review-list">
        {!loading && !error && data.map((ev) => (
          <article className={`review-card ${ev.resolved ? "" : "reported"}`} key={ev.id}>
            <Avatar name={ev.actorName} size={44} palette={ev.actorRole === "PROVIDER" ? "plum" : "rose"} />
            <div className="review-body">
              <div className="review-meta">
                <span className="strong-cell">{ev.actorName}</span>
                {ev.actorRole && <Tag tone="plum">{prettyStatus(ev.actorRole)}</Tag>}
                <span className="dim">Booking #{ev.bookingId}{ev.bookingStatus ? ` · ${prettyStatus(ev.bookingStatus)}` : ""}</span>
                <span className="dim">{formatRelative(ev.createdAt) || ev.when}</span>
                {ev.resolved ? <Tag tone="success">Closed</Tag> : <Tag tone="danger">Open</Tag>}
              </div>
              {ev.notes && <p className="review-text">{"“" + ev.notes + "”"}</p>}
              {ev.deliveries?.length > 0 && (
                <div className="kv-list" style={{ marginTop: 8 }}>
                  {ev.deliveries.map((d, i) => (
                    <div className="kv-row" key={i}>
                      <span className="k">SMS · {d.kind}</span>
                      <span className="v">
                        <span className="mono">{d.phone}</span>{" "}
                        <Tag tone={d.status === "SENT" ? "success" : d.status === "FAILED" ? "danger" : "plum"}>
                          {d.status === "SENT" ? "Delivered to gateway" : d.status === "FAILED" ? `Failed after ${d.attempts} tries` : "Sending…"}
                        </Tag>
                        {d.status === "FAILED" && d.lastError && <span className="dim"> {d.lastError}</span>}
                      </span>
                    </div>
                  ))}
                </div>
              )}
              <div className="kv-list" style={{ marginTop: 8 }}>
                <div className="kv-row"><span className="k">Customer</span><span className="v">{ev.customerName || "—"} {ev.customerPhone && <a href={`tel:${ev.customerPhone}`} className="mono">{ev.customerPhone}</a>}</span></div>
                <div className="kv-row"><span className="k">Provider</span><span className="v">{ev.providerName || "—"} {ev.providerPhone && <a href={`tel:${ev.providerPhone}`} className="mono">{ev.providerPhone}</a>}</span></div>
                {(ev.homeService || ev.address) && <div className="kv-row"><span className="k">{ev.homeService ? "Home visit" : "Address"}</span><span className="v">{ev.address || "—"}</span></div>}
                {ev.latitude != null && ev.longitude != null && (
                  <div className="kv-row"><span className="k">Location</span>
                    <a className="v" href={`https://www.google.com/maps?q=${ev.latitude},${ev.longitude}`} target="_blank" rel="noreferrer">
                      Open map <ExternalLink size={12} />
                    </a>
                  </div>
                )}
              </div>
              {ev.resolved ? (
                <InlineBanner tone="success" title={`Closed by ${ev.resolvedByName || "an admin"}`} body={ev.resolutionNotes || "No note."} />
              ) : can("SUPPORT") && (
                <textarea
                  className="field-note"
                  placeholder="What was done? (called the customer, contacted the provider, police informed…)"
                  value={notes[ev.id] || ""}
                  onChange={(e) => setNotes((n) => ({ ...n, [ev.id]: e.target.value }))}
                />
              )}
            </div>
            {!ev.resolved && can("SUPPORT") && (
              <div className="review-actions">
                <button className="btn btn-primary sm" disabled={busyId === ev.id} onClick={() => resolve(ev)}>
                  <Check size={14} /> Close alert
                </button>
              </div>
            )}
          </article>
        ))}
      </div>
    </section>
  );
}

function Moderation() {
  const { data: raw, setData, error, loading, reload } = useLoad(api.moderation, mock.moderation);
  const [busyId, setBusyId] = useState(null);
  const [page, setPage] = useState(1);
  const [query, setQuery] = useState("");
  useEffect(() => { setPage(1); }, [query]);
  // Reported reviews live on the Reviews screen and chat messages on Chat
  // reports; this queue covers reported images only.
  const data = useMemo(() => raw.filter((item) => item.type === "IMAGE"), [raw]);
  const filtered = data.filter((item) => matchesQuery(item, query, ["provider", "reason", "text", "when", "type"]));
  const totalPages = Math.max(1, Math.ceil(filtered.length / LIST_PAGE_SIZE));
  const safePage = Math.min(page, totalPages);
  const pageRows = filtered.slice((safePage - 1) * LIST_PAGE_SIZE, safePage * LIST_PAGE_SIZE);

  function act(item, status) {
    if (status === "ACTIONED") {
      const label = item.type === "IMAGE" ? "Hide this image?" : "Remove this review?";
      setConfirm({
        title: label,
        body: "The provider will be notified and the action is written to the audit log.",
        confirmLabel: item.type === "IMAGE" ? "Hide image" : "Remove review",
        tone: "danger",
        onConfirm: () => doAct(item, status)
      });
      return;
    }
    doAct(item, status);
  }

  async function doAct(item, status) {
    setBusyId(item.id);
    try {
      await runAction(() => api.moderationAction(item.id, { status, notes: "" }), {
        success: status === "ACTIONED" ? "Action recorded" : "Report dismissed"
      });
      setData((current) => current.filter((entry) => entry.id !== item.id));
    } catch {
      /* toast already shown */
    } finally {
      setBusyId(null);
    }
  }

  return (
    <section className="page-content">
      <PageHeader eyebrow="Content review" title="Photo moderation" />
      <ReadOnlyNote need="SUPPORT" />
      <SearchBar value={query} onChange={setQuery} placeholder="Search provider, reason, image text…" />
      <div className="stack-list">
        {loading && <SkeletonRows cols={1} rows={3} />}
        {error && !loading && <StateBlock variant="error" body={`Could not load the moderation queue: ${error}`} onAction={reload} />}
        {!loading && !error && filtered.length === 0 && (
          <StateBlock variant="empty" icon={ImageOff}
            title={query ? "No matches" : "Queue is clear"}
            body={query ? `Nothing matches "${query}".` : "Every reported image has been handled. Reported reviews live on the Reviews screen."} />
        )}
        {pageRows.map((item) => (
          <article className="moderation-card" key={item.id}>
            <div className={`moderation-thumb ${item.type.toLowerCase()}`}>
              {item.type === "REVIEW"
                ? <MessageSquareWarning size={28} />
                : item.imageUrl
                  ? <a href={item.imageUrl} target="_blank" rel="noreferrer" title="Open the reported photo">
                      <img src={item.imageUrl} alt="Reported photo" style={{ width: 88, height: 88, objectFit: "cover", borderRadius: "inherit", display: "block" }} />
                    </a>
                  : <ImageOff size={28} />}
            </div>
            <div>
              <h3>{item.provider}</h3>
              <p>{item.reason}</p>
              {item.text && <blockquote>{"\u201C" + item.text + "\u201D"}</blockquote>}
              <span className="when">{item.when}</span>
            </div>
            {can("SUPPORT") && (
              <div className="card-actions">
                <button className="btn btn-danger sm" disabled={busyId === item.id} onClick={() => act(item, "ACTIONED")}>
                  {item.type === "IMAGE" ? <><EyeOff size={14} /> Hide image</> : <><Trash2 size={14} /> Remove review</>}
                </button>
                <button className="btn btn-ghost sm" disabled={busyId === item.id} onClick={() => act(item, "DISMISSED")}>Dismiss report</button>
              </div>
            )}
          </article>
        ))}
      </div>
      {!loading && !error && <ListFooter page={safePage} pageSize={LIST_PAGE_SIZE} total={filtered.length} totalPages={totalPages} onPage={setPage} />}
    </section>
  );
}

/* ─────────────────────────── Chat reports ─────────────────────────── */
function ChatReports() {
  const { data, setData, error, loading, reload } = useLoad(api.chatReports, mock.chatReports);
  const [busyId, setBusyId] = useState(null);
  const [page, setPage] = useState(1);
  const [query, setQuery] = useState("");
  useEffect(() => { setPage(1); }, [query]);

  const filtered = data.filter((item) => matchesQuery(item, query, ["from", "bookingId", "reason", "text", "when"]));
  const totalPages = Math.max(1, Math.ceil(filtered.length / LIST_PAGE_SIZE));
  const safePage = Math.min(page, totalPages);
  const pageRows = filtered.slice((safePage - 1) * LIST_PAGE_SIZE, safePage * LIST_PAGE_SIZE);

  async function resolve(report, action) {
    setBusyId(report.id);
    try {
      await runAction(() => api.resolveChatReport(report.id, action), {
        success: action === "KEEP" ? "Report dismissed — message kept" : "Message removed"
      });
      setData((current) => current.filter((entry) => entry.id !== report.id));
    } catch { /* toast shown */ } finally { setBusyId(null); }
  }

  function confirmResolve(report, action) {
    if (action === "KEEP") { resolve(report, action); return; }
    setConfirm({
      title: "Remove this message?",
      body: "Both parties will see “[message removed by admin]” instead of the original text. The original stays in the audit trail.",
      confirmLabel: "Remove message",
      tone: "danger",
      onConfirm: () => resolve(report, action)
    });
  }

  return (
    <section className="page-content">
      <PageHeader
        eyebrow="Content review"
        title="Chat reports"
        right={<Tag tone={data.length ? "danger" : "plum"}>{data.length} in queue</Tag>}
      />
      <ReadOnlyNote need="SUPPORT" />
      <SearchBar value={query} onChange={setQuery} placeholder="Search reporter, booking, reason, message…" />

      {loading && <div className="review-list"><SkeletonRows cols={2} rows={3} /></div>}
      {error && !loading && <StateBlock variant="error" body={`Could not load chat reports: ${error}`} onAction={reload} />}
      {!loading && !error && filtered.length === 0 && (
        <StateBlock variant="empty" icon={MessageSquareWarning}
          title={query ? "No matches" : "Nothing reported"}
          body={query ? `Nothing matches "${query}".` : "There are no reported chat messages waiting for a decision."} />
      )}

      <div className="review-list">
        {pageRows.map((report) => (
          <article className="review-card reported" key={report.id}>
            <Avatar name={report.from} size={44} palette="plum" />
            <div className="review-body">
              <div className="review-meta">
                <span className="strong-cell">{report.from}</span>
                <ChevronRight size={12} />
                <span className="dim">Booking #{report.bookingId}</span>
                <Tag tone="danger">{report.reason}</Tag>
                {report.removed && <Tag tone="plum">Already removed</Tag>}
              </div>
              <p className="review-text">{"“" + report.text + "”"}</p>
              <InlineBanner tone="warn" body="Removing replaces this message with a fixed notice for both parties; it can't be undone from here." />
            </div>
            {can("SUPPORT") && (
              <div className="review-actions">
                <button className="btn btn-danger sm" disabled={busyId === report.id || report.removed} onClick={() => confirmResolve(report, "REMOVE")}>
                  <Trash2 size={14} /> Remove message
                </button>
                <button className="btn btn-ghost sm" disabled={busyId === report.id} onClick={() => confirmResolve(report, "KEEP")}>
                  <Check size={14} /> Keep · dismiss
                </button>
              </div>
            )}
          </article>
        ))}
      </div>
      {!loading && !error && <ListFooter page={safePage} pageSize={LIST_PAGE_SIZE} total={filtered.length} totalPages={totalPages} onPage={setPage} />}
    </section>
  );
}

/* ─────────────────────────── Settlements ─────────────────────────── */
const SETTLEMENT_STATUS = {
  WITHIN_LIMIT: { cls: "info", label: "Within limit" },
  OVERDUE: { cls: "overdue", label: "Overdue" },
  SETTLED: { cls: "settled", label: "Settled" }
};

function money(value) {
  const n = Number(value || 0);
  return n === 0 ? "—" : `EGP ${n.toFixed(2)}`;
}

/** Kit ConfirmSheet "Suspend {provider}?" (Settlements row + settlement detail). */
function confirmSuspendProvider(providerId, name, onDone) {
  setConfirm({
    tone: "danger",
    icon: Ban,
    eyebrow: "Provider account",
    title: `Suspend ${name}?`,
    body: "They're immediately hidden from search and can't accept new bookings. Existing accepted jobs can still be completed. This can be reversed from Users & providers.",
    confirmLabel: "Suspend account",
    onConfirm: async () => {
      try {
        await runAction(() => api.suspendProvider(providerId), { success: `${name} suspended` });
        onDone && onDone();
      } catch { /* toast shown */ }
    }
  });
}

function Settlements() {
  const [overview, setOverview] = useState(null);
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [exporting, setExporting] = useState(false);
  const [busyId, setBusyId] = useState(null);
  const [detailFor, setDetailFor] = useState(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [query, setQuery] = useState("");

  useEffect(() => {
    let alive = true;
    setLoading(true);
    setError("");
    Promise.all([api.settlementOverview(), api.settlementProviders()])
      .then(([ov, list]) => { if (alive) { setOverview(ov); setRows(list); } })
      .catch((err) => {
        if (!alive) return;
        // 401 = the session is gone; 403 = signed in but without FINANCE.
        if (err?.status === 401) { onAuthExpired(); return; }
        setError(err?.status === 403
          ? "You don't have permission to view settlements."
          : err.message || "Could not load settlements.");
      })
      .finally(() => { if (alive) setLoading(false); });
    return () => { alive = false; };
  }, [reloadKey]);

  async function exportLedger() {
    setExporting(true);
    try {
      await runAction(() => api.exportLedger(), { success: "Ledger exported", failure: "Could not export ledger" });
    } catch { /* toast */ } finally { setExporting(false); }
  }

  async function remind(row) {
    setBusyId(row.providerId);
    try {
      await runAction(() => api.remindSettlement(row.providerId), { success: `Reminder sent to ${row.providerName}` });
    } catch { /* toast */ } finally { setBusyId(null); }
  }

  if (detailFor) {
    return (
      <SettlementDetail
        providerId={detailFor}
        onBack={() => { setDetailFor(null); setReloadKey((k) => k + 1); }}
        onChanged={() => setReloadKey((k) => k + 1)}
      />
    );
  }

  const filteredSettlements = rows.filter((r) =>
    matchesQuery(r, query, ["providerName", "status", "commissionPercent"])
  );

  return (
    <section className="page-content">
      <PageHeader
        eyebrow="Commission oversight"
        title="Settlements"
        right={<button className="btn btn-primary sm" onClick={exportLedger} disabled={exporting}>
          <Download size={15} /> {exporting ? "Exporting…" : "Export ledger"}
        </button>}
      />
      <ReadOnlyNote need="FINANCE" />

      <div className="settle-cards">
        <CommissionRateCard onSaved={() => setReloadKey((k) => k + 1)} />
        <article className="panel settle-owed">
          <p className="eyebrow">Commission owed</p>
          <strong>{money(overview?.totalOwed)}</strong>
          <span className="dim">across {overview?.providerCount ?? 0} provider{overview?.providerCount === 1 ? "" : "s"}</span>
        </article>
      </div>

      <SearchBar value={query} onChange={setQuery} placeholder="Search provider, status, commission…" />
      <article className="table-card">
        <div className="table-scroll">
          <div className="table header settlements-rich">
            <span>Provider</span><span>Commission</span><span>Balance owed</span><span>Status</span><span>Due</span><span />
          </div>
          {loading && <SkeletonRows cols={6} />}
          {error && !loading && <StateBlock variant="error" body={error} onAction={() => setReloadKey((k) => k + 1)} />}
          {!loading && !error && filteredSettlements.length === 0 && (
            <StateBlock variant="empty" icon={Banknote}
              title={query ? "No matches" : "Nothing owing"}
              body={query ? `Nothing matches "${query}".` : "No provider has an outstanding commission balance."} />
          )}
          {!loading && !error && filteredSettlements.map((row) => {
            const info = SETTLEMENT_STATUS[row.status] || SETTLEMENT_STATUS.WITHIN_LIMIT;
            const owed = Number(row.balanceOwed) || 0;
            return (
              <div className="table row settlements-rich clickable" key={row.providerId} onClick={() => setDetailFor(row.providerId)}>
                <span className="strong-cell">{row.providerName}</span>
                <span>
                  <span className="mono">{row.commissionPercent}%</span>
                  {row.commissionOverridePercent != null && <span className="chip-mini gold" style={{ marginLeft: 6 }}>Custom</span>}
                  <span className="dim block">EGP {Number(row.grossAmount || 0).toLocaleString()} gross</span>
                </span>
                <span className="mono" style={{ color: owed > 0 ? "var(--danger-700)" : "var(--success-700)" }}>{money(owed)}</span>
                <span>
                  <span className={`status ${info.cls}`}>{info.label}</span>
                  {row.paymentReportedAt && <span className="chip-mini gold" style={{ marginLeft: 6 }} title={`Reported ${formatWhen(row.paymentReportedAt)}`}>Payment reported</span>}
                </span>
                <span className="dim">{row.dueDate ? formatWhen(row.dueDate) : "—"}</span>
                <span className="cell-end" onClick={(e) => e.stopPropagation()} style={{ gap: 6 }}>
                  {row.accountSuspended
                    ? <Tag tone="danger">Suspended</Tag>
                    : can("SUPPORT") && (
                      <button className="circle-button sm" aria-label={`Suspend ${row.providerName}`} title="Suspend provider"
                        onClick={() => confirmSuspendProvider(row.providerId, row.providerName, () => setReloadKey((k) => k + 1))}>
                        <Ban size={14} />
                      </button>
                    )}
                  {row.status === "OVERDUE" && can("FINANCE")
                    ? <button className="btn btn-danger sm" disabled={busyId === row.providerId} onClick={() => remind(row)}>
                        {busyId === row.providerId ? "Sending…" : "Send reminder"}
                      </button>
                    : <button className="btn btn-ghost sm" onClick={() => setDetailFor(row.providerId)}>View</button>}
                </span>
              </div>
            );
          })}
        </div>
      </article>

      <InlineBanner tone="warn" title="Applies to new bookings only"
        body="Changing the rate doesn't recalculate past ledger entries — each keeps the rate that was live when it was created." />
    </section>
  );
}

const fmtNum = (v) => (v == null || v === "" ? "—" : String(Number(v)));

/**
 * Per-provider commission + booking-rule overrides. Each row shows the effective
 * value and whether it's a custom override or the platform default; editing is
 * gated per row (commission → FINANCE, booking rules → SUPER_ADMIN).
 */
function ProviderOverridesCard({ providerId, onSaved }) {
  const [s, setS] = useState(null);
  const [err, setErr] = useState("");
  const [editing, setEditing] = useState(null);
  const [draft, setDraft] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let alive = true;
    setErr(""); setS(null);
    api.providerSettings(providerId)
      .then((d) => { if (alive) setS(d); })
      .catch((e) => { if (alive) setErr(e.message || "Could not load provider settings."); });
    return () => { alive = false; };
  }, [providerId]);

  if (err) return <article className="detail-block"><p className="eyebrow">Rates &amp; rules</p><p className="muted">{err}</p></article>;
  if (!s) return <article className="detail-block"><p className="eyebrow">Rates &amp; rules</p><SkeletonRows cols={1} rows={3} /></article>;

  const rows = [
    { key: "commission", label: "Commission", unit: "%", perm: "FINANCE", min: 0, max: 100, step: 0.5,
      effective: s.effectiveCommissionPercent, platform: s.platformCommissionPercent, override: s.commissionOverridePercent },
    { key: "cancellationCutoffHours", label: "Cancellation cutoff", unit: " hrs", perm: "SUPER_ADMIN", min: 0, max: 168, step: 1,
      effective: s.effectiveCancellationCutoffHours, platform: s.platformCancellationCutoffHours, override: s.cancellationCutoffHoursOverride },
    { key: "providerCancelPenaltyPercent", label: "Provider cancel penalty", unit: "%", perm: "SUPER_ADMIN", min: 0, max: 100, step: 1,
      effective: s.effectiveProviderCancelPenaltyPercent, platform: s.platformProviderCancelPenaltyPercent, override: s.providerCancelPenaltyPercentOverride },
    { key: "responseWindowMinutes", label: "Response window", unit: " min", perm: "SUPER_ADMIN", min: 5, max: 1440, step: 5,
      effective: s.effectiveResponseWindowMinutes, platform: s.platformResponseWindowMinutes, override: s.responseWindowMinutesOverride }
  ];
  const anyEditable = rows.some((r) => can(r.perm));

  async function persist(row, fn, msg) {
    setBusy(true);
    try {
      const next = await fn();
      setS(next); setEditing(null); toast(msg, "ok"); onSaved && onSaved();
    } catch (e) { toast(e.message || "Could not save", "error"); }
    finally { setBusy(false); }
  }
  function save(row) {
    const num = Number(draft);
    if (draft === "" || Number.isNaN(num) || num < row.min || num > row.max) {
      toast(`Enter a value between ${row.min} and ${row.max}.`, "error"); return;
    }
    persist(row,
      () => (row.key === "commission"
        ? api.setProviderCommission(providerId, num)
        : api.setProviderBookingRules(providerId, { set: { [row.key]: num } })),
      `${row.label} set to a custom value`);
  }
  function reset(row) {
    persist(row,
      () => (row.key === "commission"
        ? api.setProviderCommission(providerId, null)
        : api.setProviderBookingRules(providerId, { clear: [row.key] })),
      `${row.label} back to the platform default`);
  }

  return (
    <article className="detail-block">
      <p className="eyebrow">Rates &amp; rules</p>
      <p className="muted" style={{ margin: "0 0 6px" }}>
        Per-provider overrides. Rows marked <em>Platform</em> follow the platform default. Applies to future bookings only.
      </p>
      {rows.map((row, i) => (
        <div className="override-row" key={row.key}>
          {i > 0 && <div className="hr" />}
          <div className="override-head">
            <span className="k">{row.label}</span>
            <span className={`chip-mini ${row.override != null ? "gold" : ""}`}>{row.override != null ? "Custom" : "Platform"}</span>
          </div>
          {editing === row.key ? (
            <div className="override-edit">
              <div className="pct-field">
                <input type="number" min={row.min} max={row.max} step={row.step} value={draft}
                  onChange={(e) => setDraft(e.target.value)} aria-label={row.label} autoFocus />
                <span>{row.unit.trim() || "%"}</span>
              </div>
              <button className="btn btn-primary sm" disabled={busy} onClick={() => save(row)}>{busy ? "Saving…" : "Save"}</button>
              {row.override != null && <button className="btn btn-ghost sm" disabled={busy} onClick={() => reset(row)}>Use platform</button>}
              <button className="btn btn-ghost sm" disabled={busy} onClick={() => setEditing(null)}>Cancel</button>
            </div>
          ) : (
            <div className="override-view">
              <strong>{fmtNum(row.effective)}{row.unit}</strong>
              {row.override != null && <span className="dim">platform {fmtNum(row.platform)}{row.unit}</span>}
              {can(row.perm) && (
                <button className="btn btn-ghost sm override-edit-btn" onClick={() => { setEditing(row.key); setDraft(String(row.override ?? row.effective ?? "")); }}>
                  <Settings size={12} /> Edit
                </button>
              )}
            </div>
          )}
        </div>
      ))}

      {/* Home-service travel fee — semantics differ: null = "no travel fee",
          not "use platform default", so it doesn't fit the override pattern above. */}
      <div className="override-row">
        <div className="hr" />
        <div className="override-head">
          <span className="k">Home-service travel fee</span>
          <span className={`chip-mini ${s.homeServiceTravelFee != null ? "gold" : ""}`}>
            {s.homeServiceTravelFee != null ? "Custom" : "None"}
          </span>
        </div>
        {editing === "travelFee" ? (
          <div className="override-edit">
            <div className="pct-field">
              <input type="number" min={0} max={10000} step={5} value={draft}
                onChange={(e) => setDraft(e.target.value)} aria-label="Travel fee" autoFocus />
              <span>EGP</span>
            </div>
            <button className="btn btn-primary sm" disabled={busy} onClick={() => {
              const num = Number(draft);
              if (draft === "" || Number.isNaN(num) || num < 0) { toast("Enter 0 or a positive amount.", "error"); return; }
              persist(null, () => api.setProviderTravelFee(providerId, num),
                num === 0 ? "Travel fee removed" : `Travel fee set to EGP ${num}`);
            }}>{busy ? "Saving…" : "Save"}</button>
            {s.homeServiceTravelFee != null && (
              <button className="btn btn-ghost sm" disabled={busy}
                onClick={() => persist(null, () => api.setProviderTravelFee(providerId, null), "Travel fee removed")}>
                Remove
              </button>
            )}
            <button className="btn btn-ghost sm" disabled={busy} onClick={() => setEditing(null)}>Cancel</button>
          </div>
        ) : (
          <div className="override-view">
            {s.homeServiceTravelFee != null
              ? <strong>EGP {fmtNum(s.homeServiceTravelFee)}</strong>
              : <span className="dim">Provider does not charge for travel</span>}
            {can("FINANCE") && (
              <button className="btn btn-ghost sm override-edit-btn"
                onClick={() => { setEditing("travelFee"); setDraft(String(s.homeServiceTravelFee ?? "")); }}>
                <Settings size={12} /> Edit
              </button>
            )}
          </div>
        )}
        <p className="muted small" style={{ margin: "6px 0 0" }}>
          Added to home-service bookings only. Commission is charged on the service portion; travel is pass-through to the provider.
        </p>
      </div>

      {!anyEditable && <ReadOnlyNote need="FINANCE" />}
    </article>
  );
}

function CommissionRateCard({ onSaved }) {
  const [percent, setPercent] = useState(null);
  const [value, setValue] = useState("");
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let alive = true;
    api.getCommission().then((r) => { if (alive && r?.commissionPercent != null) { setPercent(r.commissionPercent); setValue(String(r.commissionPercent)); } }).catch(() => {});
    return () => { alive = false; };
  }, []);

  async function save() {
    const num = Number(value);
    // Kit rule 0 < n ≤ 50; anything else reverts to the saved rate.
    if (value === "" || Number.isNaN(num) || num <= 0 || num > 50) {
      toast("Enter a rate above 0 and up to 50%.", "error");
      setValue(String(percent ?? ""));
      return;
    }
    // CR-22: the platform-wide rate changes what every provider owes, so it asks first.
    setConfirm({
      title: `Change the commission rate to ${num}%?`,
      body: `The platform rate is ${percent != null ? `${percent}%` : "not set"} now. Providers without their own rate are charged the new one on completed cash bookings.`,
      confirmLabel: "Change rate",
      tone: "plum",
      onConfirm: apply
    });

    async function apply() {
      setSaving(true);
      try {
        const r = await api.setCommission(num);
        const next = r?.commissionPercent ?? num;
        setPercent(next); setValue(String(next)); setEditing(false);
        toast("Commission rate updated", "ok");
        onSaved && onSaved();
      } catch (err) { toast(err.message || "Could not save", "error"); }
      finally { setSaving(false); }
    }
  }

  return (
    <article className="panel settle-rate">
      <div className="settle-rate-head">
        <p className="eyebrow">Commission rate</p>
        {!editing && can("FINANCE") && <button className="circle-button sm" aria-label="Edit commission rate" onClick={() => setEditing(true)}><Pencil size={14} /></button>}
      </div>
      {editing ? (
        <div className="settle-rate-edit">
          <div className="pct-field">
            <input type="number" min="0.5" max="50" step="0.5" value={value} autoFocus onChange={(e) => setValue(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter") save(); if (e.key === "Escape") { setEditing(false); setValue(String(percent ?? "")); } }}
              aria-label="Commission percent" />
            <span>%</span>
          </div>
          <button className="btn btn-primary sm" disabled={saving} onClick={save}>{saving ? "Saving…" : "Save"}</button>
          <button className="btn btn-ghost sm" onClick={() => { setEditing(false); setValue(String(percent ?? "")); }}>Cancel</button>
        </div>
      ) : (
        <>
          <strong>{percent != null ? `${percent}%` : "—"}</strong>
          <span className="dim">of completed cash bookings</span>
        </>
      )}
    </article>
  );
}

export function SettlementDetail({ providerId, onBack, onChanged }) {
  const [detail, setDetail] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [reloadKey, setReloadKey] = useState(0);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    api.settlementDetail(providerId)
      .then((d) => { if (alive) setDetail(d); })
      .catch((err) => { if (alive) setError(err.message || "Could not load settlement detail."); })
      .finally(() => { if (alive) setLoading(false); });
    return () => { alive = false; };
  }, [providerId, reloadKey]);

  const refresh = () => { setReloadKey((k) => k + 1); onChanged && onChanged(); };
  const [paidOut, setPaidOut] = useState(false);

  // CR-06: the dialog states the total the provider reported (or, with no
  // report, what is outstanding now) and the confirmation sends it back, so
  // the server settles exactly that and nothing recorded since.
  async function confirmPayout() {
    let report;
    setBusy(true);
    try {
      report = await api.payoutReport(providerId);
    } catch (err) {
      toast(err?.message || "Could not load the payout report.", "error");
      return;
    } finally { setBusy(false); }
    const count = `${report.entryCount} ${report.entryCount === 1 ? "entry" : "entries"}`;
    const amount = `EGP ${Number(report.total || 0).toFixed(2)}`;
    setConfirm({
      title: `Confirm payout from ${detail?.providerName}?`,
      body: report.reportedAt
        ? `The provider reported paying ${amount} (${count}). Only those entries are marked settled; commission recorded since stays owed.`
        : `Confirm you received ${amount} (${count}). Those entries are marked settled.`,
      confirmLabel: "Confirm payout",
      tone: "plum",
      onConfirm: async () => {
        setBusy(true);
        try {
          await runAction(() => api.confirmPayout(providerId, report.total), { success: "Payout confirmed" });
          setPaidOut(true);
          refresh();
        } catch { /* toast */ } finally { setBusy(false); }
      }
    });
  }

  function toggleBookingPause() {
    const paused = detail?.settlementPaused;
    setConfirm({
      tone: paused ? "plum" : "danger",
      eyebrow: "New bookings",
      title: paused ? `Resume bookings for ${detail?.providerName}?` : `Pause new bookings for ${detail?.providerName}?`,
      body: paused
        ? "They can receive new bookings again straight away."
        : "They stay listed but can't take new bookings until the balance is settled. Existing jobs continue.",
      confirmLabel: paused ? "Resume bookings" : "Pause bookings",
      onConfirm: async () => {
        setBusy(true);
        try {
          await runAction(() => api.setSettlementPause(providerId, !paused),
            { success: paused ? "New bookings resumed" : "New bookings paused" });
          refresh();
        } catch { /* toast */ } finally { setBusy(false); }
      }
    });
  }

  async function remind() {
    setBusy(true);
    try {
      await runAction(() => api.remindSettlement(providerId), { success: "Reminder sent" });
    } catch { /* toast */ } finally { setBusy(false); }
  }

  const settled = paidOut || (detail && Number(detail.totalOwed) <= 0 && detail.status === "SETTLED");
  const info = SETTLEMENT_STATUS[settled ? "SETTLED" : detail?.status] || SETTLEMENT_STATUS.WITHIN_LIMIT;

  return (
    <section className="page-content">
      <button className="detail-back" onClick={onBack}><ArrowLeft size={14} /> Back to settlements</button>

      {loading && <SkeletonRows cols={2} rows={4} />}
      {error && !loading && <StateBlock variant="error" body={error} onAction={() => setReloadKey((k) => k + 1)} />}
      {!loading && !error && detail && (
        <>
          <div className="detail-hero">
            <div>
              <p className="eyebrow">Settlement detail</p>
              <h1>{detail.providerName}</h1>
              <div className="sub">Due {detail.dueDate ? formatWhen(detail.dueDate) : "—"}</div>
            </div>
            <div style={{ display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap" }}>
              <span className={`status ${info.cls}`}>{info.label}</span>
              {detail.settlementPaused && <Tag tone="warn">Bookings paused</Tag>}
              {detail.paymentReportedAt && <Tag tone="gold">Payment reported {formatWhen(detail.paymentReportedAt)}</Tag>}
            </div>
          </div>
          {detail.paymentReportedAt && can("FINANCE") && (
            <InlineBanner
              tone="info"
              title="The provider says they paid"
              body="Check that the money arrived, then confirm the payout. Until then their balance stays owed."
            />
          )}

          <div className="detail-cols">
            <article className="table-card">
              <div className="table header" style={{ gridTemplateColumns: "1fr auto", padding: "13px 22px" }}>
                <span>Ledger entries</span><span />
              </div>
              {detail.entries.length === 0 && <div className="empty-row">No ledger entries.</div>}
              {detail.entries.map((entry) => (
                <div className="ledger-row" key={entry.id}>
                  <div>
                    <strong>{entry.serviceName}{entry.customerName ? ` · ${entry.customerName}` : ""}</strong>
                    <span className="dim">
                      {entry.createdAt ? formatWhen(entry.createdAt) : ""} · EGP {Number(entry.bookingAmount || 0).toFixed(2)} gross · {entry.commissionPercent}% commission
                      {entry.status === "SETTLED" ? " · settled" : entry.status === "OVERDUE" ? " · overdue" : ""}
                    </span>
                  </div>
                  <span className="mono ledger-amount">−EGP {Number(entry.commissionAmount || 0).toFixed(2)}</span>
                </div>
              ))}
            </article>

            <div className="detail-side-stack">
            <ProviderOverridesCard providerId={detail.providerId} onSaved={onChanged} />

            <article className="detail-block">
              <p className="eyebrow">Total owed</p>
              <strong className="detail-figure" style={{ marginBottom: 14 }}>{money(detail.totalOwed)}</strong>
              {can("FINANCE") ? (
                <>
                  {settled ? (
                    <p className="settle-confirmed"><CheckCircle2 size={16} /> Settlement confirmed</p>
                  ) : (
                    <button className="btn btn-primary full" disabled={busy || Number(detail.totalOwed) <= 0} onClick={confirmPayout}>
                      <Banknote size={15} /> Confirm payout received
                    </button>
                  )}
                  <button className="btn btn-ghost full" disabled={busy} onClick={remind} style={{ marginTop: 8 }}>Send reminder</button>
                  <div className="hr" />
                  <p className="eyebrow">New bookings</p>
                  <p className="muted" style={{ margin: "0 0 10px" }}>
                    {detail.settlementPaused
                      ? "This provider is not receiving new bookings until their balance is settled."
                      : "Pause new bookings until the balance is settled. The account itself stays active — deactivate it from the provider's profile."}
                  </p>
                  <button className={`btn full ${detail.settlementPaused ? "btn-primary" : "btn-secondary"}`} disabled={busy} onClick={toggleBookingPause}>
                    {detail.settlementPaused ? "Resume new bookings" : "Pause new bookings"}
                  </button>
                </>
              ) : (
                <ReadOnlyNote need="FINANCE" />
              )}
              {can("SUPPORT") && (
                <>
                  <div className="hr" />
                  <p className="eyebrow">Provider account</p>
                  {detail.accountSuspended ? (
                    <InlineBanner tone="danger" title="Account suspended" body="Hidden from search, can't accept new bookings." />
                  ) : (
                    <button className="btn btn-danger full" disabled={busy}
                      onClick={() => confirmSuspendProvider(detail.providerId, detail.providerName, refresh)}>
                      <Ban size={15} /> Suspend account
                    </button>
                  )}
                </>
              )}
            </article>
            </div>
          </div>
        </>
      )}
    </section>
  );
}
/* ─────────────────────────── Audit log ─────────────────────────── */
function AuditLog() {
  const [query, setQuery] = useState("");
  const [items, setItems] = useState([]);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [exporting, setExporting] = useState(false);

  async function exportCsv() {
    setExporting(true);
    try {
      await runAction(() => api.exportAudit(query), { success: "Audit log exported", failure: "Could not export the audit log" });
    } catch { /* toast shown */ } finally { setExporting(false); }
  }

  useEffect(() => {
    let alive = true;
    setLoading(true);
    setError("");
    const handle = setTimeout(() => {
      api.audit(query, page - 1, 20)
        .then((result) => { if (alive) { setItems(result.items); setTotalPages(result.totalPages || 1); } })
        .catch((err) => {
          if (!alive) return;
          // 401 = the session is gone; 403 = this admin lacks the permission.
          if (err?.status === 401) { setError("Session expired. Please sign in again."); onAuthExpired(); }
          else if (err?.status === 403) setError("You don't have permission to view the audit log.");
          else setError(err.message || "Could not load the audit log.");
          setItems([]);
        })
        .finally(() => { if (alive) setLoading(false); });
    }, 200);
    return () => { alive = false; clearTimeout(handle); };
  }, [query, page]);

  return (
    <section className="page-content">
      <PageHeader
        eyebrow="Accountability"
        title="Audit log"
        right={
          <button className="btn btn-primary sm" onClick={exportCsv} disabled={exporting}>
            <Download size={15} /> {exporting ? "Exporting…" : query ? "Export matches (CSV)" : "Export CSV"}
          </button>
        }
      />
      <Toolbar query={query} onQuery={(value) => { setQuery(value); setPage(1); }} placeholder="Search actor, action, target…" />
      <article className="table-card">
        <div className="table-scroll">
          <div className="table header audit">
            <span>Admin</span><span>Action</span><span>Target</span><span>When</span><span>IP</span>
          </div>
          {loading && <SkeletonRows cols={5} />}
          {error && !loading && <StateBlock variant="error" body={error} />}
          {!loading && !error && items.length === 0 && (
            query
              ? <StateBlock variant="empty" icon={FileSearch} title="No entries match" body="Try a different search term." />
              : <StateBlock variant="empty" icon={FileSearch} title="No audit entries yet"
                  body="Privileged admin actions — approvals, suspensions, settlements, moderation, review hides — are recorded here as they happen." />
          )}
          {!loading && !error && items.map((entry) => (
            <div className="table row audit" key={entry.id}>
              <span className="strong-cell">{entry.actor}</span>
              <span><Tag tone={entry.tone}>{entry.action}</Tag></span>
              <span className="mono dim">{entry.target}</span>
              <span className="dim">{entry.when}</span>
              <span className="mono dim">{entry.ip}</span>
            </div>
          ))}
        </div>
      </article>
      <Pagination page={page} totalPages={totalPages} onPage={setPage} />
    </section>
  );
}

/* ─────────────────────────── Policies ─────────────────────────── */
const settingsHeadingStyle = { marginTop: 4, fontFamily: "var(--font-display)", fontWeight: 400, fontSize: 24, color: "var(--plum-900)", lineHeight: 1.15 };

function Policies() {
  const [tab, setTab] = useState("terms");
  const tabs = [
    { id: "terms", label: "Terms & policies" },
    { id: "rules", label: "Booking rules" },
    { id: "support", label: "Support" }
  ];
  return (
    <section className="page-content">
      <PageHeader
        eyebrow="Platform"
        title="Policies & support"
        right={tab === "terms" && can("SUPER_ADMIN") ? <TermsPublishButton /> : null}
      />
      <div className="policy-tabs">
        {tabs.map((t) => (
          <button key={t.id} className={`chip ${tab === t.id ? "active" : ""}`} onClick={() => setTab(t.id)}>{t.label}</button>
        ))}
      </div>
      <ReadOnlyNote need="SUPER_ADMIN" />
      {tab === "terms" && <TermsEditorPanel />}
      {tab === "rules" && <BookingRulesPanel />}
      {tab === "support" && <SupportSettingsPanel />}
    </section>
  );
}

/* module-level bridge so the header button can trigger the editor's publish */
let __termsPublish = null;
function TermsPublishButton() {
  return (
    <button className="btn btn-primary sm" onClick={() => __termsPublish && __termsPublish()}>
      <Download size={15} style={{ transform: "rotate(180deg)" }} /> Publish new version
    </button>
  );
}

/* Terms & policies — per-type EN/AR draft + version history (GET/POST /terms).
 * Drafts persist per type in this browser until published. */
const TERMS_TYPES = [
  { id: "CUSTOMER_TERMS", label: "Customer terms" },
  { id: "PROVIDER_TERMS", label: "Provider terms" }
];
const draftKey = (type) => `aiwa_admin_terms_draft_${type}`;
function readDraft(type) {
  try { return JSON.parse(window.localStorage.getItem(draftKey(type)) || "null"); } catch { return null; }
}
function writeDraft(type, value) {
  try {
    if (value) window.localStorage.setItem(draftKey(type), JSON.stringify(value));
    else window.localStorage.removeItem(draftKey(type));
    return true;
  } catch { return false; }
}

export function TermsEditorPanel() {
  const [type, setType] = useState("CUSTOMER_TERMS");
  const [versions, setVersions] = useState([]);
  const [draft, setDraft] = useState("");
  const [draftAr, setDraftAr] = useState("");
  const [nextVersion, setNextVersion] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [savedDraft, setSavedDraft] = useState(false);
  const [preview, setPreview] = useState(false);

  function load(forType = type) {
    setLoading(true);
    setError("");
    api.termsVersions(forType)
      .then((list) => {
        setVersions(list);
        const live = list.find((v) => v.active) || list[0];
        const saved = readDraft(forType);
        setDraft(saved?.en ?? live?.contentEn ?? "");
        setDraftAr(saved?.ar ?? live?.contentAr ?? "");
        setSavedDraft(!!saved);
        setNextVersion(bumpVersion(live?.version));
      })
      .catch((err) => setError(err.message || "Could not load terms."))
      .finally(() => setLoading(false));
  }
  useEffect(() => { load(type); }, [type]);

  function saveDraft() {
    if (writeDraft(type, { en: draft, ar: draftAr })) { setSavedDraft(true); toast("Draft saved in this browser", "ok"); }
    else toast("This browser blocks local storage; the draft could not be saved.", "error");
  }

  function bumpVersion(v) {
    const parts = String(v || "1.0.0").split(".").map((n) => parseInt(n, 10) || 0);
    parts[1] = (parts[1] || 0) + 1;
    parts[2] = 0;
    return parts.join(".");
  }

  const who = type === "PROVIDER_TERMS" ? "provider" : "customer";

  function publish() {
    if (!draft.trim()) { toast("The English text is empty.", "error"); return; }
    setConfirm({
      title: `Publish ${who} terms v${nextVersion}?`,
      body: `It becomes the live ${who} version and every ${who} is asked to re-accept the next time they open the app.`
        + (draftAr.trim() ? "" : " There is no Arabic text, so Arabic users will see the English version."),
      input: { label: "What changed · shown in the version history", placeholder: "e.g. Provider cancel penalties, home-service safety" },
      confirmLabel: "Publish & notify",
      tone: "plum",
      onConfirm: async (changeNote) => {
        try {
          await runAction(() => api.publishTerms(nextVersion, draft, type, draftAr, changeNote), { success: `${who} terms v${nextVersion} published` });
          writeDraft(type, null);
          load(type);
        } catch { /* toast */ }
      }
    });
  }
  useEffect(() => { __termsPublish = publish; return () => { __termsPublish = null; }; });

  const typeChips = (
    <div className="policy-tabs" style={{ marginBottom: 12 }}>
      {TERMS_TYPES.map((t) => (
        <button key={t.id} className={`chip ${type === t.id ? "active" : ""}`} onClick={() => { setPreview(false); setType(t.id); }}>{t.label}</button>
      ))}
    </div>
  );

  if (loading) return <>{typeChips}<SkeletonRows cols={2} rows={4} /></>;
  if (error) return <>{typeChips}<StateBlock variant="error" body={error} onAction={() => load(type)} /></>;

  const edit = (setter) => (e) => { setter(e.target.value); setSavedDraft(false); };

  return (
    <>
    {typeChips}
    <div className="policy-cols">
      <article className="panel">
        <p className="eyebrow">Draft · {who} terms · v{nextVersion}</p>
        {preview ? (
          <>
            <p className="version-note" style={{ whiteSpace: "pre-wrap" }}>{draft || "—"}</p>
            <p className="version-note" dir="rtl" lang="ar" style={{ whiteSpace: "pre-wrap" }}>{draftAr || "لا يوجد نص عربي بعد."}</p>
          </>
        ) : (
          <>
            <textarea className="terms-draft" value={draft} onChange={edit(setDraft)}
              placeholder={`Write the ${who} terms & policies (English)…`} aria-label="English text" />
            <textarea className="terms-draft" value={draftAr} onChange={edit(setDraftAr)} dir="rtl" lang="ar"
              placeholder="النص العربي للشروط والسياسات…" aria-label="Arabic text" style={{ height: 220 }} />
          </>
        )}
        <div style={{ display: "flex", gap: 9, marginTop: 12, flexWrap: "wrap" }}>
          <button className="btn btn-secondary sm" onClick={saveDraft}>
            <Check size={15} /> {savedDraft ? "Draft saved" : "Save draft"}
          </button>
          <button className="btn btn-ghost sm" onClick={() => setPreview((p) => !p)}>
            <Eye size={15} /> {preview ? "Back to editing" : "Preview"}
          </button>
        </div>
      </article>

      <article className="table-card">
        <div className="table header" style={{ gridTemplateColumns: "1fr", padding: "13px 18px" }}>
          <span>Version history</span>
        </div>
        {versions.length === 0 && <div className="empty-row">No versions yet.</div>}
        {versions.map((v) => (
          <div className="version-row" key={v.id}>
            <div className="version-head">
              <span className="mono">v{v.version}</span>
              {v.active && <Tag tone="success">Live</Tag>}
            </div>
            <p className="version-note">{v.changeNote || "No change note"}</p>
            <span className="dim">
              {[v.createdAt ? formatWhen(v.createdAt) : "", v.publishedBy, v.contentAr ? "" : "English only"].filter(Boolean).join(" · ")}
            </span>
          </div>
        ))}
      </article>
    </div>
    </>
  );
}

/* Support — labeled list of WhatsApp lines + hours + escalation email (GET/PATCH /support/admin/settings) */
const emptyLine = () => ({ label: "", number: "", displayNumber: "", primary: false, enabled: true });

function SupportSettingsPanel() {
  const [numbers, setNumbers] = useState([]);
  const [hours, setHours] = useState("");
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  const editable = can("SUPER_ADMIN");

  function load() {
    setLoading(true);
    setError("");
    api.getSupportSettings()
      .then((s) => {
        const list = (s.numbers && s.numbers.length)
          ? s.numbers.map((n) => ({ label: n.label || "", number: n.number || "", displayNumber: n.displayNumber || "", primary: !!n.primary, enabled: n.enabled !== false }))
          : [{ label: "General", number: s.whatsappNumber || "", displayNumber: s.whatsappNumberDisplay || s.whatsappNumber || "", primary: true, enabled: true }];
        if (!list.some((n) => n.primary && n.enabled)) {
          const first = list.find((n) => n.enabled);
          if (first) first.primary = true;
        }
        setNumbers(list);
        setHours(s.availabilityHoursEn || "");
        setEmail(s.supportEmail || "");
      })
      .catch((err) => setError(err.message || "Could not load support settings."))
      .finally(() => setLoading(false));
  }
  useEffect(load, []);

  const update = (i, patch) => setNumbers((cur) => cur.map((n, idx) => (idx === i ? { ...n, ...patch } : n)));
  const makePrimary = (i) => setNumbers((cur) => cur.map((n, idx) => ({ ...n, primary: idx === i })));
  const addLine = () => setNumbers((cur) => [...cur, emptyLine()]);
  const removeLine = (i) => setNumbers((cur) => {
    const next = cur.filter((_, idx) => idx !== i);
    if (next.length && !next.some((n) => n.primary && n.enabled)) {
      const first = next.find((n) => n.enabled);
      if (first) first.primary = true;
    }
    return next;
  });

  const enabledCount = numbers.filter((n) => n.enabled && n.number.trim()).length;
  const validationError = enabledCount === 0
    ? "Add at least one enabled support number."
    : (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? "Enter a valid escalation email." : "");

  async function save() {
    if (validationError) { toast(validationError, "error"); return; }
    setSaving(true);
    try {
      await runAction(() => api.updateSupportSettings({
        numbers: numbers
          .filter((n) => n.number.trim())
          .map((n) => ({ label: n.label.trim(), number: n.number.trim(), displayNumber: n.displayNumber.trim() || n.number.trim(), primary: n.primary, enabled: n.enabled })),
        availabilityHoursEn: hours,
        supportEmail: email
      }), { success: "Support settings saved" });
      load();
    } catch { /* toast */ } finally { setSaving(false); }
  }

  if (loading) return <SkeletonRows cols={1} rows={3} />;
  if (error) return <StateBlock variant="error" body={error} onAction={load} />;

  return (
    <article className="panel" style={{ maxWidth: 620 }}>
      <p className="eyebrow">Support channels</p>
      <h2 style={settingsHeadingStyle}>Support numbers</h2>
      <p className="rule-hint" style={{ marginTop: 4 }}>
        Add as many lines as you need — general, payments, a city line. The <strong>primary</strong> line is the one both apps show first; the rest appear as additional contacts. Disabled lines are hidden from customers.
      </p>

      <div className="support-lines">
        {numbers.map((n, i) => (
          <div className={`support-line ${n.enabled ? "" : "off"}`} key={i}>
            <div className="support-line-grid">
              <label className="stack-label sm">Label
                <input value={n.label} disabled={!editable} onChange={(e) => update(i, { label: e.target.value })} placeholder="General" />
              </label>
              <label className="stack-label sm">Number
                <input value={n.number} disabled={!editable} onChange={(e) => update(i, { number: e.target.value })} placeholder="+201005550000" />
              </label>
              <label className="stack-label sm">Display
                <input value={n.displayNumber} disabled={!editable} onChange={(e) => update(i, { displayNumber: e.target.value })} placeholder="+20 100 555 0000" />
              </label>
            </div>
            <div className="support-line-actions">
              <label className="mini-check">
                <input type="radio" name="primary-support" checked={n.primary} disabled={!editable || !n.enabled}
                  onChange={() => makePrimary(i)} /> Primary
              </label>
              <label className="mini-check">
                <input type="checkbox" checked={n.enabled} disabled={!editable}
                  onChange={(e) => update(i, { enabled: e.target.checked, primary: e.target.checked ? n.primary : false })} /> Enabled
              </label>
              {editable && numbers.length > 1 && (
                <button className="btn btn-ghost sm" onClick={() => removeLine(i)}><Trash2 size={13} /> Remove</button>
              )}
            </div>
          </div>
        ))}
      </div>
      {editable && (
        <button className="btn btn-ghost sm" onClick={addLine} style={{ marginTop: 4 }}><Plus size={14} /> Add number</button>
      )}

      <div className="hr" />
      <label className="stack-label">Support hours
        <input value={hours} disabled={!editable} onChange={(e) => setHours(e.target.value)} placeholder="Daily · 9:00 AM – 11:00 PM" />
      </label>
      <label className="stack-label">Escalation email
        <input value={email} disabled={!editable} onChange={(e) => setEmail(e.target.value)} placeholder="urgent@aiwa.com" type="email" />
      </label>
      <p className="rule-hint">The escalation email receives SOS incidents and payment disputes.</p>

      {validationError && <InlineBanner tone="warn" title={validationError} />}
      <button className="btn btn-primary sm" disabled={saving || !editable || !!validationError} onClick={save} style={{ marginTop: 12 }}>
        <Check size={15} /> {saving ? "Saving…" : "Save support settings"}
      </button>
      {!editable && <ReadOnlyNote need="SUPER_ADMIN" />}
    </article>
  );
}

/* Booking rules — GET/PATCH /admin/settings/booking-rules */
function BookingRulesPanel() {
  const [rules, setRules] = useState(null);
  const [draft, setDraft] = useState({ cancellationCutoffHours: 2, providerCancelPenaltyPercent: 15, responseWindowMinutes: 120 });
  const [saving, setSaving] = useState(false);
  const [feedback, setFeedback] = useState(null);

  useEffect(() => {
    let alive = true;
    api.getBookingRules().then((result) => {
      if (!alive || !result) return;
      const normalized = {
        cancellationCutoffHours: result.cancellationCutoffHours,
        providerCancelPenaltyPercent: Number(result.providerCancelPenaltyPercent),
        responseWindowMinutes: result.responseWindowMinutes
      };
      setRules(normalized);
      setDraft(normalized);
    }).catch(() => {});
    return () => { alive = false; };
  }, []);

  const setField = (key, value) => setDraft((current) => ({ ...current, [key]: value }));
  const dirty = rules && ["cancellationCutoffHours", "providerCancelPenaltyPercent", "responseWindowMinutes"]
    .some((key) => Number(draft[key]) !== Number(rules[key]));

  async function save() {
    setSaving(true);
    setFeedback(null);
    try {
      const updated = await api.setBookingRules(draft);
      const normalized = {
        cancellationCutoffHours: updated.cancellationCutoffHours,
        providerCancelPenaltyPercent: Number(updated.providerCancelPenaltyPercent),
        responseWindowMinutes: updated.responseWindowMinutes
      };
      setRules(normalized);
      setDraft(normalized);
      setFeedback({ kind: "ok", text: "Saved — applies to future bookings only." });
    } catch (err) {
      setFeedback({ kind: "error", text: err.message || "Could not save booking rules." });
    } finally {
      setSaving(false);
    }
  }

  const sliders = [
    { key: "cancellationCutoffHours", label: "Free cancellation cutoff", unit: "hours before", min: 0, max: 24, hint: "Cancelling later applies the customer penalty." },
    { key: "providerCancelPenaltyPercent", label: "Provider cancel penalty", unit: "% of price", min: 0, max: 50, hint: "Flagged against the provider on late cancellation." },
    { key: "responseWindowMinutes", label: "Provider response window", unit: "minutes", min: 5, max: 240, hint: "Pending requests auto-expire after this." }
  ];

  return (
    <article className="panel">
      <p className="eyebrow">Booking rules</p>
      <h2 style={settingsHeadingStyle}>Booking rules</h2>
      <p className="muted">Applies to future bookings only; existing bookings keep the rules that were live when created.</p>
      {sliders.map((slider) => (
        <div className="rule-row" key={slider.key}>
          <div className="rule-head">
            <span>{slider.label}</span>
            <span className="mono">{draft[slider.key] ?? slider.min} <small>{slider.unit}</small></span>
          </div>
          <input type="range" min={slider.min} max={slider.max} value={draft[slider.key] ?? slider.min}
            onChange={(event) => setField(slider.key, Number(event.target.value))} aria-label={slider.label} />
          <div className="rule-hint">{slider.hint}</div>
        </div>
      ))}
      <button className="btn btn-primary sm" disabled={saving || !dirty || !can("SUPER_ADMIN")} onClick={save} style={{ marginTop: 4 }}>
        <Check size={15} /> {saving ? "Saving…" : "Save booking rules"}
      </button>
      {feedback && (
        <div className="muted" style={{ marginTop: 10, color: feedback.kind === "error" ? "var(--danger-700)" : "var(--success-700)" }}>{feedback.text}</div>
      )}
    </article>
  );
}

/* ─────────────────────────── Add admin modal ─────────────────────────── */
function AddAdminModal({ onClose, onCreate }) {
  const [form, setForm] = useState({ fullName: "", email: "", phone: "", password: "", confirmPassword: "" });
  const [permissions, setPermissions] = useState(["SUPPORT"]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  function update(field, value) {
    setForm((current) => ({ ...current, [field]: value }));
  }
  const togglePerm = (id) => setPermissions((cur) => (cur.includes(id) ? cur.filter((x) => x !== id) : [...cur, id]));

  async function submit(event) {
    event.preventDefault();
    setError("");
    if (form.fullName.trim().length < 2 || !/\S+@\S+\.\S+/.test(form.email)) {
      setError("Enter a valid name and email.");
      return;
    }
    if (form.password.length < 12) {
      setError("Password must be at least 12 characters.");
      return;
    }
    if (form.password !== form.confirmPassword) {
      setError("Password confirmation does not match.");
      return;
    }
    if (permissions.length === 0) {
      setError("Select at least one permission.");
      return;
    }
    setLoading(true);
    try {
      await onCreate({ fullName: form.fullName.trim(), email: form.email.trim(), phone: form.phone || null, password: form.password, permissions });
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <form className="modal-card" onClick={(e) => e.stopPropagation()} onSubmit={submit}>
        <button type="button" className="modal-close" onClick={onClose}><X size={18} /></button>
        <p className="eyebrow">Admin accounts</p>
        <h2>Create admin user</h2>
        <label>Full name<input value={form.fullName} onChange={(event) => update("fullName", event.target.value)} placeholder="e.g. Mona Farouk" required /></label>
        <label>Email<input value={form.email} onChange={(event) => update("email", event.target.value)} placeholder="admin@aiwa.com" type="email" required /></label>
        <label>Phone <span>(optional)</span><input value={form.phone} onChange={(event) => update("phone", event.target.value)} placeholder="100 555 0000" /></label>
        <label>Password<input value={form.password} onChange={(event) => update("password", event.target.value)} placeholder="At least 12 characters" type="password" required /></label>
        <label>Confirm password<input value={form.confirmPassword} onChange={(event) => update("confirmPassword", event.target.value)} placeholder="Re-enter password" type="password" required /></label>
        <div className="field-label">Permissions</div>
        <PermissionPicker selected={permissions} onToggle={togglePerm} />
        {error && <div className="form-error">{error}</div>}
        <div className="modal-actions">
          <button type="button" className="btn btn-secondary" onClick={onClose}>Cancel</button>
          <button className="btn btn-primary" disabled={loading}><UserPlus size={16} /> {loading ? "Creating…" : "Create admin"}</button>
        </div>
      </form>
    </div>
  );
}

/* ─────────────────────────── Shared bits ─────────────────────────── */
const AVATAR_PALETTES = ["plum", "rose", "gold"];
function paletteFor(name, explicit) {
  if (explicit) return explicit;
  const s = String(name || "?");
  let hash = 0;
  for (let i = 0; i < s.length; i += 1) hash = (hash * 31 + s.charCodeAt(i)) >>> 0;
  return AVATAR_PALETTES[hash % AVATAR_PALETTES.length];
}

function Avatar({ name, size = 40, palette }) {
  const tone = paletteFor(name, palette);
  return (
    <span className={`avatar ${tone}`} style={{ width: size, height: size, fontSize: Math.round(size * 0.42) }}>
      {String(name || "?").charAt(0).toUpperCase()}
    </span>
  );
}

function ProfileCell({ name, subtitle, palette, flag }) {
  return (
    <span className="profile-cell">
      <Avatar name={name} palette={palette} size={36} />
      <span>
        <strong>{name}</strong>
        {flag ? <span className="row-flag"><AlertTriangle size={11} /> {flag}</span> : subtitle ? <small>{subtitle}</small> : null}
      </span>
    </span>
  );
}

const STATUS_LABELS = {
  OK: "Within limit",
  IN_REVIEW: "In review",
  UNDER_REVIEW: "In review",
  ON_THE_WAY: "On the way",
  NEEDS_RESUBMIT: "Needs resubmit",
  NO_SHOW: "No-show"
};
function prettyStatus(value) {
  if (STATUS_LABELS[value]) return STATUS_LABELS[value];
  return value.charAt(0) + value.slice(1).toLowerCase().replace(/_/g, " ");
}

export function Status({ status, dot }) {
  const normalized = String(status || "").toUpperCase();
  return <span className={`status ${normalized.toLowerCase()}`}>{dot && <i className="pip" />}{prettyStatus(normalized)}</span>;
}

function Priority({ value }) {
  return <span className={`priority ${String(value).toLowerCase()}`}>{value}</span>;
}

export function RolePill({ role }) {
  const normalized = String(role || "").toLowerCase();
  const cls = normalized === "provider" ? "provider" : normalized === "admin" ? "admin" : "customer";
  return <span className={`role-pill ${cls}`}>{String(role).toUpperCase()}</span>;
}

function Stars({ value }) {
  return (
    <span className="stars">
      {[1, 2, 3, 4, 5].map((star) => <Star key={star} size={14} fill={star <= value ? "currentColor" : "none"} strokeWidth={star <= value ? 0 : 1.8} />)}
    </span>
  );
}

// Global "reload every visible screen" broadcast — the header refresh button
// fires this, and every useLoad on the page re-runs its fetch. No page-by-page
// wiring needed; new screens get it for free.
const appRefreshListeners = new Set();
export function refreshApp() { appRefreshListeners.forEach((fn) => { try { fn(); } catch {} }); }

function useLoad(loader, fallback) {
  const [data, setData] = useState(() => (USE_MOCKS ? fallback : emptyDataFor(fallback)));
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [reloadKey, setReloadKey] = useState(0);

  // Subscribe to the global refresh — so any useLoad in the tree re-fetches
  // when the top-bar refresh button is clicked.
  useEffect(() => {
    const listener = () => setReloadKey((k) => k + 1);
    appRefreshListeners.add(listener);
    return () => appRefreshListeners.delete(listener);
  }, []);

  useEffect(() => {
    let alive = true;
    setError("");
    setLoading(true);
    loader()
      .then((result) => {
        if (alive && result) {
          setData(result);
          setError("");
        }
      })
      .catch((err) => {
        if (alive) {
          // 401 = the session is gone; 403 = signed in but not allowed here,
          // which must not sign the admin out (OPS-9).
          if (err?.status === 401) {
            setError("Session expired. Please sign in again.");
            onAuthExpired();
          } else if (err?.status === 403) {
            setError("You don't have permission to view this.");
          } else {
            setError(err.message || "Request failed");
          }
          setData(USE_MOCKS ? fallback : emptyDataFor(fallback));
        }
      })
      .finally(() => { if (alive) setLoading(false); });
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [reloadKey]);

  return { data, setData, error, loading, reload: () => setReloadKey((key) => key + 1) };
}

function emptyDataFor(fallback) {
  if (Array.isArray(fallback)) return [];
  if (fallback?.stats && fallback?.activity) return { stats: [], activity: [] };
  return fallback;
}
