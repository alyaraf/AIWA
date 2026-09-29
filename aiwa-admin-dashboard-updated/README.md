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
pnpm install        # or: npm install
pnpm dev            # or: npm run dev
```
Vite serves on http://127.0.0.1:5173.

Mock mode is on by default (no backend needed). Any email/password signs you in.
To connect the Spring Boot backend, create a `.env`:
```
VITE_USE_MOCKS=false
VITE_API_BASE_URL=http://localhost:8080/api
```

## Screens
Dashboard · Verifications (queue + ID review + approve/reject) · Complaints · Flags
(warn/suspend/ban) · Users & providers (+ add admin) · Bookings · Reviews · Moderation
(hide image / remove review) · Settlements (commission oversight) · Policies & support.

## Files
- `src/App.jsx` — all screens + shared components
- `src/api.js` — API client + mock data (toggle via `VITE_USE_MOCKS`)
- `src/styles.css` — AIWA design tokens + component styling
- `index.html` — font loading + root
