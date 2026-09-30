#!/usr/bin/env bash
# Release build (FE-1 / FE-2). Always passes the production dart-defines so a
# store build can never fall back to the emulator API address.
#
#   API_BASE_URL=https://api.aiwa.app/api SENTRY_DSN=... tool/build_release.sh [appbundle|ipa]
set -euo pipefail
: "${API_BASE_URL:?Set API_BASE_URL (https://api.<domain>/api)}"
case "$API_BASE_URL" in https://*) ;; *) echo "API_BASE_URL must start with https://" >&2; exit 1;; esac
if [ -z "${SENTRY_DSN:-}" ]; then echo "warning: SENTRY_DSN not set - crash reporting stays off" >&2; fi

target="${1:-appbundle}"
cd "$(dirname "$0")/.."
flutter build "$target" --release \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=SENTRY_DSN="${SENTRY_DSN:-}" \
  ${APP_LINK_BASE:+--dart-define=APP_LINK_BASE="$APP_LINK_BASE"}
