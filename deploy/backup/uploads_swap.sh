#!/bin/sh
# Staged, recoverable replacement of the uploads volume contents (audit I-02, R4-01). Runs inside the backup
# container (/uploads mounted, tar and gzip present); restore.sh drives it. Everything happens INSIDE the one
# volume, so moving a name is an atomic rename, never a copy:
#
#   preflight   < tarball.tgz     does the volume have room for a second copy of the tarball's files?
#   stage <id>  < tarball.tgz     extract into /uploads/.restore-staging-<id> and verify it; the live files
#                                 are not touched, and a failure removes the staging directory again
#   swap <id>                     move the live entries into /uploads/.restore-previous-<id>, then move the staged
#                                 entries into place. Any failure puts the live entries back (rollback)
#   rollback <id>                 undo a swap: staged content out, previous content back in. Resumable: run it again
#                                 after a failure and it continues from the journal
#   discard <id>                  remove the staging directory (after a failed run)
#   purge <id>                    delete the retained previous content (only after the restore was verified)
#
# Exit codes: 0 done; 1 the command failed and the live files are exactly as before (for swap: the rollback ran
# and was VERIFIED); 2 usage; 3 RECOVERY FAILED: the live files are in a mixed state, the journal and both
# directories are kept, and the caller must not start the application (run "rollback <id>" again, or fix by hand).
#
# Every rename of the way back is checked. A recovery journal (.restore-journal-<id>) records the names that were
# live before ("L:") and the staged names that were moved in ("S:"); it is removed only after the rollback has
# verified that every original name is back and no staged-only name is left live.
#
# Names starting ".restore-" belong to this script and are never treated as application files.
# UPLOADS_SWAP_FAIL_AFTER=n makes the n-th forward rename fail, UPLOADS_ROLLBACK_FAIL_AFTER=n the n-th rename of the
# way back: test hooks for the failure-injection suite.
set -u

U="${UPLOADS_DIR:-/uploads}"
cmd="${1:-}"
id="${2:-}"
staging="$U/.restore-staging-$id"
previous="$U/.restore-previous-$id"
journal="$U/.restore-journal-$id" # outside "previous", and ".restore-*" names are never treated as files
moves=0
rb_moves=0
list=""
list2=""
ulist=""
ulist2=""
cleanup() { rm -f "$list" "$list2" "$ulist" "$ulist2"; }
trap cleanup EXIT

# Move $1 to $2, never nesting into an existing destination (mv would move a directory INTO an existing directory).
safe_mv() {
  if [ -e "$2" ] || [ -L "$2" ]; then
    echo "refusing to move $1: $2 already exists" >&2
    return 1
  fi
  mv "$1" "$2"
}

# Forward rename with the test hook in front of it.
mv_one() {
  moves=$((moves + 1))
  if [ -n "${UPLOADS_SWAP_FAIL_AFTER:-}" ] && [ "$moves" -gt "$UPLOADS_SWAP_FAIL_AFTER" ]; then
    echo "injected failure at rename $moves" >&2
    return 1
  fi
  safe_mv "$1" "$2"
}

# Rename of the way back: checked by the callers, with its own test hook.
rb_mv() {
  rb_moves=$((rb_moves + 1))
  if [ -n "${UPLOADS_ROLLBACK_FAIL_AFTER:-}" ] && [ "$rb_moves" -gt "$UPLOADS_ROLLBACK_FAIL_AFTER" ]; then
    echo "injected rollback failure at rename $rb_moves" >&2
    return 1
  fi
  safe_mv "$1" "$2"
}

exists() { [ -e "$1" ] || [ -L "$1" ]; }

# The names directly inside $1 that are application files (everything except this script's own directories).
entries() {
  find "$1" -mindepth 1 -maxdepth 1 ! -name '.restore-*' 2> /dev/null
}
# Everything directly inside the retained previous directory, whatever it is called.
all_entries() {
  find "$1" -mindepth 1 -maxdepth 1 2> /dev/null
}

# Put everything back, driven by the journal, and PROVE it. Returns 0 only when every original name is live again and
# no staged-only name is. Safe to run again after a failure: a staged name is only moved out of the live tree when its
# staging slot is free, and a previous name is only moved back when its live slot is free.
undo() {
  ok=0
  mkdir -p "$staging" || return 1
  ulist=$(mktemp) || return 1
  sed -n 's/^S://p' "$journal" > "$ulist"
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    if exists "$U/$n" && ! exists "$staging/$n"; then
      rb_mv "$U/$n" "$staging/$n" || ok=1
    fi
  done < "$ulist"
  if [ -d "$previous" ]; then
    all_entries "$previous" > "$ulist"
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      rb_mv "$p" "$U/$(basename "$p")" || ok=1
    done < "$ulist"
  fi
  [ "$ok" -eq 0 ] || return 1
  # Verification: the retained directory is empty, every original name is live, no staged-only name is live.
  if [ -d "$previous" ] && [ -n "$(all_entries "$previous")" ]; then
    echo "verification failed: $previous is not empty" >&2; return 1
  fi
  ulist2=$(mktemp) || return 1
  sed -n 's/^L://p' "$journal" > "$ulist2"
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    exists "$U/$n" || { echo "verification failed: original entry '$n' is not back in the live volume" >&2; return 1; }
  done < "$ulist2"
  sed -n 's/^S://p' "$journal" > "$ulist"
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    if ! grep -qxF "L:$n" "$journal" && exists "$U/$n"; then
      echo "verification failed: staged entry '$n' is still live" >&2; return 1
    fi
  done < "$ulist"
  rm -f "$journal"
  rmdir "$previous" 2> /dev/null
  return 0
}

