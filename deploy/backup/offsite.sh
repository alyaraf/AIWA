#!/bin/sh
# F-02: copies the encrypted backups off the server, then proves the copy is there.
#
# Uses "rclone copy --immutable", never "sync": a wiped or ransomware-encrypted local backups/
# directory must not be mirrored over the remote copy, and a file already on the remote is never
# rewritten. Turn on bucket versioning / object lock on the remote as well (docs/runbooks.md).
# Only encrypted files (*.enc) are sent; plain backups (BACKUP_ALLOW_UNENCRYPTED) stay local.
#
# Needs: OFFSITE_REMOTE (e.g. aiwa:aiwa-backups) and an rclone config at /config/rclone.conf
# (deploy/secrets/rclone.conf). Writes aiwa_offsite_last_success_timestamp_seconds to
# /backups/metrics/offsite.txt (served by the backup container, alerts: OffsiteBackupStale).
set -uf  # -f: no globbing, the *.enc filter below is for rclone, not the shell

REMOTE="${OFFSITE_REMOTE:?Set OFFSITE_REMOTE (remote:bucket/path)}"
INTERVAL="${OFFSITE_INTERVAL_SECONDS:-21600}"
SRC="${BACKUP_DIR:-/backups}"
FILTER="--include *.enc --exclude *"

copy_once() {
  for part in db uploads; do
    # shellcheck disable=SC2086
    rclone copy "$SRC/$part" "$REMOTE/$part" --immutable --config /config/rclone.conf $FILTER || { echo "$(date -u +%FT%TZ) OFFSITE FAILED: copy of $part" >&2; return 1; }
    # shellcheck disable=SC2086
    rclone check "$SRC/$part" "$REMOTE/$part" --one-way --config /config/rclone.conf $FILTER || { echo "$(date -u +%FT%TZ) OFFSITE FAILED: $part on the remote does not match" >&2; return 1; }
  done
  mkdir -p "$SRC/metrics"
  printf '# TYPE aiwa_offsite_last_success_timestamp_seconds gauge\naiwa_offsite_last_success_timestamp_seconds %s\n' "$(date -u +%s)" > "$SRC/metrics/offsite.txt.new" \
    && mv "$SRC/metrics/offsite.txt.new" "$SRC/metrics/offsite.txt"
  echo "$(date -u +%FT%TZ) offsite ok"
  if [ -n "${OFFSITE_HEARTBEAT_URL:-}" ]; then
    wget -q -O /dev/null -T 10 "$OFFSITE_HEARTBEAT_URL" || echo "$(date -u +%FT%TZ) offsite heartbeat ping failed" >&2
  fi
}

if [ "${1:-loop}" = "once" ]; then copy_once; exit $?; fi
while true; do
  copy_once || true
  sleep "$INTERVAL"
done
