#!/usr/bin/env bash
# Restore a backup made by backup/backup.sh (OPS-2). REPLACES the live database
# and uploads, so it asks first. Run from deploy/ on the server:
#
#   ./restore.sh backups/db/aiwa-YYYYMMDD-HHMMSS.dump [backups/uploads/uploads-YYYYMMDD-HHMMSS.tar.gz]
#
# CR-20: files ending in .enc were encrypted by backup.sh; they need the key file
# (BACKUP_KEY_FILE, default secrets/backup.key) and openssl on this machine.
set -euo pipefail
cd "$(dirname "$0")"

dump="${1:?usage: ./restore.sh <db dump> [uploads tarball]}"
uploads="${2:-}"
[ -f "$dump" ] || { echo "no such dump: $dump" >&2; exit 1; }
[ -z "$uploads" ] || [ -f "$uploads" ] || { echo "no such tarball: $uploads" >&2; exit 1; }

key="${BACKUP_KEY_FILE:-secrets/backup.key}"
case "$dump$uploads" in *.enc*) [ -s "$key" ] || { echo "encrypted backup: key file $key not found (set BACKUP_KEY_FILE)" >&2; exit 1; } ;; esac
# Same cipher settings as backup/backup.sh. Prints the plain bytes of a backup file.
plain() {
  case "$1" in
    *.enc) BACKUP_PASS=$(cat "$key") openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass env:BACKUP_PASS < "$1" ;;
    *) cat "$1" ;;
  esac
}

compose=(docker compose -f docker-compose.prod.yml)
echo "This replaces the live database${uploads:+ and uploads} with:"
echo "  $dump"; [ -n "$uploads" ] && echo "  $uploads"
if [ "${ASSUME_YES:-}" != "1" ]; then
  read -r -p "Type RESTORE to continue: " answer
  [ "$answer" = "RESTORE" ] || { echo "cancelled"; exit 1; }
fi

# Keep the app from writing while the data is swapped.
"${compose[@]}" stop backend

"${compose[@]}" exec -T postgres sh -c 'pg_restore --clean --if-exists --no-owner -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < <(plain "$dump")

if [ -n "$uploads" ]; then
  "${compose[@]}" run --rm -T --entrypoint sh backup -c 'find /uploads -mindepth 1 -delete && tar -xzf - -C /uploads' < <(plain "$uploads")
fi

"${compose[@]}" start backend
echo "restored; check https://\$API_DOMAIN/api/actuator/health"
