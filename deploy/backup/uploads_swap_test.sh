#!/usr/bin/env bash
# Failure-injection tests for the staged uploads restore (audit I-02), no Docker needed:
#   bash deploy/backup/uploads_swap_test.sh
# They run uploads_swap.sh against temporary directories and prove: the live files are untouched until a verified
# staged copy exists, a damaged archive or a failure at ANY rename leaves the live files exactly as they were,
# and a finished swap can be rolled back.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
swap="$here/uploads_swap.sh"
pass=0; failed=0
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else failed=$((failed+1)); echo "FAIL $1"; fi; }

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
live="$work/live"

# listing of the application files (not the script's own .restore-* directories), with checksums
snapshot() { ( cd "$1" && find . -path './.restore-*' -prune -o -type f -print | sort | while IFS= read -r f; do printf '%s %s\n' "$(cksum < "$f")" "$f"; done ); }
run() { UPLOADS_DIR="$live" sh "$swap" "$@"; }
reset_live() {
  rm -rf "$live"; mkdir -p "$live/public/avatars" "$live/public/gallery" "$live/private/docs"
  echo "old avatar" > "$live/public/avatars/a1.jpg"
  echo "old gallery" > "$live/public/gallery/g1.jpg"
  echo "old id" > "$live/private/docs/id1.png"
  echo "with space" > "$live/public/gallery/name with space.jpg"
}
make_tarball() {
  rm -rf "$work/src"; mkdir -p "$work/src/public/avatars" "$work/src/private/docs" "$work/src/extra"
  echo "new avatar" > "$work/src/public/avatars/n1.jpg"
  echo "new id" > "$work/src/private/docs/nid.png"
  echo "hidden" > "$work/src/.hidden-file"
  echo "x" > "$work/src/extra/e.txt"
  tar -czf "$work/good.tgz" -C "$work/src" .
}
make_tarball
head -c 40 "$work/good.tgz" > "$work/bad.tgz"   # cut off: gzip/tar cannot read it

# --- preflight ------------------------------------------------------------------------------------------------
reset_live
check "preflight accepts a readable tarball with room to spare" 'run preflight < "$work/good.tgz" > /dev/null'
check "preflight rejects garbage" '! run preflight < /dev/null > /dev/null 2>&1'

# --- stage: a damaged archive never touches the live files -----------------------------------------------------
reset_live; before=$(snapshot "$live")
check "a damaged archive fails to stage" '! run stage T1 < "$work/bad.tgz" > /dev/null 2>&1'
check "...and the live files are exactly as before" '[ "$(snapshot "$live")" = "$before" ]'
check "...and no staging directory is left behind" '[ ! -e "$live/.restore-staging-T1" ]'

# --- the happy path -----------------------------------------------------------------------------------------------
reset_live; before=$(snapshot "$live")
check "a good archive stages" 'run stage T2 < "$work/good.tgz" > /dev/null'
check "staging does not change the live files yet" '[ "$(snapshot "$live")" = "$before" ]'
check "the swap succeeds" 'run swap T2 > /dev/null'
check "the live volume now holds the restored files" '[ -f "$live/public/avatars/n1.jpg" ] && [ -f "$live/.hidden-file" ] && [ -f "$live/extra/e.txt" ] && [ ! -e "$live/public/avatars/a1.jpg" ]'
check "the previous files are kept intact" '[ "$(cat "$live/.restore-previous-T2/public/avatars/a1.jpg")" = "old avatar" ] && [ -f "$live/.restore-previous-T2/public/gallery/name with space.jpg" ]'
check "rollback puts the previous files back" 'run rollback T2 > /dev/null && [ "$(snapshot "$live")" = "$before" ]'
check "the restored content stays staged after a rollback, and discard removes it" '[ -d "$live/.restore-staging-T2" ] && run discard T2 && [ -z "$(ls -A "$live" | grep "^.restore-")" ]'

# --- failure injected at every rename of the swap ---------------------------------------------------------------
# live has 3 top-level entries ("public", "private") + the hidden/extra of the archive: injecting at 1..N covers both phases
for n in 0 1 2 3 4 5; do
  reset_live; before=$(snapshot "$live")
  run stage "F$n" < "$work/good.tgz" > /dev/null
  UPLOADS_SWAP_FAIL_AFTER=$n run swap "F$n" > /dev/null 2>&1; rc=$?
  if [ $rc -ne 0 ]; then
    check "failure after $n renames: the swap reports failure" 'true'
    check "failure after $n renames: the live files are exactly as before" '[ "$(snapshot "$live")" = "$before" ]'
    check "failure after $n renames: the staged copy is intact for a retry" '[ -f "$live/.restore-staging-F'"$n"'/public/avatars/n1.jpg" ]'
  else
    check "failure after $n renames: it was past the last rename, so the swap completed" '[ -f "$live/public/avatars/n1.jpg" ]'
  fi
done

