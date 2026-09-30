# AIWA — Admin Dashboard

Desktop web admin panel for AIWA (beauty & grooming marketplace). Rebuilt to match the
AIWA design system (deep plum + warm cream + rose + brass gold), per
`design_handoff_aiwa_app`.

## Stack
- React 18 + Vite 6
- lucide-react icons
- Google Fonts: DM Serif Display (display), Plus Jakarta Sans (body), JetBrains Mono (data)

## Run
```bash
npm ci             # npm only: package-lock.json is the one lockfile
npm run dev
```
Vite serves on http://127.0.0.1:5173.

Mock mode is off by default. Set `VITE_USE_MOCKS=true` to run without a backend (any email/password then signs you in).
To connect the Spring Boot backend, create a `.env`:
```
VITE_USE_MOCKS=false
VITE_API_BASE_URL=http://localhost:8080/api
```

## Deploy

`Dockerfile` builds the panel (tests must pass) and serves it with nginx and a strict
Content-Security-Policy (`deploy/nginx.conf.template`). See `docs/release.md` at the repo root.


## Screens
Dashboard · Verifications (queue + ID review + approve/reject) · Complaints · Flags
(warn/suspend/ban) · Users & providers (+ add admin) · Bookings · Reviews · Moderation
(hide image / remove review) · Settlements (commission oversight) · Policies & support.

## Files
- `src/App.jsx` — all screens + shared components
- `src/api.js` — API client + mock data (toggle via `VITE_USE_MOCKS`)
- `src/styles.css` — AIWA design tokens + component styling
- `index.html` — font loading + root
