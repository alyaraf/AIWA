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
# leaves the old timestamp, so the alert needs no optional setting. The key file
# (BACKUP_KEY_FILE, docs/runbooks.md) is required: the dump and the uploads tarball are
# encrypted with openssl, and without a key the run fails (BACKUP FAILED) unless
# BACKUP_ALLOW_UNENCRYPTED=1, which warns and sets aiwa_backup_encrypted to 0.
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
SAFETY_KEEP_DAYS="${BACKUP_SAFETY_KEEP_DAYS:-$KEEP_DAYS}"
RECONCILE_SCRIPT="${RECONCILE_SCRIPT:-/reconcile_uploads.sh}"
REFERENCES_SQL="${REFERENCES_SQL:-/uploads_references.sql}"

fail() {
  echo "$(date -u +%FT%TZ) BACKUP FAILED: $*" >&2
  return 1
}

# Encrypt $1 to $2 (same settings as restore.sh), prove it decrypts back to $1, drop $1.
# The key is read into the environment because Windows openssl has no fd: passwords.
encrypt() {
  command -v openssl > /dev/null || return 1  # F-02: baked into the image (backup/Dockerfile), no network install
  BACKUP_PASS=$(cat "$KEY") openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -pass env:BACKUP_PASS < "$1" > "$2" || return 1
  BACKUP_PASS=$(cat "$KEY") openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass env:BACKUP_PASS < "$2" | cmp -s - "$1" || return 1
  rm -f "$1"
}

# SA-04: pg_restore --list reads only the table of contents, so a dump cut off in its payload passed
# it. Restoring into a throwaway database proves the whole file reads back.
# R5-02: while that scratch restore exists it is the only place that holds the DUMP's own state, so the file references
# are read from it (psql -d <scratch>, never the live database) into $2. A failed or incomplete read leaves no $2 (or
# one without the terminator); it never fails the verification, but reconcile_pair then reports the scan as failed.
verify_dump() {
  v="aiwa_verify_$$"
  createdb "$v" || return 1
  if pg_restore --no-owner --exit-on-error -d "$v" "$1" > /dev/null 2>&1; then
    if [ -n "${2:-}" ] && [ -f "$REFERENCES_SQL" ]; then
      psql -d "$v" -v ON_ERROR_STOP=1 -tA -F '|' -f "$REFERENCES_SQL" > "$2" 2> /dev/null || rm -f "$2"
    fi
    dropdb --if-exists "$v" > /dev/null 2>&1 || true
    return 0
  fi
  dropdb --if-exists "$v" > /dev/null 2>&1 || true
  return 1
}

# R4/I-03, R5-02: reconcile the pair WHILE the backup is made. The references are the DUMP's: verify_dump reads them from
# the scratch restore of the very dump that is being archived ($refs_file), and they are checked against the file list
# of the tarball just written. The live database is never consulted (it moves on after the dump, so a file deleted from
# the volume together with its row would look clean). A failed scratch query, a missing script or an incomplete list is
# recorded as "failed", never as zero missing files. This never fails the backup (a file deleted inside the window is
# expected); it is visible in the manifest, the log and the metrics (aiwa_backup_reconcile_ok,
# aiwa_backup_missing_references; alert BackupReconcileFailed).
# Limits: the dump and the tarball are still two snapshots (docs/runbooks.md "Backup consistency"). This finds files the
# dump references that the tarball lacks; it does not detect a file replaced under the same name, a corrupt image, or a
# file that was uploaded and referenced only after the dump (an orphan in the tarball, harmless).
reconcile_status=failed; missing_refs=-1
reconcile_pair() {
  reconcile_status=failed; missing_refs=-1
  [ -f "$RECONCILE_SCRIPT" ] && [ -f "$REFERENCES_SQL" ] || { echo "$(date -u +%FT%TZ) reconciliation unavailable: scripts not mounted" >&2; return 0; }
  [ -n "${refs_file:-}" ] && [ -s "$refs_file" ] || { echo "$(date -u +%FT%TZ) RECONCILIATION FAILED: no file references could be read from the dump's scratch restore" >&2; return 0; }
  rl=$(mktemp) || return 0
  if tar -tzf "$1" > "$rl.raw" 2> /dev/null &&
     { sed 's|^\./||' "$rl.raw" | grep -v '/$' | grep -v '^$' > "$rl"; true; }; then
    if out=$(RECONCILE_FILE_LIST="$rl" sh "$RECONCILE_SCRIPT" < "$refs_file"); then
      missing_refs=$(printf '%s\n' "$out" | sed -n 's/^reconcile: [0-9]* database references checked, \([0-9]*\) missing.*/\1/p')
      if [ -n "$missing_refs" ]; then reconcile_status=ok; else missing_refs=-1; fi
      printf '%s\n' "$out" | sed "s|^|$(date -u +%FT%TZ) |"
    fi
  fi
  [ "$reconcile_status" = ok ] || echo "$(date -u +%FT%TZ) RECONCILIATION FAILED: the database references could not be checked against this backup (not a zero-missing result)" >&2
  rm -f "$rl" "$rl.raw"
  return 0
}

