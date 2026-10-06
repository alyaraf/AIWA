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

# --- U (R5-03): ONE paired undo: backend stopped for both halves, started only when both are back -------------------------
# undo <case> <id> [VAR=value ...]: restore.sh --undo <id> in that case's deploy dir; the log is reset first
undo() {
  c="$work/$1"; id="$2"; shift 2; : > "$c/log"
  ( cd "$c/deploy" && env PATH="$work/bin:$PATH" FAKE_LOG="$c/log" FAKE_STATE="$c/state" FAKE_VOLUME="$c/volume" \
      FAKE_DEPLOY="$c/deploy" ASSUME_YES=1 BACKUP_ALLOW_UNENCRYPTED=${BACKUP_ALLOW_UNENCRYPTED:-1} "$@" bash ./restore.sh --undo "$id" ) > "$c/undo-out" 2>&1
  urc=$?
}
rid_of() { ls "$work/$1/deploy/backups/safety" | sed -n 's/^pre-restore-\(.*\)\.dump.*/\1/p' | grep -v '^undo-' | head -1; }
starts_after() { awk -v n="$2" 'NR>n && /^start backend/ { c++ } END { print c+0 }' "$work/$1/log"; }

new_case U; restore U; uid=$(rid_of U)
check "U: the restore itself succeeded and printed the single supported undo command" '[ $rc -eq 0 ] && grep -q "./restore.sh --undo $uid" "$work/U/out"'
undo U "$uid"
check "U: the undo succeeds" '[ $urc -eq 0 ]'
check "U: it puts back BOTH the old database (fed the safety dump) and the old uploads" 'called U "db-restore #2 input=SAFETY-DUMP-OF-LIVE" && [ -f "$work/U/volume/public/avatars/a1.jpg" ] && [ ! -e "$work/U/volume/public/avatars/n1.jpg" ]'
check "U: the backend is stopped BEFORE either half is changed" '[ "$(line_of U "^stop ")" -lt "$(line_of U "db-restore #2")" ] && [ "$(line_of U "^stop ")" -lt "$(line_of U "uploads_swap.sh rollback")" ]'
check "U: NO backend start between the database restore and the uploads rollback" '[ "$(line_of U "db-restore #2")" -lt "$(line_of U "uploads_swap.sh rollback")" ] && [ "$(grep -c "^start backend" "$work/U/log")" -eq 1 ] && [ "$(line_of U "uploads_swap.sh rollback")" -lt "$(line_of U "^start backend")" ]'
check "U: the previous uploads and journal are consumed; the undone restore's files are kept as .restore-staging until purged" '! ls "$work/U/volume/".restore-previous-* > /dev/null 2>&1 && ! ls "$work/U/volume/".restore-journal-* > /dev/null 2>&1 && [ -f "$work/U/volume/".restore-staging-"$uid"/public/avatars/n1.jpg ] && grep -q "uploads_swap.sh purge $uid" "$work/U/undo-out"'
check "U: a safety copy of the current database was taken first, and it is not mistaken for the restore's own" 'ls "$work/U/deploy/backups/safety"/pre-restore-undo-*.dump > /dev/null 2>&1 && [ -e "$work/U/deploy/backups/safety/pre-restore-$uid.dump" ]'
check "U: the output says the restore was undone and the reconciliation ran" 'grep -q "was UNDONE" "$work/U/undo-out" && grep -q "undone; reconciliation: completed" "$work/U/undo-out"'

# the database half fails: nothing changed, the backend stays stopped, the uploads are not touched
new_case U2; restore U2; uid=$(rid_of U2); before=$(volume_sum "$work/U2/volume")
undo U2 "$uid" FAKE_DB_RESTORE_FAILS=2
check "U2: a failed database half fails the undo and the backend is NOT started" '[ $urc -ne 0 ] && [ "$(grep -c "^start backend" "$work/U2/log")" -eq 0 ] && grep -q "STOPPED" "$work/U2/undo-out"'
check "U2: the uploads are untouched (still the restored ones) and nothing recovery-related is lost" '[ "$(volume_sum "$work/U2/volume")" = "$before" ] && ! called U2 "uploads_swap.sh rollback" && ls "$work/U2/volume/".restore-previous-* > /dev/null 2>&1 && ls "$work/U2/volume/".restore-journal-* > /dev/null 2>&1 && [ -e "$work/U2/deploy/backups/safety/pre-restore-$uid.dump" ]'
check "U2: the message prints runnable commands (repeat the undo, or start the restored pair)" 'grep -q "./restore.sh --undo $uid" "$work/U2/undo-out" && grep -q "docker compose -f docker-compose.prod.yml start backend" "$work/U2/undo-out"'

