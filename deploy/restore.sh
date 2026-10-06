#!/usr/bin/env bash
# Restore a backup made by backup/backup.sh (OPS-2). REPLACES the live database
# and uploads, so it asks first. Run from deploy/ on the server:
#
#   ./restore.sh backups/db/aiwa-YYYYMMDD-HHMMSS.dump [backups/uploads/uploads-YYYYMMDD-HHMMSS.tar.gz]
#
# CR-20: files ending in .enc were encrypted by backup.sh; they need the key file
# (BACKUP_KEY_FILE, default secrets/backup.key) and openssl on this machine.
#
# CR-20: the decrypted dump and uploads tarball are written as plaintext to a temporary
# directory (mode 700, files 600: umask 077 below) and removed on exit. They need room for
# both files: set TMPDIR to a directory on the restore volume (e.g. TMPDIR=/srv/aiwa-restore)
# when /tmp is small or is not on the encrypted disk. Delete it if the script is ever killed
# with SIGKILL (the exit trap cannot run then).
#
# R4-06: before anything is replaced a SAFETY COPY of the live database is taken so the pair (database, uploads) can be
# rolled back together. It follows the normal backup policy: verified (restored into a scratch database), encrypted
# with the backup key and verified again (BACKUP_ALLOW_UNENCRYPTED=1 only for throwaway environments), mode 600 in
# backups/safety/, covered by the backup container's retention (BACKUP_SAFETY_KEEP_DAYS, kept while the matching
# .restore-previous-<id> uploads still exist), and the free disk space is checked first.
#
# R4-01: the backend is started again ONLY when the database and the uploads are known to be consistent: either the
# restore completed, or both were verifiably rolled back. If the uploads rollback cannot be proven, or the database cannot be
# put back, the backend stays STOPPED and the message says what is where.
set -euo pipefail
umask 077 # everything created below (temp dir, plaintext dump and tarball) is private to this user
cd "$(dirname "$0")"

dump="${1:?usage: ./restore.sh <db dump> [uploads tarball]}"
uploads="${2:-}"
[ -f "$dump" ] || { echo "no such dump: $dump" >&2; exit 1; }
[ -z "$uploads" ] || [ -f "$uploads" ] || { echo "no such tarball: $uploads" >&2; exit 1; }

key="${BACKUP_KEY_FILE:-secrets/backup.key}"
openssl_bin="${OPENSSL_BIN:-openssl}"
case "$dump$uploads" in
  *.enc*)
    [ -f "$key" ] && [ -n "$(cat "$key")" ] || { echo "encrypted backup: key file $key not found or empty (set BACKUP_KEY_FILE)" >&2; exit 1; }
    command -v "$openssl_bin" > /dev/null || { echo "encrypted backup: openssl is not installed on this machine" >&2; exit 1; } ;;
esac
# Same cipher settings as backup/backup.sh. Prints the plain bytes of a backup file.
plain() {
  case "$1" in
    *.enc) BACKUP_PASS=$(cat "$key") "$openssl_bin" enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass env:BACKUP_PASS < "$1" ;;
    *) cat "$1" ;;
  esac
}

compose=(docker compose -f docker-compose.prod.yml)
backend_stopped=0
safety_final=""
tmp=""
# The exit trap: remove the plaintext temp dir and any half-written safety copy, and never let the operator miss
# that the backend was left stopped (a failed command under "set -e" can end the script anywhere after the stop).
cleanup() {
  rc=$?
  [ -z "$tmp" ] || rm -rf "$tmp"
  [ -z "$safety_final" ] || rm -f "$safety_final.partial"
  if [ "$backend_stopped" = 1 ]; then
    echo "NOTE: the backend is STOPPED. Do not start it until the database and uploads are known to be consistent (see above and docs/runbooks.md \"Restoring\")." >&2
  fi
  exit "$rc"
}
trap cleanup EXIT
die() { echo "$*; nothing was changed" >&2; exit 1; }

# R4-06: decide how the safety copy is protected BEFORE anything is touched.
safety_enc=0
if [ -f "$key" ] && [ -n "$(cat "$key")" ] && command -v "$openssl_bin" > /dev/null; then
  safety_enc=1
