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
# Optional: BACKUP_HEARTBEAT_URL (healthchecks.io, Better Stack, …) is called
# after each good backup, so a missing ping alerts someone.
set -u

KEEP_DAYS="${BACKUP_KEEP_DAYS:-14}"
INTERVAL="${BACKUP_INTERVAL_SECONDS:-86400}"
MIN_DUMP_BYTES="${BACKUP_MIN_DUMP_BYTES:-1024}"
OUT=/backups

fail() {
  echo "$(date -u +%FT%TZ) BACKUP FAILED: $*" >&2
  return 1
}

run_backup() {
  stamp=$(date -u +%Y%m%d-%H%M%S)
  dump="$OUT/db/aiwa-$stamp.dump"
  tarball="$OUT/uploads/uploads-$stamp.tar.gz"
  mkdir -p "$OUT/db" "$OUT/uploads" || { fail "cannot create $OUT"; return 1; }

  # Write to a temp name first so a half-written dump is never mistaken for a good one.
  if ! pg_dump -Fc -f "$dump.partial"; then
    rm -f "$dump.partial"; fail "pg_dump exited non-zero"; return 1
  fi
  size=$(wc -c < "$dump.partial" | tr -d ' ')
  if [ "$size" -lt "$MIN_DUMP_BYTES" ]; then
    rm -f "$dump.partial"; fail "dump is only $size bytes"; return 1
  fi
  # pg_restore --list reads the whole table of contents: fails on a corrupt or truncated dump.
  if ! pg_restore --list "$dump.partial" > /dev/null; then
    rm -f "$dump.partial"; fail "pg_restore cannot read the dump"; return 1
  fi
  mv "$dump.partial" "$dump" || { fail "cannot rename the dump"; return 1; }

  if ! tar -czf "$tarball.partial" -C /uploads .; then
    rm -f "$tarball.partial"; fail "tar of uploads failed"; return 1
  fi
  if ! gzip -t "$tarball.partial"; then
    rm -f "$tarball.partial"; fail "uploads tarball is corrupt"; return 1
  fi
  mv "$tarball.partial" "$tarball" || { fail "cannot rename the uploads tarball"; return 1; }

  find "$OUT/db" "$OUT/uploads" -type f -mtime +"$KEEP_DAYS" -delete
  find "$OUT/db" "$OUT/uploads" -type f -name '*.partial' -mmin +120 -delete
  date -u +%FT%TZ > "$OUT/last-success"
  echo "$(date -u +%FT%TZ) backup ok: aiwa-$stamp.dump ($size bytes), uploads-$stamp.tar.gz"
  if [ -n "${BACKUP_HEARTBEAT_URL:-}" ]; then
    wget -q -O /dev/null -T 10 "$BACKUP_HEARTBEAT_URL" || echo "$(date -u +%FT%TZ) heartbeat ping failed" >&2
  fi
  return 0
}

if [ "${1:-loop}" = "once" ]; then
  run_backup
  exit $?
fi

while true; do
  run_backup || true   # already reported as BACKUP FAILED; the heartbeat stays silent
  sleep "$INTERVAL"
done
