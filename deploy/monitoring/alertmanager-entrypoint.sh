#!/bin/sh
# R2-04: Prometheus had alert rules but nothing delivered them. This builds the
# Alertmanager config from deploy/.env and refuses to start when no receiver is
# configured, so "alerts reach no one" shows up as a restarting container
# instead of silence.
#
#   Email:    ALERT_EMAIL_TO, ALERT_EMAIL_FROM, ALERT_SMTP_HOST (host:port),
#             ALERT_SMTP_USER, ALERT_SMTP_PASSWORD
#   Telegram: ALERT_TELEGRAM_BOT_TOKEN, ALERT_TELEGRAM_CHAT_ID
set -eu

cfg=/tmp/alertmanager.yml
email="${ALERT_EMAIL_TO:-}"
tg_token="${ALERT_TELEGRAM_BOT_TOKEN:-}"
tg_chat="${ALERT_TELEGRAM_CHAT_ID:-}"

if [ -z "$email" ] && { [ -z "$tg_token" ] || [ -z "$tg_chat" ]; }; then
  echo "alertmanager: set ALERT_EMAIL_TO (+ SMTP settings) or ALERT_TELEGRAM_BOT_TOKEN and ALERT_TELEGRAM_CHAT_ID in deploy/.env" >&2
  exit 1
fi

q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"; }

{
  echo "route:"
  echo "  receiver: team"
  echo "  group_by: [alertname]"
  echo "  group_wait: 30s"
  echo "  group_interval: 5m"
  echo "  repeat_interval: 4h"
  echo "  routes:"
  echo "    - matchers: ['alertname=\"Watchdog\"']"
  echo "      receiver: watchdog"
  echo "      group_wait: 0s"
  echo "      group_interval: 1m"
  echo "      repeat_interval: 5m"
  echo "    - matchers: ['severity=\"critical\"']"
  echo "      receiver: team"
  echo "      group_wait: 0s"
  echo "      repeat_interval: 30m"
  echo "receivers:"
  # F-07: dead-man's switch. The Watchdog alert always fires; with DEADMAN_WEBHOOK_URL set (healthchecks.io,
  # Better Stack) it is pinged every 5 minutes, so the external service alerts when this whole pipeline stops.
  echo "  - name: watchdog"
  if [ -n "${DEADMAN_WEBHOOK_URL:-}" ]; then
    echo "    webhook_configs:"
    echo "      - url: $(q "$DEADMAN_WEBHOOK_URL")"
    echo "        send_resolved: false"
  fi
  echo "  - name: team"
  if [ -n "$email" ]; then
    echo "    email_configs:"
    echo "      - to: $(q "$email")"
    echo "        from: $(q "${ALERT_EMAIL_FROM:?ALERT_EMAIL_FROM is required with ALERT_EMAIL_TO}")"
    echo "        smarthost: $(q "${ALERT_SMTP_HOST:?ALERT_SMTP_HOST (host:port) is required with ALERT_EMAIL_TO}")"
    echo "        auth_username: $(q "${ALERT_SMTP_USER:-}")"
    echo "        auth_password: $(q "${ALERT_SMTP_PASSWORD:-}")"
    echo "        send_resolved: true"
  fi
  if [ -n "$tg_token" ] && [ -n "$tg_chat" ]; then
    echo "    telegram_configs:"
    echo "      - bot_token: $(q "$tg_token")"
    echo "        chat_id: $tg_chat"
    echo "        send_resolved: true"
  fi
} > "$cfg"

exec /bin/alertmanager --config.file="$cfg" --storage.path=/alertmanager "$@"
