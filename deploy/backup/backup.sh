#!/bin/sh
# Nightly backup (OPS-2): a PostgreSQL custom-format dump plus a tarball of the
# uploads volume (gallery, avatars and private ID documents), kept for
# BACKUP_KEEP_DAYS. Copy deploy/backups/ off the server too (see docs/runbooks.md):
# a backup on the same disk doesn't survive losing the server.
#
#   backup.sh          loop: back up now, then every BACKUP_INTERVAL_SECONDS
#   backup.sh once     one backup and exit (docker compose run --rm backup once)
#
# R2-02: every step is checked explicitly. "set -e" does nothing inside a
# function called as "run_backup || …", so a failed pg_dump used to leave a
# 15-byte file that was renamed to .dump and logged as "backup ok". Now a
# failed step removes its partial file, the run says BACKUP FAILED, and
# /backups/last-success is only touched when both parts are verified.
# CR-20: after each good backup the age of the last success is written to
# $OUT/metrics/metrics.txt, which this container serves on :9100 for Prometheus
# (alerts.yml: BackupStale, BackupMetricsMissing, BackupNotEncrypted). A failed run
# leaves the old timestamp, so the alert needs no optional setting. When a key file
# is mounted (BACKUP_KEY_FILE, docs/runbooks.md) the dump and the uploads tarball are
# encrypted with openssl; without one the backup still runs, warns, and
# aiwa_backup_encrypted is 0.
# Optional: BACKUP_HEARTBEAT_URL (healthchecks.io, Better Stack, …) is called
# after each good backup, so a missing ping alerts someone.
set -u

KEEP_DAYS="${BACKUP_KEEP_DAYS:-14}"
INTERVAL="${BACKUP_INTERVAL_SECONDS:-86400}"
MIN_DUMP_BYTES="${BACKUP_MIN_DUMP_BYTES:-1024}"
OUT="${BACKUP_DIR:-/backups}"
UPLOADS="${UPLOADS_DIR:-/uploads}"
KEY="${BACKUP_KEY_FILE:-}"
METRICS_PORT="${BACKUP_METRICS_PORT:-9100}"

fail() {
  echo "$(date -u +%FT%TZ) BACKUP FAILED: $*" >&2
  return 1
}

# Encrypt $1 to $2 (same settings as restore.sh), prove it decrypts back to $1, drop $1.
# The key is read into the environment because Windows openssl has no fd: passwords.
encrypt() {
  command -v openssl > /dev/null || apk add -q --no-cache openssl > /dev/null 2>&1 || return 1
  BACKUP_PASS=$(cat "$KEY") openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -pass env:BACKUP_PASS < "$1" > "$2" || return 1
  BACKUP_PASS=$(cat "$KEY") openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass env:BACKUP_PASS < "$2" | cmp -s - "$1" || return 1
  rm -f "$1"
}

# SA-04: pg_restore --list reads only the table of contents, so a dump cut off in its payload passed
# it. Restoring into a throwaway database proves the whole file reads back.
verify_dump() {
  v="aiwa_verify_$$"
  createdb "$v" || return 1
  if pg_restore --no-owner --exit-on-error -d "$v" "$1" > /dev/null 2>&1; then
    dropdb --if-exists "$v" > /dev/null 2>&1 || true
    return 0
  fi
  dropdb --if-exists "$v" > /dev/null 2>&1 || true
  return 1
}