# the uploads half fails after the database was put back: the backend must stay stopped
new_case U3; restore U3; uid=$(rid_of U3)
undo U3 "$uid" FAKE_ROLLBACK_FAIL_AFTER=0
check "U3: a failed uploads half fails the undo and the backend is NOT started with the old database on the new files" '[ $urc -ne 0 ] && [ "$(grep -c "^start backend" "$work/U3/log")" -eq 0 ] && called U3 "db-restore #2 input=SAFETY-DUMP-OF-LIVE" && grep -q "STOPPED" "$work/U3/undo-out" && grep -q "INCOMPLETE" "$work/U3/undo-out"'
check "U3: the journal, the previous files and both safety copies are retained" 'ls "$work/U3/volume/".restore-journal-* > /dev/null 2>&1 && ls "$work/U3/volume/".restore-previous-* > /dev/null 2>&1 && [ -e "$work/U3/deploy/backups/safety/pre-restore-$uid.dump" ] && ls "$work/U3/deploy/backups/safety"/pre-restore-undo-*.dump > /dev/null 2>&1'
check "U3: it prints complete, runnable recovery commands" 'grep -q "docker compose -f docker-compose.prod.yml run --rm -T --entrypoint sh backup /uploads_swap.sh rollback $uid" "$work/U3/undo-out" && grep -q "docker compose -f docker-compose.prod.yml start backend" "$work/U3/undo-out"'
# ...and with the cause gone the printed rollback command finishes it (the fake docker runs the same script)
( cd "$work/U3/deploy" && env PATH="$work/bin:$PATH" FAKE_LOG="$work/U3/log" FAKE_STATE="$work/U3/state" FAKE_VOLUME="$work/U3/volume" FAKE_DEPLOY="$work/U3/deploy" docker compose -f docker-compose.prod.yml run --rm -T --entrypoint sh backup /uploads_swap.sh rollback "$uid" > /dev/null 2>&1 ); u3rc=$?
check "U3: repeating the printed rollback command completes the recovery" '[ $u3rc -eq 0 ] && [ -f "$work/U3/volume/public/avatars/a1.jpg" ] && [ ! -e "$work/U3/volume/public/avatars/n1.jpg" ]'

# a restore whose own rollback could not be verified (R4-01) is finished by ONE undo command, not by a database-first restore
new_case U4; restore U4 MV_FAIL=1; uid=$(rid_of U4)
check "U4: the failed-rollback message names the single undo command" 'grep -q "./restore.sh --undo $uid" "$work/U4/out"'
undo U4 "$uid"
check "U4: with the cause gone the undo resumes from the journal and finishes both halves, starting the backend once at the end" '[ $urc -eq 0 ] && [ -f "$work/U4/volume/public/avatars/a1.jpg" ] && [ "$(grep -c "^start backend" "$work/U4/log")" -eq 1 ] && [ "$(line_of U4 "uploads_swap.sh rollback")" -lt "$(line_of U4 "^start backend")" ]'

# encrypted safety copies: the undo decrypts and verifies the saved one, and its own safety copy is encrypted too
new_case U5; printf 'a long test secret\n' > "$work/U5/key"
restore U5 BACKUP_KEY_FILE="$work/U5/key" BACKUP_ALLOW_UNENCRYPTED=0; uid=$(rid_of U5)
before=$(volume_sum "$work/U5/volume")
BACKUP_ALLOW_UNENCRYPTED=0 undo U5 "$uid" BACKUP_KEY_FILE="$work/U5/nokey"
check "U5: an encrypted safety copy without its key is refused before anything is stopped or changed" '[ $urc -ne 0 ] && ! called U5 "^stop " && ! called U5 "db-restore" && [ "$(volume_sum "$work/U5/volume")" = "$before" ]'
BACKUP_ALLOW_UNENCRYPTED=0 undo U5 "$uid" BACKUP_KEY_FILE="$work/U5/key"
check "U5: with the key the undo succeeds from the ENCRYPTED safety copy" '[ $urc -eq 0 ] && called U5 "db-restore #2 input=SAFETY-DUMP-OF-LIVE" && [ -f "$work/U5/volume/public/avatars/a1.jpg" ]'
check "U5: the safety copy of the undone state is encrypted as well; no plaintext safety dump exists" 'ls "$work/U5/deploy/backups/safety"/pre-restore-undo-*.dump.enc > /dev/null 2>&1 && ! ls "$work/U5/deploy/backups/safety"/*.dump > /dev/null 2>&1'

# nothing to undo: unknown id, or the previous uploads were purged
new_case U6; restore U6; uid=$(rid_of U6)
undo U6 "no-such-id"
check "U6: an unknown restore id is refused with nothing changed" '[ $urc -ne 0 ] && ! called U6 "^stop " && ! called U6 "db-restore"'
UPLOADS_DIR="$work/U6/volume" sh "$work/U6/deploy/backup/uploads_swap.sh" purge "$uid"; before=$(volume_sum "$work/U6/volume")
undo U6 "$uid"
check "U6: previous uploads already purged: the paired undo is refused BEFORE the backend is stopped or the database touched" '[ $urc -ne 0 ] && ! called U6 "^stop " && ! called U6 "db-restore" && grep -q "cannot be undone" "$work/U6/undo-out" && [ "$(volume_sum "$work/U6/volume")" = "$before" ]'

# R6: retry a previously incomplete undo while its safety-copy step fails.
new_case R6; restore R6; uid=$(rid_of R6)
undo R6 "$uid" FAKE_ROLLBACK_FAIL_AFTER=0
check 'R6 setup: first undo restores OLD database, fails files, and leaves backend stopped' '[ $urc -ne 0 ] && ! called R6 "^start backend" && called R6 "db-restore #2 input=SAFETY-DUMP-OF-LIVE" && [ -f "$work/R6/volume/public/avatars/n1.jpg" ] && [ ! -e "$work/R6/volume/public/avatars/a1.jpg" ]'
undo R6 "$uid" FAKE_NO_SAFETY=1
check 'R6 defect: failed safety copy on retry restarts backend on OLD database and NEW files' '[ $urc -ne 0 ] && called R6 "^start backend" && ! called R6 "db-restore" && [ -f "$work/R6/volume/public/avatars/n1.jpg" ] && [ ! -e "$work/R6/volume/public/avatars/a1.jpg" ]'
echo 'CONFIRMED: retry safety-copy failure restarts an already inconsistent pair.'
echo "$pass passed, $failed failed"
[ "$failed" -eq 0 ]
