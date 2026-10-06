#!/usr/bin/env bash
# CR-20 test for backup.sh, run with bash (no docker): pg_dump, pg_restore and tar are stubs.
#   bash deploy/backup/backup_test.sh
# BACKUP_SCRIPT overrides the script under test (used to show the test failing on the old script).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
script="${BACKUP_SCRIPT:-$here/backup.sh}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; failed=0
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else failed=$((failed+1)); echo "FAIL $1"; fi; }

mkdir "$tmp/stubs"
cat > "$tmp/stubs/pg_dump" <<'S'
#!/bin/sh
[ "${STUB_FAIL:-}" = pg_dump ] && exit 1
[ "$1" = -Fc ] && [ "$2" = -f ] && yes aiwa | head -c 2000 > "$3"
S
printf '#!/bin/sh\nexit 0\n' > "$tmp/stubs/pg_restore"
printf '#!/bin/sh\nexit 0\n' > "$tmp/stubs/createdb"
printf '#!/bin/sh\nexit 0\n' > "$tmp/stubs/dropdb"
cat > "$tmp/stubs/tar" <<'S'
#!/bin/sh
[ "${STUB_FAIL:-}" = tar ] && exit 1
if [ "$1" = -tzf ]; then   # the listing of the tarball (R4 reconciliation); STUB_TAR_NO_A=1: a.jpg was deleted before tar ran (R5-02)
  printf './\n./public/\n'; [ "${STUB_TAR_NO_A:-}" = 1 ] || printf './public/a.jpg\n'; exit 0
fi
printf uploads | gzip -n > "$2"
S
cat > "$tmp/stubs/psql" <<'S'
#!/bin/sh
# R5-02: the file-reference query is answered per database. The scratch restore of the dump (psql -d aiwa_verify_*)
# holds the DUMP's references; any other connection is the LIVE database, which has moved on (STUB_LIVE_REFS=none:
# the file and its row were deleted after the dump). Rows, then the done|ok terminator.
db=""; while [ $# -gt 0 ]; do [ "$1" = -d ] && db="$2"; shift; done
case "$db" in
  aiwa_verify_*)
    [ "${STUB_FAIL:-}" = psql ] || [ "${STUB_FAIL:-}" = psql_scratch ] && { echo "psql: connection refused" >&2; exit 2; }
    printf 'public|/files/public/a.jpg\n'
    [ -n "${STUB_MISSING_REF:-}" ] && printf 'public|/files/public/deleted.jpg\n'
    [ "${STUB_PARTIAL_THEN_FAIL:-}" = 1 ] && { echo "psql: connection lost" >&2; exit 2; }
    [ "${STUB_NO_TERMINATOR:-}" = 1 ] || printf 'done|ok\n' ;;
  *)
    [ "${STUB_FAIL:-}" = psql ] && { echo "psql: connection refused" >&2; exit 2; }
    [ "${STUB_LIVE_REFS:-}" = none ] || printf 'public|/files/public/a.jpg\n'
    printf 'done|ok\n' ;;
esac
S
chmod +x "$tmp/stubs/"*

# run_backup <dir> [VAR=value ...]: one backup into <dir>; exit code in $rc
run_backup() {
  d="$1"; shift
  mkdir -p "$d/uploads-src"
  env PATH="$tmp/stubs:$PATH" BACKUP_DIR="$d/out" UPLOADS_DIR="$d/uploads-src" BACKUP_ALLOW_UNENCRYPTED=1 RECONCILE_SCRIPT="$here/reconcile_uploads.sh" REFERENCES_SQL="$here/uploads_references.sql" "$@" sh "$script" once > "$d/log" 2>&1
  rc=$?
}
metric() { sed -n "s/^$2 //p" "$1/out/metrics/metrics.txt" 2>/dev/null; }
ts=aiwa_backup_last_success_timestamp_seconds

# C1: success writes a fresh timestamp
d="$tmp/ok"; run_backup "$d"; now=$(date -u +%s); t=$(metric "$d" $ts)
check "success exits 0" '[ $rc -eq 0 ]'
# I-03: each pair gets a manifest saying when the dump and the tarball were taken (dump first)
check "success writes a snapshot manifest naming both files" 'grep -q "\"dump\":\"aiwa-" "$d"/out/manifest/snapshot-*.json && grep -q "\"tar_started\"" "$d"/out/manifest/snapshot-*.json'
check "success writes a fresh timestamp" '[ -n "$t" ] && [ "$t" -le "$now" ] && [ "$t" -ge $((now-30)) ]'

