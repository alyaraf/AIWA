#!/usr/bin/env bash
# Failure-injection test for the ORDER of restore.sh (audit I-02), with a fake docker (no containers needed):
#   bash deploy/restore_flow_test.sh
# The fake runs the real backup/uploads_swap.sh and backup/reconcile_uploads.sh against a temporary "volume", and
# records every call. It proves what restore.sh does when the extraction, the database restore or the swap fails:
# the live files and database are never left replaced-and-gone, and the backend is restarted (or deliberately kept
# stopped with instructions when nothing can be put back).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
pass=0; failed=0
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else failed=$((failed+1)); echo "FAIL $1"; fi; }
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

# --- the fake docker --------------------------------------------------------------------------------------------
mkdir -p "$work/bin"
cat > "$work/bin/docker" <<'FAKE'
#!/bin/sh
# docker compose -f <file> <verb> ...
[ "$1" = compose ] || exit 1
shift; shift; shift   # compose -f file
verb="$1"; shift
echo "$verb $*" >> "$FAKE_LOG"
case "$verb" in
  stop|start) exit 0 ;;
  exec)
    # exec -T postgres <cmd...>
    shift; shift
    if [ "$1" = pg_restore ]; then cat > /dev/null; exit 0; fi   # --list
    script="$*"
    case "$script" in
      *pg_database_size*) cat > /dev/null; echo "${FAKE_DB_SIZE:-1000}"; exit 0 ;;
      *"pg_dump -Fc"*) [ -n "${FAKE_NO_SAFETY:-}" ] && exit 1; echo "SAFETY-DUMP-OF-LIVE"; exit 0 ;;
      *"pg_restore --clean"*)
        cat > "$FAKE_STATE/restore-input"
        n=$(($(cat "$FAKE_STATE/restores" 2> /dev/null || echo 0) + 1)); echo "$n" > "$FAKE_STATE/restores"
        echo "db-restore #$n input=$(head -c 20 "$FAKE_STATE/restore-input" | tr -d '\n')" >> "$FAKE_LOG"
        [ -n "${FAKE_DB_RESTORE_FAILS:-}" ] && [ "$n" = "$FAKE_DB_RESTORE_FAILS" ] && exit 1
        [ -n "${FAKE_DB_RESTORE_FAILS_FROM:-}" ] && [ "$n" -ge "$FAKE_DB_RESTORE_FAILS_FROM" ] && exit 1
        exit 0 ;;
      *"pg_restore --no-owner"*) cat > /dev/null; exit 0 ;;   # scratch restore
      *psql*) cat > /dev/null
              [ -n "${FAKE_REFS_FAIL:-}" ] && { echo "psql: connection refused" >&2; exit 2; }
              [ -n "${FAKE_REFS_TRUNCATED:-}" ] && { printf 'public|/files/public/avatars/n1.jpg\n'; exit 0; }
              printf 'public|/files/public/avatars/n1.jpg\npublic|/files/public/avatars/gone.jpg\ndone|ok\n'; exit 0 ;;
      *) cat > /dev/null; exit 0 ;;                           # createdb / dropdb
    esac ;;
  run)
    # run --rm -T --entrypoint sh backup /script args...
    while [ "$1" != backup ]; do shift; done; shift
    script="$1"; shift
    if [ "$1" = stage ] && [ -n "${FAKE_STAGE_FAILS:-}" ]; then cat > /dev/null; exit 1; fi
    case "$script" in
      /uploads_swap.sh) UPLOADS_DIR="$FAKE_VOLUME" UPLOADS_SWAP_FAIL_AFTER="${FAKE_SWAP_FAIL_AFTER:-}" UPLOADS_ROLLBACK_FAIL_AFTER="${FAKE_ROLLBACK_FAIL_AFTER:-}" sh "$FAKE_DEPLOY/backup/uploads_swap.sh" "$@" ;;
      /reconcile_uploads.sh) UPLOADS_DIR="$FAKE_VOLUME" sh "$FAKE_DEPLOY/backup/reconcile_uploads.sh" ;;
    esac ;;
esac
FAKE
chmod +x "$work/bin/docker"