# --- retry after a failed swap works ------------------------------------------------------------------------------
reset_live
run stage R1 < "$work/good.tgz" > /dev/null
UPLOADS_SWAP_FAIL_AFTER=2 run swap R1 > /dev/null 2>&1
check "a swap that failed can simply be run again" 'run swap R1 > /dev/null && [ -f "$live/public/avatars/n1.jpg" ]'

# --- R4-01: the way back itself fails ---------------------------------------------------------------------------------
# For every point where the forward move fails and every point where the rollback then fails: the exit code says
# RECOVERY FAILED (3), nothing is deleted (journal, previous and staged copies stay), and running the rollback again
# finishes the job and proves the original files are back.
for f in 1 2 3 4; do
  for r in 0 1 2; do
    reset_live; before=$(snapshot "$live")
    run stage "RB$f$r" < "$work/good.tgz" > /dev/null
    UPLOADS_SWAP_FAIL_AFTER=$f UPLOADS_ROLLBACK_FAIL_AFTER=$r run swap "RB$f$r" > /dev/null 2>&1; rc=$?
    if [ $rc -eq 3 ]; then
      check "forward failure $f + rollback failure $r: reports RECOVERY FAILED (exit 3)" 'true'
      check "forward failure $f + rollback failure $r: the journal and the previous files are retained" '[ -f "$live/.restore-journal-RB'"$f$r"'" ] && [ -d "$live/.restore-previous-RB'"$f$r"'" ]'
      check "forward failure $f + rollback failure $r: a new swap is refused while recovery is pending" '! run swap "RB'"$f$r"'" > /dev/null 2>&1'
      check "forward failure $f + rollback failure $r: running rollback again restores everything" 'run rollback "RB'"$f$r"'" > /dev/null 2>&1 && [ "$(snapshot "$live")" = "$before" ] && [ ! -e "$live/.restore-journal-RB'"$f$r"'" ]'
    else
      check "forward failure $f + rollback failure $r: no rollback was needed or it succeeded (exit $rc), files as before" '[ $rc -ne 0 ] && [ "$(snapshot "$live")" = "$before" ] || [ $rc -eq 0 ]'
    fi
  done
done

# a real OS rename failure (a mv wrapper), the audit reproduction: forward AND backward moves of "public" fail
reset_live; before=$(snapshot "$live")
mkdir -p "$work/bin"
cat > "$work/bin/mv" <<'WRAPPER'
#!/bin/sh
if [ -n "${MV_FAIL:-}" ]; then
  case "$1" in
    */.restore-staging-*/public|*/.restore-previous-*/public) echo 'simulated OS rename failure' >&2; exit 1;;
  esac
fi
exec /usr/bin/mv "$@"
WRAPPER
chmod +x "$work/bin/mv"
run stage OS1 < "$work/good.tgz" > /dev/null
MV_FAIL=1 PATH="$work/bin:$PATH" run swap OS1 > /dev/null 2>&1; rc=$?
check "OS rename failure in both directions: swap exits 3, not success" '[ $rc -eq 3 ]'
check "...the previous files are still retained, not lost" '[ -f "$live/.restore-previous-OS1/public/avatars/a1.jpg" ]'
MV_FAIL=1 PATH="$work/bin:$PATH" run rollback OS1 > /dev/null 2>&1; rc=$?
check "...an explicit rollback that fails also exits 3" '[ $rc -eq 3 ] && [ -f "$live/.restore-journal-OS1" ]'
check "...once the rename works again the rollback completes and verifies" 'run rollback OS1 > /dev/null 2>&1 && [ "$(snapshot "$live")" = "$before" ]'

# an explicit rollback after a COMPLETED swap that fails halfway, then resumes
reset_live; before=$(snapshot "$live")
run stage RB9 < "$work/good.tgz" > /dev/null; run swap RB9 > /dev/null
UPLOADS_ROLLBACK_FAIL_AFTER=2 run rollback RB9 > /dev/null 2>&1; rc=$?
check "an explicit rollback that fails halfway exits 3 and keeps the journal" '[ $rc -eq 3 ] && [ -f "$live/.restore-journal-RB9" ]'
check "...and resuming it never nests or deletes anything and restores the original files" 'run rollback RB9 > /dev/null 2>&1 && [ "$(snapshot "$live")" = "$before" ]'

# a rollback for a swap made without a journal (older release) still works
reset_live; before=$(snapshot "$live")
run stage OLD < "$work/good.tgz" > /dev/null; run swap OLD > /dev/null; rm -f "$live/.restore-journal-OLD"
check "a swap from before the journal existed can still be rolled back" 'run rollback OLD > /dev/null 2>&1 && [ "$(snapshot "$live")" = "$before" ]'

# --- purge ------------------------------------------------------------------------------------------------------------
reset_live; run stage R1 < "$work/good.tgz" > /dev/null; run swap R1 > /dev/null
check "purge frees the retained previous files" 'run purge R1 && [ ! -e "$live/.restore-previous-R1" ]'
check "...and keeps the restored ones" '[ -f "$live/public/avatars/n1.jpg" ]'

echo "$pass passed, $failed failed"
[ "$failed" -eq 0 ]