# R4 / I-03: the pair is reconciled while the backup is made, and a failed scan is never a clean one
check "success: the manifest records a completed reconciliation with 0 missing" 'grep -q "\"reconcile\":\"ok\"" "$d"/out/manifest/snapshot-*.json && grep -q "\"missing_references\":0" "$d"/out/manifest/snapshot-*.json'
check "success: reconcile metrics are 1 and 0" '[ "$(metric "$d" aiwa_backup_reconcile_ok)" = 1 ] && [ "$(metric "$d" aiwa_backup_missing_references)" = 0 ]'
d="$tmp/recmissing"; run_backup "$d" STUB_MISSING_REF=1
check "a referenced file missing from the tarball is counted, and the backup still succeeds" '[ $rc -eq 0 ] && [ "$(metric "$d" aiwa_backup_missing_references)" = 1 ] && [ "$(metric "$d" aiwa_backup_reconcile_ok)" = 1 ]'
d="$tmp/recfail"; run_backup "$d" STUB_FAIL=psql
check "a failed reference query does not fail the backup" '[ $rc -eq 0 ] && [ -f "$d/out/last-success" ]'
check "...but is recorded as failed: manifest, metric and log, never as 0 missing" 'grep -q "\"reconcile\":\"failed\"" "$d"/out/manifest/snapshot-*.json && [ "$(metric "$d" aiwa_backup_reconcile_ok)" = 0 ] && [ "$(metric "$d" aiwa_backup_missing_references)" = -1 ] && grep -q "RECONCILIATION FAILED" "$d/log" && ! grep -q " 0 missing" "$d/log"'
d="$tmp/recpartial"; run_backup "$d" STUB_NO_TERMINATOR=1
check "an incomplete reference list (no terminator) is also a failed scan" '[ "$(metric "$d" aiwa_backup_reconcile_ok)" = 0 ] && grep -q "RECONCILIATION FAILED" "$d/log"'

# R5-02: the references come from the dump's scratch restore, never from the live database
d="$tmp/recdump"; mkdir -p "$d/tmpdir"; run_backup "$d" TMPDIR="$d/tmpdir" STUB_TAR_NO_A=1 STUB_LIVE_REFS=none
check "R5-02: a file deleted together with its live row before tar is still missing for the dump" '[ $rc -eq 0 ] && [ "$(metric "$d" aiwa_backup_missing_references)" = 1 ] && [ "$(metric "$d" aiwa_backup_reconcile_ok)" = 1 ] && grep -q "\"missing_references\":1" "$d"/out/manifest/snapshot-*.json && grep -q "MISSING public /files/public/a.jpg" "$d/log"'
check "R5-02: the reference temp file is removed" '[ -z "$(ls -A "$d/tmpdir")" ]'
d="$tmp/reclive"; run_backup "$d" STUB_LIVE_REFS=none
check "R5-02: references deleted from the live database after the dump do not hide a file the tarball holds, or invent a miss" '[ "$(metric "$d" aiwa_backup_missing_references)" = 0 ] && [ "$(metric "$d" aiwa_backup_reconcile_ok)" = 1 ]'
d="$tmp/recscratchfail"; run_backup "$d" STUB_FAIL=psql_scratch STUB_TAR_NO_A=1
check "R5-02: a failed scratch query is a failed scan even though the live database would answer (no fallback to it)" '[ $rc -eq 0 ] && grep -q "\"reconcile\":\"failed\"" "$d"/out/manifest/snapshot-*.json && [ "$(metric "$d" aiwa_backup_reconcile_ok)" = 0 ] && [ "$(metric "$d" aiwa_backup_missing_references)" = -1 ] && ! grep -q " 0 missing" "$d/log"'
d="$tmp/recpartialfail"; run_backup "$d" STUB_PARTIAL_THEN_FAIL=1
check "R5-02: a scratch query that dies after some rows is a failed scan, not a short clean list" '[ $rc -eq 0 ] && [ "$(metric "$d" aiwa_backup_reconcile_ok)" = 0 ] && [ "$(metric "$d" aiwa_backup_missing_references)" = -1 ] && grep -q "RECONCILIATION FAILED" "$d/log"'
d="$tmp/recnoterm"; run_backup "$d" STUB_NO_TERMINATOR=1 STUB_TAR_NO_A=1
check "R5-02: an incomplete scratch list never reports zero missing" '[ "$(metric "$d" aiwa_backup_reconcile_ok)" = 0 ] && ! grep -q " 0 missing" "$d/log"'