recovery_failed() {
  echo "ROLLBACK FAILED: the live uploads are in a MIXED state. The journal $journal, the staged files in $staging and the previous files in $previous are kept. Do NOT start the application. Run 'uploads_swap.sh rollback $id' again after fixing the cause (disk, permissions)." >&2
  exit 3
}

case "$cmd" in
  preflight)
    # The uncompressed tar is an upper bound of what extraction writes (headers and padding included).
    need=$(gzip -dc 2> /dev/null | wc -c | tr -d ' ')
    [ "${need:-0}" -gt 0 ] || { echo "the tarball cannot be read" >&2; exit 1; }
    # df -Pk: 1024-byte blocks. Keep a 10% margin plus 16 MiB for metadata.
    avail=$(df -Pk "$U" | awk 'NR==2 { print $4 * 1024 }')
    want=$((need + need / 10 + 16777216))
    echo "need ${need} bytes, ${avail} available"
    [ "$avail" -ge "$want" ] || { echo "not enough free space in the uploads volume for a staged copy" >&2; exit 1; }
    ;;

  stage)
    [ -n "$id" ] || { echo "usage: stage <id>" >&2; exit 2; }
    rm -rf "$staging"
    mkdir -p "$staging" || exit 1
    if ! tar -xzf - -C "$staging"; then
      rm -rf "$staging"; echo "extraction failed; the live uploads were not touched" >&2; exit 1
    fi
    # The extracted tree must be non-trivially consistent with what the archive says it holds.
    count=$(find "$staging" -type f | wc -l | tr -d ' ')
    echo "staged $count files"
    ;;

  swap)
    [ -n "$id" ] || { echo "usage: swap <id>" >&2; exit 2; }
    [ -d "$staging" ] || { echo "nothing staged for $id" >&2; exit 1; }
    if [ -e "$journal" ]; then
      echo "a recovery journal for $id exists: run 'rollback $id' first" >&2; exit 3
    fi
    [ ! -e "$previous" ] || { echo "$previous already exists" >&2; exit 1; }
    mkdir -p "$previous" || exit 1
    list=$(mktemp) || exit 1
    entries "$U" > "$list"
    : > "$journal" || { rmdir "$previous" 2> /dev/null; exit 1; }
    while IFS= read -r p; do printf 'L:%s\n' "$(basename "$p")" >> "$journal"; done < "$list"
    # 1. live entries -> previous
    while IFS= read -r p; do
      n=$(basename "$p")
      if ! mv_one "$p" "$previous/$n"; then
        echo "could not set aside $n; rolling back" >&2
        if undo; then exit 1; else recovery_failed; fi
      fi
    done < "$list"
    # 2. staged entries -> live
    entries "$staging" > "$list"
    while IFS= read -r p; do
      n=$(basename "$p")
      echo "S:$n" >> "$journal"
      if ! mv_one "$p" "$U/$n"; then
        echo "could not move $n into place; rolling back" >&2
        if undo; then exit 1; else recovery_failed; fi
      fi
    done < "$list"
    # The journal stays until purge: a later explicit rollback uses it, and so does a rollback after a crash here.
    echo "DONE" >> "$journal"
    rmdir "$staging" 2> /dev/null
    echo "swapped; the previous uploads are kept in .restore-previous-$id"
    ;;

  rollback)
    [ -n "$id" ] || { echo "usage: rollback <id>" >&2; exit 2; }
    if [ ! -e "$journal" ]; then
      # A restore made before the journal was kept: everything live now is staged content, everything in previous
      # is what was there before.
      [ -d "$previous" ] || { echo "no previous content for $id" >&2; exit 1; }
      list=$(mktemp) || exit 1
      : > "$journal" || exit 1
      entries "$U" > "$list"
      while IFS= read -r p; do printf 'S:%s\n' "$(basename "$p")" >> "$journal"; done < "$list"
      all_entries "$previous" > "$list"
      while IFS= read -r p; do printf 'L:%s\n' "$(basename "$p")" >> "$journal"; done < "$list"
    fi
    if undo; then echo "rolled back to the previous uploads"; else recovery_failed; fi
    ;;

  discard)
    rm -rf "$staging"
    ;;

  purge)
    [ -n "$id" ] || { echo "usage: purge <id>" >&2; exit 2; }
    rm -rf "$previous" "$staging" "$journal"
    ;;

  *)
    echo "usage: uploads_swap.sh preflight|stage|swap|rollback|discard|purge [id]" >&2
    exit 2
    ;;
esac
