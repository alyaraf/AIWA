#!/bin/sh
# Nightly backup (OPS-2): a PostgreSQL custom-format dump plus a tarball of the
# uploads volume (gallery, avatars and private ID documents), kept for
# BACKUP_KEEP_DAYS. Copy deploy/backups/ off the server too (see docs/runbooks.md):
# a backup on the same disk doesn't survive losing the server.
#
#   backup.sh          loop: back up now, then every BACKUP_INTERVAL_SECONDS
#   backup.sh once     one backup and exit (docker compose run --rm backup once)
set -eu

KEEP_DAYS="${BACKUP_KEEP_DAYS:-14}"
INTERVAL="${BACKUP_INTERVAL_SECONDS:-86400}"
OUT=/backups

run_backup() {
  stamp=$(date -u +%Y%m%d-%H%M%S)
  mkdir -p "$OUT/db" "$OUT/uploads"

  # Write to a temp name first so a half-written dump is never mistaken for a good one.
  pg_dump -Fc -f "$OUT/db/aiwa-$stamp.dump.partial"
  pg_restore --list "$OUT/db/aiwa-$stamp.dump.partial" > /dev/null   # fails on a corrupt dump
  mv "$OUT/db/aiwa-$stamp.dump.partial" "$OUT/db/aiwa-$stamp.dump"

  tar -czf "$OUT/uploads/uploads-$stamp.tar.gz.partial" -C /uploads .
  mv "$OUT/uploads/uploads-$stamp.tar.gz.partial" "$OUT/uploads/uploads-$stamp.tar.gz"

  find "$OUT/db" "$OUT/uploads" -type f -mtime +"$KEEP_DAYS" -delete
  find "$OUT/db" "$OUT/uploads" -type f -name '*.partial' -mmin +120 -delete
  echo "$(date -u +%FT%TZ) backup ok: aiwa-$stamp.dump, uploads-$stamp.tar.gz"
}

if [ "${1:-loop}" = "once" ]; then
  run_backup
  exit 0
fi

while true; do
  run_backup || echo "$(date -u +%FT%TZ) BACKUP FAILED" >&2
  sleep "$INTERVAL"
done