# R4-06: the pre-restore safety copies are retained by the same job: old ones go, one whose previous uploads were not purged stays
d="$tmp/safety"; mkdir -p "$d/out/safety" "$d/uploads-src/.restore-previous-20200101-000000-1"
touch -d '40 days ago' "$d/out/safety/pre-restore-20200101-000000-1.dump.enc" "$d/out/safety/pre-restore-20200102-000000-2.dump.enc" "$d/out/safety/pre-restore-20200103-000000-3.dump.enc.partial"
touch "$d/out/safety/pre-restore-20991231-000000-4.dump.enc"
run_backup "$d"
check "safety copies: an old copy is deleted" '[ ! -e "$d/out/safety/pre-restore-20200102-000000-2.dump.enc" ]'
check "safety copies: an old copy whose previous uploads still exist is kept, with a warning" '[ -e "$d/out/safety/pre-restore-20200101-000000-1.dump.enc" ] && grep -q "kept: the previous uploads" "$d/log"'
check "safety copies: a recent copy is kept and an old .partial is removed" '[ -e "$d/out/safety/pre-restore-20991231-000000-4.dump.enc" ] && [ ! -e "$d/out/safety/pre-restore-20200103-000000-3.dump.enc.partial" ]'

# C1: failure keeps the old timestamp and exits non-zero (pg_dump and tar)
for what in pg_dump tar; do
  d="$tmp/fail-$what"; mkdir -p "$d/out/metrics"
  printf '# TYPE %s gauge\n%s 1000\naiwa_backup_encrypted 1\n' $ts $ts > "$d/out/metrics/metrics.txt"
  run_backup "$d" STUB_FAIL=$what
  check "$what failure exits non-zero" '[ $rc -ne 0 ]'
  check "$what failure keeps the old timestamp" '[ "$(metric "$d" $ts)" = 1000 ]'
done