run_backup() {
  stamp=$(date -u +%Y%m%d-%H%M%S)
  dump="$OUT/db/aiwa-$stamp.dump"
  tarball="$OUT/uploads/uploads-$stamp.tar.gz"
  encrypted=0; ext=""
  # -f: Docker makes a directory of a bind-mounted file that does not exist; a blank key would encrypt with an empty password
  if [ -f "$KEY" ] && [ -r "$KEY" ] && [ -n "$(cat "$KEY")" ]; then
    encrypted=1; ext=".enc"
  else
    echo "$(date -u +%FT%TZ) WARNING: no backup key at '${KEY:-BACKUP_KEY_FILE unset}': this backup is NOT encrypted (docs/runbooks.md)" >&2
  fi
  mkdir -p "$OUT/db" "$OUT/uploads" "$OUT/metrics" || { fail "cannot create $OUT"; return 1; }

  # Write to a temp name first so a half-written dump is never mistaken for a good one.
  if ! pg_dump -Fc -f "$dump.partial"; then
    rm -f "$dump.partial"; fail "pg_dump exited non-zero"; return 1
  fi
  size=$(wc -c < "$dump.partial" | tr -d ' ')
  if [ "$size" -lt "$MIN_DUMP_BYTES" ]; then
    rm -f "$dump.partial"; fail "dump is only $size bytes"; return 1
  fi
  if ! verify_dump "$dump.partial"; then
    rm -f "$dump.partial"; fail "the dump does not restore into a scratch database"; return 1
  fi
  if [ "$encrypted" = 1 ]; then
    encrypt "$dump.partial" "$dump$ext.partial" || { rm -f "$dump.partial" "$dump$ext.partial"; fail "cannot encrypt the dump"; return 1; }
    mv "$dump$ext.partial" "$dump$ext" || { fail "cannot rename the dump"; return 1; }
  else
    mv "$dump.partial" "$dump" || { fail "cannot rename the dump"; return 1; }
  fi

  if ! tar -czf "$tarball.partial" -C "$UPLOADS" .; then
    rm -f "$tarball.partial"; fail "tar of uploads failed"; return 1
  fi
  if ! gzip -t "$tarball.partial"; then
    rm -f "$tarball.partial"; fail "uploads tarball is corrupt"; return 1
  fi
  if [ "$encrypted" = 1 ]; then
    encrypt "$tarball.partial" "$tarball$ext.partial" || { rm -f "$tarball.partial" "$tarball$ext.partial"; fail "cannot encrypt the uploads tarball"; return 1; }
    mv "$tarball$ext.partial" "$tarball$ext" || { fail "cannot rename the uploads tarball"; return 1; }
  else
    mv "$tarball.partial" "$tarball" || { fail "cannot rename the uploads tarball"; return 1; }
  fi

  find "$OUT/db" "$OUT/uploads" -type f -mtime +"$KEEP_DAYS" -delete
  find "$OUT/db" "$OUT/uploads" -type f -name '*.partial' -mmin +120 -delete
  date -u +%FT%TZ > "$OUT/last-success"
  printf '# TYPE aiwa_backup_last_success_timestamp_seconds gauge
aiwa_backup_last_success_timestamp_seconds %s
# TYPE aiwa_backup_encrypted gauge
aiwa_backup_encrypted %s
'     "$(date -u +%s)" "$encrypted" > "$OUT/metrics/metrics.txt.new" && mv "$OUT/metrics/metrics.txt.new" "$OUT/metrics/metrics.txt" ||
    echo "$(date -u +%FT%TZ) cannot write the backup metrics" >&2
  echo "$(date -u +%FT%TZ) backup ok: aiwa-$stamp.dump$ext ($size bytes), uploads-$stamp.tar.gz$ext"
  if [ -n "${BACKUP_HEARTBEAT_URL:-}" ]; then
    wget -q -O /dev/null -T 10 "$BACKUP_HEARTBEAT_URL" || echo "$(date -u +%FT%TZ) heartbeat ping failed" >&2
  fi
  return 0
}

if [ "${1:-loop}" = "once" ]; then
  run_backup
  exit $?
fi

# Busybox httpd (already in the image) serves the metrics file; Prometheus scrapes backup:9100/metrics.txt.
# If it dies the series goes missing and BackupMetricsMissing fires.
mkdir -p "$OUT/metrics" && httpd -f -p "$METRICS_PORT" -h "$OUT/metrics" &

while true; do
  run_backup || true   # already reported as BACKUP FAILED; the heartbeat stays silent
  sleep "$INTERVAL"
done