# --- a disposable deploy directory and volume ------------------------------------------------------------------
new_case() {
  c="$work/$1"; shift
  mkdir -p "$c/deploy/backup" "$c/state" "$c/volume/public/avatars" "$c/volume/private/docs"
  cp "$here/restore.sh" "$c/deploy/"
  cp "$here/backup/uploads_swap.sh" "$here/backup/reconcile_uploads.sh" "$here/backup/uploads_references.sql" "$c/deploy/backup/"
  : > "$c/deploy/docker-compose.prod.yml"
  echo "old avatar" > "$c/volume/public/avatars/a1.jpg"
  echo "old id" > "$c/volume/private/docs/id1.png"
  mkdir -p "$c/src/public/avatars"; echo "new avatar" > "$c/src/public/avatars/n1.jpg"
  tar -czf "$c/uploads.tgz" -C "$c/src" .
  echo "DUMPDATA" > "$c/db.dump"
  : > "$c/log"
}
volume_sum() { ( cd "$1" && find . -path './.restore-*' -prune -o -type f -print | sort | xargs cksum ); }
# restore <case> [VAR=value ...]
restore() {
  c="$work/$1"; shift
  ( cd "$c/deploy" && env PATH="$work/bin:$PATH" FAKE_LOG="$c/log" FAKE_STATE="$c/state" FAKE_VOLUME="$c/volume" \
      FAKE_DEPLOY="$c/deploy" ASSUME_YES=1 BACKUP_ALLOW_UNENCRYPTED=1 "$@" bash ./restore.sh "$c/db.dump" "$c/uploads.tgz" ) > "$c/out" 2>&1
  rc=$?
}
called() { grep -q "$2" "$work/$1/log"; }
line_of() { grep -n "$2" "$work/$1/log" | head -1 | cut -d: -f1; }

# --- A: everything works -----------------------------------------------------------------------------------------
new_case A; restore A
check "A: a good restore succeeds" '[ $rc -eq 0 ]'
check "A: the live volume holds the restored files" '[ -f "$work/A/volume/public/avatars/n1.jpg" ] && [ ! -e "$work/A/volume/public/avatars/a1.jpg" ]'
check "A: the previous files are retained until purged" '[ -f "$work/A/volume/".restore-previous-*/public/avatars/a1.jpg ]'
check "A: a safety copy of the live database was taken before the restore" 'ls "$work/A/deploy/backups/safety"/pre-restore-*.dump > /dev/null 2>&1'
check "A: staging happened BEFORE the backend was stopped" '[ "$(line_of A "stage ")" -lt "$(line_of A "^stop ")" ]'
check "A: the backend is started again at the end" 'called A "^start backend"'
check "A: the reconciliation report names the missing file" 'grep -q "MISSING public /files/public/avatars/gone.jpg" "$work/A/out" && grep -q "1 missing" "$work/A/out"'

# --- B: the extraction fails (disk full, damaged) ------------------------------------------------------------------
new_case B; before=$(volume_sum "$work/B/volume"); restore B FAKE_STAGE_FAILS=1
check "B: a failed extraction fails the restore" '[ $rc -ne 0 ]'
check "B: the live files are untouched" '[ "$(volume_sum "$work/B/volume")" = "$before" ]'
check "B: the backend was never stopped and the database never restored" '! called B "^stop " && ! called B "db-restore"'

# --- C: the database restore fails ------------------------------------------------------------------------------------
new_case C; before=$(volume_sum "$work/C/volume"); restore C FAKE_DB_RESTORE_FAILS=1
check "C: a failed database restore fails the run" '[ $rc -ne 0 ]'
check "C: the live files are untouched and the backend runs again" '[ "$(volume_sum "$work/C/volume")" = "$before" ] && called C "^start backend"'
check "C: the staged copy was discarded" '[ -z "$(ls -A "$work/C/volume" | grep "^.restore-staging")" ]'

# --- D: the swap fails after the database was restored: both are rolled back ----------------------------------------
new_case D; before=$(volume_sum "$work/D/volume"); restore D FAKE_SWAP_FAIL_AFTER=1
check "D: a failed swap fails the run" '[ $rc -ne 0 ]'
check "D: the live files are exactly as before" '[ "$(volume_sum "$work/D/volume")" = "$before" ]'
check "D: the database was put back from the safety copy (second restore, fed the safety dump)" 'called D "db-restore #2 input=SAFETY-DUMP-OF-LIVE"'
check "D: the backend is running again" 'called D "^start backend"'
check "D: the output says both are back" 'grep -q "back as they were" "$work/D/out"'