# C2: with a key file the outputs are encrypted and decrypt back to the same bytes
d="$tmp/enc"; mkdir -p "$d"; printf 'correct horse battery staple\n' > "$d/key"
run_backup "$d" BACKUP_KEY_FILE="$d/key"
dumps=("$d"/out/db/*); ups=("$d"/out/uploads/*)
check "encrypted run exits 0" '[ $rc -eq 0 ]'
check "encrypted: one .enc dump and one .enc tarball, no plaintext" '[ ${#dumps[@]} -eq 1 ] && [ ${#ups[@]} -eq 1 ] && [[ ${dumps[0]} == *.dump.enc ]] && [[ ${ups[0]} == *.tar.gz.enc ]]'
check "encrypted metric is 1" '[ "$(metric "$d" aiwa_backup_encrypted)" = 1 ]'
dec() { BACKUP_PASS=$(cat "$d/key") openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass env:BACKUP_PASS < "$1"; }
check "dump decrypts to the same bytes" 'dec "${dumps[0]}" | cmp -s - <(yes aiwa | head -c 2000)'
check "uploads tarball decrypts to the same bytes" 'dec "${ups[0]}" | cmp -s - <(printf uploads | gzip -n)'

# S-02: without a key and without the explicit opt-out the backup refuses to run
d="$tmp/refuse"; run_backup "$d" BACKUP_ALLOW_UNENCRYPTED=0
check "no key, no opt-out: exits non-zero" '[ $rc -ne 0 ]'
check "no key, no opt-out: writes no backup and no success metric" '[ -z "$(ls "$d"/out/db 2>/dev/null)" ] && [ ! -f "$d/out/last-success" ]'
check "no key, no opt-out: says BACKUP FAILED" 'grep -q "BACKUP FAILED" "$d/log"'

# C2: with BACKUP_ALLOW_UNENCRYPTED=1 and no key the backup still runs, warns, and the unencrypted metric is 0
d="$tmp/plain"; run_backup "$d"
check "no key: exits 0 and stores plain files" '[ $rc -eq 0 ] && [ -f "$d"/out/db/*.dump ] && [ -f "$d"/out/uploads/*.tar.gz ]'
check "no key: encrypted metric is 0" '[ "$(metric "$d" aiwa_backup_encrypted)" = 0 ]'
check "no key: logs a warning" 'grep -qi "warning" "$d/log"'

# a key path that is a directory (Docker's bind mount of a missing host file) counts as no key
d="$tmp/dirkey"; mkdir -p "$d/k"; run_backup "$d" BACKUP_KEY_FILE="$d/k"
check "key path is a directory: runs unencrypted" '[ $rc -eq 0 ] && [ "$(metric "$d" aiwa_backup_encrypted)" = 0 ]'

# a blank key file (only a newline) must not encrypt with an empty password
d="$tmp/blankkey"; mkdir -p "$d"; echo > "$d/key"; run_backup "$d" BACKUP_KEY_FILE="$d/key"
check "blank key: runs unencrypted, metric 0" '[ $rc -eq 0 ] && [ "$(metric "$d" aiwa_backup_encrypted)" = 0 ] && [ -f "$d"/out/db/*.dump ]'

# ---- restore.sh against a fake docker (never the real one) ----
# RESTORE_SCRIPT overrides the script under test, like BACKUP_SCRIPT.
rscript="${RESTORE_SCRIPT:-$here/../restore.sh}"
mkdir "$tmp/dstub"  # only docker is faked here: tar and openssl are the real ones
cat > "$tmp/dstub/docker" <<'S'
#!/bin/bash
# fake "docker compose ...": logs the call; plays postgres (exec) and the backup container (run) on local files
echo "$*" >> "$FAKE_LOG"
# what the restore script's temp files look like while it runs: its umask, then the mode and name of its temp dir and files
snap() { { umask; for f in "$TMPDIR"/tmp.*/ "$TMPDIR"/tmp.*/*; do stat -c '%a %n' "$f"; done; } >> "$FAKE_LOG.modes" 2>&1; }
case " $* " in
  *" pg_restore --list "*) snap; [ "$(head -c 5)" = PGDMP ] ;;
  # SA-04: the scratch database the dump is test-restored into first
  *" createdb "*|*" dropdb "*) ;;
  *" pg_restore --no-owner --exit-on-error "*) cat > "$FAKE_LOG.scratch"; [ "${FAKE_SCRATCH_FAIL:-}" != 1 ] ;;
  # I-02: restore.sh takes a safety copy of the live database before it restores
  *" pg_database_size "*|*pg_database_size*) cat > /dev/null; echo 1000 ;;
  *" pg_dump -Fc "*) echo PGDMP-SAFETY-COPY ;;
  *" pg_restore --clean "*) cat > "$FAKE_LOG.restored" ;;
  *" psql "*) cat > /dev/null ;;
  *" exec "*) cat > /dev/null ;;
  # I-02: the backup container runs the real swap / reconcile scripts against the fake volume
  *" run "*)
    snap
    args=("$@"); i=0
    while [ "${args[$i]}" != backup ]; do i=$((i+1)); done
    script="${args[$((i+1))]}"; rest=("${args[@]:$((i+2))}")
    case "$script" in
      /uploads_swap.sh) UPLOADS_DIR="$FAKE_UPLOADS" sh "$SWAP_SCRIPTS/uploads_swap.sh" "${rest[@]}" ;;
      /reconcile_uploads.sh) UPLOADS_DIR="$FAKE_UPLOADS" sh "$SWAP_SCRIPTS/reconcile_uploads.sh" ;;
    esac ;;
esac
S
chmod +x "$tmp/dstub/docker"
enc() { BACKUP_PASS=$(cat "$2") openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -pass env:BACKUP_PASS < "$1" > "$1.enc"; }
r="$tmp/restore"; mkdir -p "$r/src"; printf 'rightkey
' > "$r/key"; printf 'wrongkey
' > "$r/wrong"
printf 'PGDMPdump-bytes' > "$r/db.dump"; enc "$r/db.dump" "$r/key"
mkdir "$r/src/new"; echo new > "$r/src/new/photo.jpg"; tar -czf "$r/up.tgz" -C "$r/src/new" .; enc "$r/up.tgz" "$r/key"
echo 'not gzip' > "$r/bad.tgz"; printf 'garbage' > "$r/bad.dump"
# run_restore <name> <key> <dump> <uploads> [VAR=value ...]: uploads dir starts with live.jpg; exit code in $rc
run_restore() {
  n="$1"; k="$2"; dp="$3"; up="$4"; shift 4
  FAKE="$r/$n"; rm -rf "$FAKE"; mkdir -p "$FAKE/uploads"; echo live > "$FAKE/uploads/live.jpg"; : > "$FAKE/log"
  env PATH="$tmp/dstub:$PATH" ASSUME_YES=1 BACKUP_KEY_FILE="$k" FAKE_LOG="$FAKE/log" FAKE_UPLOADS="$FAKE/uploads" SWAP_SCRIPTS="$here" "$@"     bash "$rscript" "$dp" "$up" > "$FAKE/out" 2>&1
  rc=$?
}
# I-02: a failed restore may have STAGED the archive (inside the volume, live files untouched) but never stops the
# backend, restores the database or swaps the uploads.
untouched() { [ "$(cat "$FAKE/uploads/live.jpg" 2>/dev/null)" = live ] && ! grep -Eq ' (stop|exec .*--clean) |uploads_swap.sh swap' "$FAKE/log"; }

run_restore wrongkey "$r/wrong" "$r/db.dump" "$r/up.tgz.enc"
check "restore, wrong key: fails and leaves uploads and database alone" '[ $rc -ne 0 ] && untouched'
run_restore wrongdump "$r/wrong" "$r/db.dump.enc" "$r/up.tgz"
check "restore, wrong key on the dump: fails before anything is touched" '[ $rc -ne 0 ] && untouched'
run_restore noopenssl "$r/key" "$r/db.dump" "$r/up.tgz.enc" OPENSSL_BIN=/no/such/openssl
check "restore, no openssl: fails and leaves uploads alone" '[ $rc -ne 0 ] && untouched'
run_restore nokey "$r/nokey" "$r/db.dump" "$r/up.tgz.enc"
check "restore, key file missing: fails and leaves uploads alone" '[ $rc -ne 0 ] && untouched'
run_restore badtar "$r/key" "$r/db.dump" "$r/bad.tgz"
check "restore, corrupt tarball: fails and leaves uploads alone" '[ $rc -ne 0 ] && untouched'
run_restore baddump "$r/key" "$r/bad.dump" "$r/up.tgz"
check "restore, corrupt dump: fails and leaves uploads alone" '[ $rc -ne 0 ] && untouched'
# SA-04: a dump that reads its table of contents but does not restore completely stops the script
# before the backend is stopped, the live database is cleaned or the uploads are emptied.
run_restore scratchfail "$r/key" "$r/db.dump" "$r/up.tgz" FAKE_SCRATCH_FAIL=1
check "restore, dump that fails the scratch restore: fails and leaves everything alone" '[ $rc -ne 0 ] && untouched && grep -q "does not restore completely" "$FAKE/out"'
run_restore good "$r/key" "$r/db.dump.enc" "$r/up.tgz.enc"
check "restore, right key: replaces database and uploads" '[ $rc -eq 0 ] && [ "$(cat "$FAKE/uploads/photo.jpg")" = new ] && [ ! -e "$FAKE/uploads/live.jpg" ] && cmp -s "$FAKE/log.restored" "$r/db.dump" && [ "$(cat "$FAKE"/uploads/.restore-previous-*/live.jpg)" = live ]'
run_restore plain "$r/nokey" "$r/db.dump" "$r/up.tgz" BACKUP_ALLOW_UNENCRYPTED=1
check "restore, plain files need no key" '[ $rc -eq 0 ] && [ "$(cat "$FAKE/uploads/photo.jpg")" = new ]'