elif [ "${BACKUP_ALLOW_UNENCRYPTED:-0}" = 1 ]; then
  echo "WARNING: no backup key at '$key' and BACKUP_ALLOW_UNENCRYPTED=1: the safety copy of the live database will NOT be encrypted" >&2
else
  die "no backup key at '$key' (or no openssl): refusing to keep an unencrypted safety copy of the live database (set BACKUP_KEY_FILE, or BACKUP_ALLOW_UNENCRYPTED=1 for a throwaway environment)"
fi

# Decrypt and check every input BEFORE anything is stopped, dropped or deleted: a wrong key,
# a missing openssl or a corrupt file must leave the live database and uploads untouched.
tmp=$(mktemp -d)
plain "$dump" > "$tmp/db.dump" || die "cannot read $dump (wrong key?)"
[ -s "$tmp/db.dump" ] || die "$dump is empty"
"${compose[@]}" exec -T postgres pg_restore --list < "$tmp/db.dump" > /dev/null || die "$dump is not a readable dump (wrong key?)"
# SA-04: --list only reads the table of contents, so a dump with an intact contents page and a
# truncated payload passes it, and the restore below would then wipe the live data and fail halfway.
# Restore into a disposable database first: if that does not complete, nothing live is touched.
# scratch_restore <dump file> <label>: 0 when the whole file restores into a throwaway database.
scratch_restore() {
  local scratch="restore_check_$$_$2"
  pg() { "${compose[@]}" exec -T postgres sh -c "$1" _ "$scratch"; } # $1 sees the scratch name as "$1"
  pg 'createdb -U "$POSTGRES_USER" "$1"' < /dev/null || { SCRATCH_ERR="cannot create a scratch database"; return 1; }
  if ! pg 'pg_restore --no-owner --exit-on-error -U "$POSTGRES_USER" -d "$1"' < "$1" > /dev/null 2> "$tmp/check.err"; then
    pg 'dropdb -U "$POSTGRES_USER" --if-exists "$1"' < /dev/null > /dev/null 2>&1 || true
    SCRATCH_ERR="$(tail -n 2 "$tmp/check.err" | tr -s "[:space:]" " ")"
    return 1
  fi
  pg 'dropdb -U "$POSTGRES_USER" --if-exists "$1"' < /dev/null > /dev/null 2>&1 || echo "note: scratch database $scratch was not dropped; drop it by hand" >&2
  return 0
}
SCRATCH_ERR=""
scratch_restore "$tmp/db.dump" input || die "$dump does not restore completely (truncated or damaged): $SCRATCH_ERR"
if [ -n "$uploads" ]; then
  plain "$uploads" > "$tmp/uploads.tgz" || die "cannot read $uploads (wrong key?)"
  tar -tzf "$tmp/uploads.tgz" > /dev/null || die "$uploads is not a readable tarball (wrong key?)"
fi

# R4-06: disk capacity. The safety copy needs room twice: the plaintext in the private temp dir while it is verified
# and encrypted, and the final file in backups/safety. Free space is checked against the live database size.
free_kb() { df -Pk "$1" | awk 'NR==2 { print $4 }'; }
fs_of() { df -Pk "$1" | awk 'NR==2 { print $1 }'; }
mkdir -p backups/safety
chmod 700 backups/safety 2> /dev/null || true
db_bytes=$("${compose[@]}" exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -c "SELECT pg_database_size(current_database())"' < /dev/null | tr -d '[:space:]') || db_bytes=""
case "$db_bytes" in ''|*[!0-9]*) die "cannot read the size of the live database to budget the safety copy" ;; esac
need_kb=$(( (db_bytes + db_bytes / 10 + 16777216) / 1024 + 1 ))
if [ "$(fs_of "$tmp")" = "$(fs_of backups/safety)" ]; then need_each=$((need_kb * 2)); else need_each=$need_kb; fi
[ "$(free_kb "$tmp")" -ge "$need_each" ] || die "not enough free space for the safety copy in $(dirname "$tmp") (need about $((need_each / 1024)) MiB; set TMPDIR to a bigger directory)"
[ "$(free_kb backups/safety)" -ge "$need_each" ] || die "not enough free space in backups/safety for the safety copy (need about $((need_each / 1024)) MiB; free space or purge old safety copies)"

