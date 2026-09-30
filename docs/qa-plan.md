# Real-device QA and pilot (OPS-7)

Run against **staging** (never production data), with a release build made by
`tool/build_release.sh` so signing, the HTTPS API and Sentry are the real ones.

## Devices

| # | Device | Why |
|---|--------|-----|
| 1 | Low-end Android, 2–3 GB RAM, Android 10–11 (e.g. Samsung A0x, Xiaomi Redmi 9) | most common in Egypt; performance and memory |
| 2 | Mid-range Android 13–14 (notification permission prompt) | runtime notification permission |
| 3 | Recent Samsung or Pixel, Android 15 | current OS behaviour, edge-to-edge |
| 4 | Older iPhone on the oldest supported iOS | layout at small width, permissions |
| 5 | Recent iPhone | current iOS |

Each device in **both palettes** (sign up once as male and once as female) and
**both languages** (English LTR, Arabic RTL). Once per device: system text size at
130%, and a throttled network (3G / "poor" in developer options).

## Pass 1: customer (per device)

1. Fresh install → splash → language → browse as guest → guest-locked tabs.
2. Sign up by phone (real SMS arrives, resend works after the countdown), set up
   account, photo, gender (palette changes), terms, preferences, permissions priming.
3. Home, search, filters, provider profile, gallery, reviews, save a provider.
4. Book later: date, slot, home address, confirm; slot-conflict path (two phones
   booking the same slot).
5. Book now against an offline provider (blocked screen) and an online one.
6. Tracking: provider accepts → on the way → arrived → in progress → done; travel
   fee accept and decline; chat both ways; cancel with a reason on another booking.
7. SOS during a home visit: on-call phone and trusted contact get the SMS, admin
   Safety screen shows it, "I'm safe" closes it.
8. Pay-in-cash confirm, review, complaint; notification preferences and quiet hours.
9. Kill the app mid-booking and reopen; airplane mode (offline banner, retry).
10. Sign out, sign in with "remember me" off; delete account (then the web page
    `https://staging.<domain>/delete-account` for the no-app path).

## Pass 2: provider (two devices: individual and shop)

Sign up, business info, ID upload and selfie, pending screen, admin approves;
services, schedule, travel buffer, vacation / offline; accept, reject with
alternatives, propose a new time, quote a travel fee, no-show, cash received,
rate the customer; wallet and a settlement pause; gallery upload, cancel an upload,
delete a photo; staff picker for the shop.

## Pass 3: admin panel (desktop Chrome + Safari)

Verification approve / reject / request info; complaints with notes; flags;
dispute resolution; settlement pause and payout; publish new terms (the app asks
customers to re-accept); support settings; audit log export; user search past 500
users (seed a big staging dataset).

## Recording results

One row per device × pass: device, OS, palette, language, pass/fail, and for each
failure a screenshot, the booking/user id, and the Sentry event link. Fix blockers,
re-run the failed rows.

## Pilot

After a clean pass: 5–10 providers in one district (e.g. Zamalek or Maadi),
invited by hand, for 2–3 weeks, sign-ups closed to everyone else.

- Watch daily: Sentry errors, the admin Safety and complaints queues, settlements.
- Talk to every pilot provider weekly; log what confused them.
- Exit criteria: no open blocker, no unexplained crash, every SOS test answered in
  under 5 minutes, settlements reconciled, and the providers would recommend it.