# CR-20: the decrypted dump and tarball are plaintext, so the script runs with umask 077 and puts them under TMPDIR
# (point it at the restore volume). The fake docker above logs the umask and the temp files' modes while they exist.
mkdir -p "$r/rtmp"; old_umask=$(umask); umask 022   # a permissive caller: the script must tighten it itself
run_restore tmpmodes "$r/key" "$r/db.dump.enc" "$r/up.tgz.enc" TMPDIR="$r/rtmp"
umask "$old_umask"
check "restore, temp files: still restores with TMPDIR set" '[ $rc -eq 0 ] && [ "$(cat "$FAKE/uploads/photo.jpg")" = new ]'
check "restore, temp files: runs with umask 077 even when the caller's is 022" 'grep -qx 0077 "$FAKE/log.modes"'
check "restore, temp files: the temp dir is made under TMPDIR" 'grep -q "$r/rtmp/tmp\." "$FAKE/log.modes"'
probe="$r/probe"; : > "$probe"; chmod 640 "$probe"
modes_ok() {
  m="$FAKE/log.modes"
  dirs=$(grep -E '^[0-7]+ .*/tmp\.[^/]+/$' "$m"); files=$(grep -E '^[0-7]+ .*/tmp\.[^/]+/[^/]+$' "$m")
  [ -n "$dirs" ] && [ -n "$files" ] && ! echo "$dirs" | grep -qv '^700 ' && ! echo "$files" | grep -qv '^600 '
}
if [ "$(stat -c %a "$probe" 2>/dev/null)" = 640 ]; then
  check "restore, temp files: the temp dir is mode 700 and the plaintext files inside are 600" modes_ok
else
  echo "skip restore, temp files: modes 600/700 (this file system ignores chmod, e.g. NTFS; the umask check above covers it)"
fi

echo "$pass passed, $failed failed"
[ $failed -eq 0 ]
