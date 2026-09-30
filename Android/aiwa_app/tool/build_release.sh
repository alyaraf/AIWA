#!/usr/bin/env bash
# Release build (FE-1 / FE-2). Always passes the production dart-defines so a
# store build can never fall back to the emulator API address.
#
#   API_BASE_URL=https://api.aiwa.app/api SENTRY_DSN=... tool/build_release.sh [appbundle|ipa]
#
# Push (FE-3): also export FIREBASE_API_KEY, FIREBASE_PROJECT_ID, FIREBASE_SENDER_ID,
# FIREBASE_ANDROID_APP_ID and FIREBASE_IOS_APP_ID from the Firebase console
# (Project settings -> Your apps). Without them the app builds with push off.
# Share links (FE-13): APP_LINK_BASE=https://<domain> (the public site domain)
set -euo pipefail
: "${API_BASE_URL:?Set API_BASE_URL (https://api.<domain>/api)}"
case "$API_BASE_URL" in https://*) ;; *) echo "API_BASE_URL must start with https://" >&2; exit 1;; esac
if [ -z "${SENTRY_DSN:-}" ]; then echo "warning: SENTRY_DSN not set - crash reporting stays off" >&2; fi
if [ -z "${FIREBASE_PROJECT_ID:-}" ]; then echo "warning: FIREBASE_* not set - push notifications stay off" >&2; fi

target="${1:-appbundle}"
cd "$(dirname "$0")/.."
flutter build "$target" --release \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=SENTRY_DSN="${SENTRY_DSN:-}" \
  --dart-define=APP_LINK_BASE="${APP_LINK_BASE:-aiwa://app}" \
  --dart-define=FIREBASE_API_KEY="${FIREBASE_API_KEY:-}" \
  --dart-define=FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-}" \
  --dart-define=FIREBASE_SENDER_ID="${FIREBASE_SENDER_ID:-}" \
  --dart-define=FIREBASE_ANDROID_APP_ID="${FIREBASE_ANDROID_APP_ID:-}" \
  --dart-define=FIREBASE_IOS_APP_ID="${FIREBASE_IOS_APP_ID:-}"
