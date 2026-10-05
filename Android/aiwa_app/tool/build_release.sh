#!/usr/bin/env bash
# Release build (FE-1 / FE-2). Always passes the production dart-defines so a
# store build can never fall back to the emulator API address.
#
#   API_BASE_URL=https://api.aiwa.app/api SENTRY_DSN=... tool/build_release.sh [appbundle|ipa]
#
# Push (FE-3): also export FIREBASE_API_KEY, FIREBASE_PROJECT_ID, FIREBASE_SENDER_ID,
# FIREBASE_ANDROID_APP_ID and FIREBASE_IOS_APP_ID from the Firebase console
# (Project settings -> Your apps). They are required (R2-21): a store build
# without them would ship with push silently off. ALLOW_NO_PUSH=1 overrides
# that for an internal test build only.
# Share links (FE-13): APP_LINK_BASE=https://<domain> (the public site domain)
set -euo pipefail
: "${API_BASE_URL:?Set API_BASE_URL (https://api.<domain>/api)}"
case "$API_BASE_URL" in https://?*) ;; *) echo "API_BASE_URL must start with https://" >&2; exit 1;; esac
if [ -z "${SENTRY_DSN:-}" ]; then echo "warning: SENTRY_DSN not set - crash reporting stays off" >&2; fi
missing_push=""
for v in FIREBASE_API_KEY FIREBASE_PROJECT_ID FIREBASE_SENDER_ID FIREBASE_ANDROID_APP_ID FIREBASE_IOS_APP_ID; do
  if [ -z "${!v:-}" ]; then missing_push="$missing_push $v"; fi
done
if [ -n "$missing_push" ]; then
  if [ "${ALLOW_NO_PUSH:-}" = "1" ]; then
    echo "warning: push notifications OFF in this build (missing:$missing_push)" >&2
  else
    echo "Missing:$missing_push. Set them, or ALLOW_NO_PUSH=1 for an internal build without push." >&2
    exit 1
  fi
fi
if [ "${1:-appbundle}" = "ipa" ]; then
  # R2-21: iOS signing and Universal Links come from the git-ignored
  # ios/Flutter/Signing.xcconfig (see ios/Flutter/Signing.xcconfig.example).
  if [ ! -f "$(dirname "$0")/../ios/Flutter/Signing.xcconfig" ]; then
    echo "Create ios/Flutter/Signing.xcconfig (team ID and link domain) from Signing.xcconfig.example" >&2
    exit 1
  fi
fi

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