# I-02: the uploads tarball is EXTRACTED AND VERIFIED INSIDE THE VOLUME BEFORE anything live is touched, and
# the swap is a set of atomic renames that keeps the previous files (backup/uploads_swap.sh), so a full disk or a
# failed extraction can no longer leave the database replaced and the files gone.
restore_id=$(date -u +%Y%m%d-%H%M%S)-$$
swap() { "${compose[@]}" run --rm -T --entrypoint sh backup /uploads_swap.sh "$@"; }
if [ -n "$uploads" ]; then
  swap preflight < "$tmp/uploads.tgz" || die "the uploads volume cannot hold a staged copy of $uploads"
  swap stage "$restore_id" < "$tmp/uploads.tgz" || { swap discard "$restore_id" < /dev/null > /dev/null 2>&1 || true; die "the uploads could not be extracted (disk full or damaged archive)"; }
fi

echo "This replaces the live database${uploads:+ and uploads} with:"
echo "  $dump"; [ -n "$uploads" ] && echo "  $uploads"
if [ "${ASSUME_YES:-}" != "1" ]; then
  read -r -p "Type RESTORE to continue: " answer
  [ "$answer" = "RESTORE" ] || { [ -z "$uploads" ] || swap discard "$restore_id" < /dev/null > /dev/null 2>&1 || true; echo "cancelled"; exit 1; }
fi

# Keep the app from writing while the data is swapped.
"${compose[@]}" stop backend
backend_stopped=1

# A copy of the live database taken now, so that if the files cannot be swapped after the database was restored
# the database can be put back too: the pair is rolled back together (R4-06: verified, encrypted, 600, in backups/safety).
safety_final="backups/safety/pre-restore-$restore_id.dump"
[ "$safety_enc" = 1 ] && safety_final="$safety_final.enc"
abort_with_backend() { # the safety copy could not be made: nothing was changed, so the backend can run again
  rm -f "$safety_final.partial"
  [ -z "$uploads" ] || swap discard "$restore_id" < /dev/null > /dev/null 2>&1 || true
  "${compose[@]}" start backend
  backend_stopped=0
  die "$1; the backend is running again"
}
if ! "${compose[@]}" exec -T postgres sh -c 'pg_dump -Fc -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$tmp/safety.dump" || [ ! -s "$tmp/safety.dump" ]; then
  abort_with_backend "could not take a safety copy of the live database"
fi
"${compose[@]}" exec -T postgres pg_restore --list < "$tmp/safety.dump" > /dev/null || abort_with_backend "the safety copy is not readable"
scratch_restore "$tmp/safety.dump" safety || abort_with_backend "the safety copy does not restore into a scratch database ($SCRATCH_ERR)"
if [ "$safety_enc" = 1 ]; then
  BACKUP_PASS=$(cat "$key") "$openssl_bin" enc -aes-256-cbc -pbkdf2 -iter 200000 -pass env:BACKUP_PASS < "$tmp/safety.dump" > "$safety_final.partial" || abort_with_backend "could not encrypt the safety copy"
  BACKUP_PASS=$(cat "$key") "$openssl_bin" enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass env:BACKUP_PASS < "$safety_final.partial" | cmp -s - "$tmp/safety.dump" || abort_with_backend "the encrypted safety copy does not decrypt back to the dump"
else
  cp "$tmp/safety.dump" "$safety_final.partial" || abort_with_backend "could not write the safety copy"
fi
chmod 600 "$safety_final.partial"
mv "$safety_final.partial" "$safety_final" || abort_with_backend "could not store the safety copy"
safety="$safety_final"

# put_db_back: restore the safety copy (the plaintext verified above, still in the private temp dir).
put_db_back() {
  "${compose[@]}" exec -T postgres sh -c 'pg_restore --clean --if-exists --no-owner --single-transaction --exit-on-error -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < "$tmp/safety.dump"
}

# One transaction that stops at the first error: if anything still goes wrong, the live database is
# rolled back to how it was instead of being left half-restored.
if ! "${compose[@]}" exec -T postgres sh -c 'pg_restore --clean --if-exists --no-owner --single-transaction --exit-on-error -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < "$tmp/db.dump"; then
  [ -z "$uploads" ] || swap discard "$restore_id" < /dev/null > /dev/null 2>&1 || true
  "${compose[@]}" start backend
  backend_stopped=0
  die "the restore failed and was rolled back; the live database is as it was and the backend is running again"
