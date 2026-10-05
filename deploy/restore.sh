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
die() { echo "$*; nothing was changed" >&2; exit 1; }

# Decrypt and check every input BEFORE anything is stopped, dropped or deleted: a wrong key,
# a missing openssl or a corrupt file must leave the live database and uploads untouched.
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
plain "$dump" > "$tmp/db.dump" || die "cannot read $dump (wrong key?)"
[ -s "$tmp/db.dump" ] || die "$dump is empty"
"${compose[@]}" exec -T postgres pg_restore --list < "$tmp/db.dump" > /dev/null || die "$dump is not a readable dump (wrong key?)"
# SA-04: --list only reads the table of contents, so a dump with an intact contents page and a
# truncated payload passes it, and the restore below would then wipe the live data and fail halfway.
# Restore into a disposable database first: if that does not complete, nothing live is touched.
scratch="restore_check_$$"
pg() { "${compose[@]}" exec -T postgres sh -c "$1" _ "$scratch"; } # $1 sees the scratch name as "$1"
pg 'createdb -U "$POSTGRES_USER" "$1"' < /dev/null || die "cannot create a scratch database to test the restore"
if ! pg 'pg_restore --no-owner --exit-on-error -U "$POSTGRES_USER" -d "$1"' < "$tmp/db.dump" > /dev/null 2> "$tmp/check.err"; then
  pg 'dropdb -U "$POSTGRES_USER" --if-exists "$1"' < /dev/null > /dev/null 2>&1 || true
  die "$dump does not restore completely (truncated or damaged): $(tail -n 2 "$tmp/check.err" | tr -s "[:space:]" " ")"
fi
pg 'dropdb -U "$POSTGRES_USER" --if-exists "$1"' < /dev/null > /dev/null 2>&1 || echo "note: scratch database $scratch was not dropped; drop it by hand" >&2
if [ -n "$uploads" ]; then
  plain "$uploads" > "$tmp/uploads.tgz" || die "cannot read $uploads (wrong key?)"
  tar -tzf "$tmp/uploads.tgz" > /dev/null || die "$uploads is not a readable tarball (wrong key?)"
fi

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

# A copy of the live database taken now, so that if the files cannot be swapped after the database was restored
# the database can be put back too: the pair is rolled back together. Kept next to the other backups.
safety="backups/pre-restore-$restore_id.dump"
mkdir -p backups
if ! "${compose[@]}" exec -T postgres sh -c 'pg_dump -Fc -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$safety.partial" || [ ! -s "$safety.partial" ]; then
  rm -f "$safety.partial"
  [ -z "$uploads" ] || swap discard "$restore_id" < /dev/null > /dev/null 2>&1 || true
  "${compose[@]}" start backend
  die "could not take a safety copy of the live database; the backend is running again"
fi
mv "$safety.partial" "$safety"

# One transaction that stops at the first error: if anything still goes wrong, the live database is
# rolled back to how it was instead of being left half-restored.
if ! "${compose[@]}" exec -T postgres sh -c 'pg_restore --clean --if-exists --no-owner --single-transaction --exit-on-error -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < "$tmp/db.dump"; then
  [ -z "$uploads" ] || swap discard "$restore_id" < /dev/null > /dev/null 2>&1 || true
  "${compose[@]}" start backend
  die "the restore failed and was rolled back; the live database is as it was and the backend is running again"
fi

if [ -n "$uploads" ]; then
  if ! swap swap "$restore_id" < /dev/null; then
    # The swap put the old files back by itself. The database is already the restored one, so restore the safety
    # copy as well: database and files are then both as they were before this run.
    echo "the uploads could not be swapped in; putting the database back as it was" >&2
    if "${compose[@]}" exec -T postgres sh -c 'pg_restore --clean --if-exists --no-owner --single-transaction --exit-on-error -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < "$safety"; then
      "${compose[@]}" start backend
      die "the uploads could not be swapped in; database and uploads are both back as they were and the backend is running again"
    fi
    # Cannot happen unless the database is unreachable: stay stopped, with everything needed for a manual fix.
    die "the uploads could not be swapped in AND the database could not be put back. The backend stays STOPPED. Previous database: $safety (pg_restore it); previous uploads are intact in the volume"
  fi
fi

"${compose[@]}" start backend
# The reconciliation report: every file the restored database points at should exist in the restored uploads.
# Missing ones are listed (a dump and an uploads tarball are two snapshots, see docs/runbooks.md), never fatal.
if [ -n "$uploads" ] && [ -f backup/reconcile_uploads.sh ]; then
  "${compose[@]}" exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -F "|" -f -' < backup/uploads_references.sql > "$tmp/refs.txt" 2> /dev/null || echo "note: could not read the file references from the database" >&2
  "${compose[@]}" run --rm -T --entrypoint sh backup /reconcile_uploads.sh < "$tmp/refs.txt" || true
fi
echo "restored; check https://\$API_DOMAIN/api/actuator/health"
if [ -n "$uploads" ]; then
  echo "Previous uploads kept in the volume as .restore-previous-$restore_id and the previous database in $safety."
  echo "After you have checked the app, free the space:  docker compose -f docker-compose.prod.yml run --rm -T --entrypoint sh backup /uploads_swap.sh purge $restore_id"
  echo "To undo the whole restore instead:  restore.sh $safety   and   uploads_swap.sh rollback $restore_id"
fi