# R4-06: retention for the pre-restore safety copies restore.sh keeps in $OUT/safety (encrypted with the same key).
# A copy is removed after BACKUP_SAFETY_KEEP_DAYS, EXCEPT while the matching previous uploads (.restore-previous-<id> in the
# volume) still exist: that pair has not been purged, and the copy is the only way to roll the database back with it.
# Interrupted runs leave *.partial files; those are removed after two hours.
prune_safety() {
  [ -d "$OUT/safety" ] || return 0
  find "$OUT/safety" -type f -name '*.partial' -mmin +120 -delete 2> /dev/null
  find "$OUT/safety" -type f -name 'pre-restore-*' ! -name '*.partial' -mtime +"$SAFETY_KEEP_DAYS" 2> /dev/null | while IFS= read -r f; do
    rid=$(basename "$f"); rid=${rid#pre-restore-}; rid=${rid%.enc}; rid=${rid%.dump}
    if [ -e "$UPLOADS/.restore-previous-$rid" ]; then
      echo "$(date -u +%FT%TZ) safety copy $(basename "$f") kept: the previous uploads .restore-previous-$rid were not purged yet" >&2
    else
      rm -f "$f"
    fi
  done
}

# The references read from the dump's scratch restore are kept in a temp file for the run and removed on every exit path.
run_backup() {
  refs_file=$(mktemp) || refs_file=""
  do_backup
  rc=$?
  [ -z "$refs_file" ] || rm -f "$refs_file"
  return $rc
}

do_backup() {
  stamp=$(date -u +%Y%m%d-%H%M%S)
  dump="$OUT/db/aiwa-$stamp.dump"
  tarball="$OUT/uploads/uploads-$stamp.tar.gz"
  encrypted=0; ext=""
  # -f: Docker makes a directory of a bind-mounted file that does not exist; a blank key would encrypt with an empty password
  if [ -f "$KEY" ] && [ -r "$KEY" ] && [ -n "$(cat "$KEY")" ]; then
    encrypted=1; ext=".enc"
  elif [ "${BACKUP_ALLOW_UNENCRYPTED:-0}" = 1 ]; then
    echo "$(date -u +%FT%TZ) WARNING: no backup key at '${KEY:-BACKUP_KEY_FILE unset}' and BACKUP_ALLOW_UNENCRYPTED=1: this backup is NOT encrypted (docs/runbooks.md)" >&2
  else
    # S-02: an unencrypted copy of identity documents and the user table must be a deliberate choice.
    fail "no backup key at '${KEY:-BACKUP_KEY_FILE unset}': refusing to write an unencrypted backup (set BACKUP_KEY_FILE, or BACKUP_ALLOW_UNENCRYPTED=1 for a throwaway environment)"; return 1
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
  if ! verify_dump "$dump.partial" "$refs_file"; then
    rm -f "$dump.partial"; fail "the dump does not restore into a scratch database"; return 1
  fi
  if [ "$encrypted" = 1 ]; then
    encrypt "$dump.partial" "$dump$ext.partial" || { rm -f "$dump.partial" "$dump$ext.partial"; fail "cannot encrypt the dump"; return 1; }
    mv "$dump$ext.partial" "$dump$ext" || { fail "cannot rename the dump"; return 1; }
  else
    mv "$dump.partial" "$dump" || { fail "cannot rename the dump"; return 1; }
  fi

  # I-03: the dump above and this tarball are two snapshots of a live system, not one transaction. The ORDER is the
  # guarantee: the dump is taken first, so every file the dump references that still existed when tar ran is in the
  # tarball. What can differ: a file deleted between the two (the dump still points at it: "missing") and a file
  # uploaded between the two (in the tarball, not in the dump: an "orphan", harmless). restore.sh prints that
  # reconciliation after a restore (backup/reconcile_uploads.sh); docs/runbooks.md "Backup consistency". R5-02: the pair is
  # also reconciled right here, from the references of the dump's own scratch restore (reconcile_pair).
  tar_started=$(date -u +%FT%TZ)
  if ! tar -czf "$tarball.partial" -C "$UPLOADS" .; then
    rm -f "$tarball.partial"; fail "tar of uploads failed"; return 1
  fi
  tar_finished=$(date -u +%FT%TZ)
  if ! gzip -t "$tarball.partial"; then
    rm -f "$tarball.partial"; fail "uploads tarball is corrupt"; return 1
  fi
  reconcile_pair "$tarball.partial"
  if [ "$encrypted" = 1 ]; then
    encrypt "$tarball.partial" "$tarball$ext.partial" || { rm -f "$tarball.partial" "$tarball$ext.partial"; fail "cannot encrypt the uploads tarball"; return 1; }
    mv "$tarball$ext.partial" "$tarball$ext" || { fail "cannot rename the uploads tarball"; return 1; }
  else
    mv "$tarball.partial" "$tarball" || { fail "cannot rename the uploads tarball"; return 1; }
  fi

  # I-03: a small record of what the pair is: when each half was taken and how many files the tarball holds.
  mkdir -p "$OUT/manifest" && printf '{"stamp":"%s","dump":"aiwa-%s.dump%s","uploads":"uploads-%s.tar.gz%s","dump_taken_before":"%s","tar_started":"%s","tar_finished":"%s","reconcile":"%s","missing_references":%s,"consistency":"dump-first: see docs/runbooks.md"}
'     "$stamp" "$stamp" "$ext" "$stamp" "$ext" "$tar_started" "$tar_started" "$tar_finished" "$reconcile_status" "$missing_refs" > "$OUT/manifest/snapshot-$stamp.json" ||
    echo "$(date -u +%FT%TZ) cannot write the backup manifest" >&2
  find "$OUT/manifest" -type f -mtime +"$KEEP_DAYS" -delete 2> /dev/null
  find "$OUT/db" "$OUT/uploads" -type f -mtime +"$KEEP_DAYS" -delete
  find "$OUT/db" "$OUT/uploads" -type f -name '*.partial' -mmin +120 -delete
  prune_safety
  date -u +%FT%TZ > "$OUT/last-success"
  printf '# TYPE aiwa_backup_last_success_timestamp_seconds gauge
aiwa_backup_last_success_timestamp_seconds %s
# TYPE aiwa_backup_encrypted gauge
aiwa_backup_encrypted %s
# TYPE aiwa_backup_reconcile_ok gauge
aiwa_backup_reconcile_ok %s
# TYPE aiwa_backup_missing_references gauge
aiwa_backup_missing_references %s
'     "$(date -u +%s)" "$encrypted" "$([ "$reconcile_status" = ok ] && echo 1 || echo 0)" "$missing_refs" > "$OUT/metrics/metrics.txt.new" && mv "$OUT/metrics/metrics.txt.new" "$OUT/metrics/metrics.txt" ||
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