fi

if [ -n "$uploads" ]; then
  swap_rc=0
  swap swap "$restore_id" < /dev/null || swap_rc=$?
  if [ "$swap_rc" -ne 0 ]; then
    if [ "$swap_rc" -ne 1 ]; then
      # Exit 3 (or anything unexpected): the uploads rollback could NOT be proven. The files are in a mixed state, so no
      # database state is consistent with them. Do not touch the database; do not start the backend.
      echo "the uploads swap failed AND its rollback could not be verified (exit $swap_rc). The backend stays STOPPED." >&2
      echo "  The database is the RESTORED one; the previous database is in $safety (restore.sh $safety puts it back)." >&2
      echo "  The uploads recovery journal and the previous files are kept in the volume (.restore-previous-$restore_id, .restore-journal-$restore_id)." >&2
      echo "  Fix the cause, then: docker compose -f docker-compose.prod.yml run --rm -T --entrypoint sh backup /uploads_swap.sh rollback $restore_id  (repeat until it succeeds), then restore.sh $safety" >&2
      exit 1
    fi
    # Exit 1: the swap put the old files back and verified it. The database is already the restored one, so restore the
    # safety copy as well: database and files are then both as they were before this run.
    echo "the uploads could not be swapped in; putting the database back as it was" >&2
    if put_db_back; then
      "${compose[@]}" start backend
      backend_stopped=0
      die "the uploads could not be swapped in; database and uploads are both back as they were and the backend is running again"
    fi
    # Cannot happen unless the database is unreachable: stay stopped, with everything needed for a manual fix.
    die "the uploads could not be swapped in AND the database could not be put back. The backend stays STOPPED. Previous database: $safety (restore.sh it); previous uploads are intact in the volume"
  fi
fi

"${compose[@]}" start backend
backend_stopped=0
# The reconciliation report: every file the restored database points at should exist in the restored uploads.
# Missing ones are listed (a dump and an uploads tarball are two snapshots, see docs/runbooks.md), never fatal.
# R4: a failed reference query or an incomplete list is reported as a FAILED scan, never as "0 missing".
reconcile="not applicable (no uploads restored)"
if [ -n "$uploads" ] && [ -f backup/reconcile_uploads.sh ]; then
  if "${compose[@]}" exec -T postgres sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -F "|" -f -' < backup/uploads_references.sql > "$tmp/refs.txt" 2> "$tmp/refs.err"; then
    if "${compose[@]}" run --rm -T --entrypoint sh backup /reconcile_uploads.sh < "$tmp/refs.txt"; then
      reconcile="completed"
    else
      reconcile="FAILED (the reference list was incomplete)"
    fi
  else
    reconcile="FAILED (the file references could not be read from the database: $(tail -n 1 "$tmp/refs.err" | tr -s '[:space:]' ' '))"
  fi
  case "$reconcile" in
    FAILED*) echo "RECONCILIATION NOT PERFORMED: ${reconcile#FAILED }. This is NOT a zero-missing result: check the restored files by hand before relying on them." >&2 ;;
  esac
fi
echo "restored; reconciliation: $reconcile; check https://\$API_DOMAIN/api/actuator/health"
if [ -n "$uploads" ]; then
  echo "Previous uploads kept in the volume as .restore-previous-$restore_id and the previous database in $safety (encrypted: $([ "$safety_enc" = 1 ] && echo yes || echo NO))."
  echo "After you have checked the app, free the space:  docker compose -f docker-compose.prod.yml run --rm -T --entrypoint sh backup /uploads_swap.sh purge $restore_id  &&  rm -f backups/safety/pre-restore-$restore_id.dump*"
  echo "To undo the whole restore instead:  restore.sh $safety   and   uploads_swap.sh rollback $restore_id"
else
  echo "The previous database is in $safety (encrypted: $([ "$safety_enc" = 1 ] && echo yes || echo NO)); it is removed by the backup retention (BACKUP_SAFETY_KEEP_DAYS) or by hand."
fi