# --- E: the swap fails AND the database cannot be put back ----------------------------------------------------------
new_case E; restore E FAKE_SWAP_FAIL_AFTER=1 FAKE_DB_RESTORE_FAILS_FROM=2
check "E: the run fails" '[ $rc -ne 0 ]'
check "E: the backend stays stopped, deliberately" '! called E "^start backend"'
check "E: the message names the safety dump and says the old uploads are intact" 'grep -q "STOPPED" "$work/E/out" && grep -q "pre-restore-" "$work/E/out" && grep -q "intact" "$work/E/out"'
check "E: the live files are the old ones" '[ -f "$work/E/volume/public/avatars/a1.jpg" ]'

# --- F: no safety copy can be taken ------------------------------------------------------------------------------------------
new_case F; before=$(volume_sum "$work/F/volume"); restore F FAKE_NO_SAFETY=1
check "F: without a safety copy nothing is restored" '[ $rc -ne 0 ] && ! called F "db-restore" && [ "$(volume_sum "$work/F/volume")" = "$before" ] && called F "^start backend"'

check "F: no safety artifacts are left behind" '[ -z "$(ls -A "$work/F/deploy/backups/safety" 2> /dev/null)" ]'

# --- G (R4-01): the files rollback ITSELF fails (real rename errors both ways) -----------------------------------------
cat > "$work/bin/mv" <<'MV'
#!/bin/sh
if [ -n "${MV_FAIL:-}" ]; then
  case "$1" in
    */.restore-staging-*/public|*/.restore-previous-*/public) echo 'simulated OS rename failure' >&2; exit 1;;
  esac
fi
exec /usr/bin/mv "$@"
MV
chmod +x "$work/bin/mv"
new_case G; restore G MV_FAIL=1
check "G: restore fails" '[ $rc -ne 0 ]'
check "G: the backend is NOT started when the files rollback could not be verified" '! called G "^start backend"'
check "G: the database is not touched again (no second restore) while the files are in a mixed state" '! called G "db-restore #2"'
check "G: the output says the backend stays STOPPED and names the journal and the rollback command" 'grep -q "STOPPED" "$work/G/out" && grep -q "restore-journal-" "$work/G/out" && grep -q "uploads_swap.sh rollback" "$work/G/out"'
check "G: the recovery journal and the previous files are retained" 'ls "$work/G/volume/".restore-journal-* > /dev/null 2>&1 && ls "$work/G/volume/".restore-previous-*/public/avatars/a1.jpg > /dev/null 2>&1'
check "G: it never claims that database and uploads are back" '! grep -q "both back" "$work/G/out"'
# ...and the operator can finish the recovery once the cause is gone
gid=$(ls "$work/G/volume" | sed -n 's/^\.restore-journal-//p' | head -1); [ -n "$gid" ] || gid=$(ls -A "$work/G/volume" | sed -n 's/^\.restore-journal-//p' | head -1)
( cd "$work/G/deploy" && PATH="$work/bin:$PATH" UPLOADS_DIR="$work/G/volume" sh ./backup/uploads_swap.sh rollback "$gid" > /dev/null 2>&1 ); grc=$?
check "G: with the cause gone, the rollback command completes and the old files are back" '[ $grc -eq 0 ] && [ -f "$work/G/volume/public/avatars/a1.jpg" ]'

# --- O (R4-01): forward move fails, then the rollback hook fails ------------------------------------------------------
new_case O; restore O FAKE_SWAP_FAIL_AFTER=1 FAKE_ROLLBACK_FAIL_AFTER=0
check "O: the run fails and the backend stays stopped" '[ $rc -ne 0 ] && ! called O "^start backend" && grep -q "STOPPED" "$work/O/out"'
check "O: the previous files stay recoverable" 'ls "$work/O/volume/".restore-previous-* > /dev/null 2>&1 && ls "$work/O/volume/".restore-journal-* > /dev/null 2>&1'

# --- H (R4-06): the safety copy is encrypted, verified and kept in backups/safety --------------------------------------
new_case H; printf 'a long test secret\n' > "$work/H/key"
restore H BACKUP_KEY_FILE="$work/H/key" BACKUP_ALLOW_UNENCRYPTED=0
check "H: a restore with a backup key succeeds" '[ $rc -eq 0 ]'
check "H: the safety copy is encrypted: only a .enc file exists in backups/safety" 'ls "$work/H/deploy/backups/safety"/pre-restore-*.dump.enc > /dev/null 2>&1 && ! ls "$work/H/deploy/backups/safety"/pre-restore-*.dump > /dev/null 2>&1'
check "H: the safety copy holds no readable plaintext" '! grep -q "SAFETY-DUMP-OF-LIVE" "$work/H/deploy/backups/safety"/pre-restore-*.dump.enc && ! ls "$work/H/deploy/backups"/pre-restore-* > /dev/null 2>&1'
check "H: it decrypts back to the live dump with the key" '[ "$(BACKUP_PASS=$(cat "$work/H/key") openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass env:BACKUP_PASS < "$(ls "$work/H/deploy/backups/safety"/pre-restore-*.dump.enc)")" = "SAFETY-DUMP-OF-LIVE" ]'
check "H: the safety copy was verified in a scratch database before the restore" 'called H "pg_restore --no-owner" || grep -q "createdb\|restore_check" "$work/H/log"'
check "H: nothing is left in the temp area and no .partial file remains" '[ -z "$(ls "$work/H/deploy/backups/safety" | grep partial)" ]'
touch "$work/modeprobe"; chmod 600 "$work/modeprobe"
if [ "$(stat -c %a "$work/modeprobe" 2> /dev/null)" = 600 ]; then
  check "H: the safety copy is mode 600" '[ "$(stat -c %a "$work"/H/deploy/backups/safety/pre-restore-*.dump.enc)" = 600 ]'
else echo "skip H: file modes are not honoured on this filesystem"; fi
new_case H2; printf 'a long test secret\n' > "$work/H2/key"; before=$(volume_sum "$work/H2/volume")
restore H2 BACKUP_KEY_FILE="$work/H2/key" BACKUP_ALLOW_UNENCRYPTED=0 FAKE_SWAP_FAIL_AFTER=1
check "H2: with an encrypted safety copy the failed swap still rolls the database back from it" 'called H2 "db-restore #2 input=SAFETY-DUMP-OF-LIVE" && called H2 "^start backend" && [ "$(volume_sum "$work/H2/volume")" = "$before" ]'

# --- I (R4-06): no key and no explicit waiver: refuse before touching anything -------------------------------------------
new_case I; before=$(volume_sum "$work/I/volume")
restore I BACKUP_KEY_FILE="$work/I/nokey" BACKUP_ALLOW_UNENCRYPTED=0
check "I: without a key an unencrypted safety copy is refused up front" '[ $rc -ne 0 ] && grep -q "refusing to keep an unencrypted safety copy" "$work/I/out" && ! called I "^stop " && ! called I "db-restore" && [ "$(volume_sum "$work/I/volume")" = "$before" ]'

# --- J (R4-06): not enough free disk for the safety copy ---------------------------------------------------------------------
new_case J; before=$(volume_sum "$work/J/volume")
restore J FAKE_DB_SIZE=900000000000000000
check "J: a database larger than the free disk space is refused before anything changes" '[ $rc -ne 0 ] && grep -q "not enough free space" "$work/J/out" && ! called J "^stop " && ! called J "db-restore" && [ "$(volume_sum "$work/J/volume")" = "$before" ]'

# --- M/N (R4): a failed or incomplete reference query is never reported as a clean scan ---------------------------------
new_case M; restore M FAKE_REFS_FAIL=1
check "M: the restore itself succeeded" '[ $rc -eq 0 ]'
check "M: a failed reference query is reported as NOT PERFORMED, never as 0 missing" 'grep -q "RECONCILIATION NOT PERFORMED" "$work/M/out" && ! grep -q "0 missing" "$work/M/out" && grep -q "reconciliation: FAILED" "$work/M/out"'
new_case N; restore N FAKE_REFS_TRUNCATED=1
check "N: an incomplete reference list (no terminator) is also a failed scan" 'grep -q "RECONCILIATION NOT PERFORMED" "$work/N/out" && ! grep -q " 0 missing" "$work/N/out"'

echo "$pass passed, $failed failed"
[ "$failed" -eq 0 ]
