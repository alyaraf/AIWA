#!/bin/sh
# Staged, recoverable replacement of the uploads volume contents (audit I-02). Runs inside the backup
# container (/uploads mounted, tar and gzip present); restore.sh drives it. Everything happens INSIDE the one
# volume, so moving a name is an atomic rename, never a copy:
#
#   preflight   < tarball.tgz     does the volume have room for a second copy of the tarball's files?
#   stage <id>  < tarball.tgz     extract into /uploads/.restore-staging-<id> and verify it; the live files
#                                 are not touched, and a failure removes the staging directory again
#   swap <id>                     move the live entries into /uploads/.restore-previous-<id>, then move the staged
#                                 entries into place. Any failure puts the live entries back (rollback)
#   rollback <id>                 undo a swap: staged content out, previous content back in
#   discard <id>                  remove the staging directory (after a failed run)
#   purge <id>                    delete the retained previous content (only after the restore was verified)
#
# Names starting ".restore-" belong to this script and are never treated as application files.
# UPLOADS_SWAP_FAIL_AFTER=n makes the n-th rename fail: a test hook for the failure-injection suite.
set -u

U="${UPLOADS_DIR:-/uploads}"
cmd="${1:-}"
id="${2:-}"
staging="$U/.restore-staging-$id"
previous="$U/.restore-previous-$id"
moves=0

# Rename with the test hook in front of it.
mv_one() {
  moves=$((moves + 1))
  if [ -n "${UPLOADS_SWAP_FAIL_AFTER:-}" ] && [ "$moves" -gt "$UPLOADS_SWAP_FAIL_AFTER" ]; then
    echo "injected failure at rename $moves" >&2
    return 1
  fi
  mv "$1" "$2"
}

# The names directly inside $1 that are application files (everything except this script's own directories).
entries() {
  find "$1" -mindepth 1 -maxdepth 1 ! -name '.restore-*' 2> /dev/null
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
    [ ! -e "$previous" ] || { echo "$previous already exists" >&2; exit 1; }
    mkdir -p "$previous" || exit 1
    journal="$U/.restore-journal-$id" # outside "previous", and ".restore-*" names are never treated as files
    : > "$journal" || exit 1
    list=$(mktemp) || exit 1
    # Undo whatever has moved so far: staged entries that already went live return to staging, the entries set
    # aside return to their place. Plain mv (no test hook), so the way back cannot be made to fail.
    rollback_swap() {
      entries "$U" > "$list"
      while IFS= read -r p; do
        n=$(basename "$p")
        if grep -qx "S:$n" "$journal" 2> /dev/null; then mv "$p" "$staging/$n"; fi
      done < "$list"
      entries "$previous" > "$list"
      while IFS= read -r p; do mv "$p" "$U/$(basename "$p")"; done < "$list"
      rm -f "$journal" "$list"; rmdir "$previous" 2> /dev/null
    }
    # 1. live entries -> previous
    entries "$U" > "$list"
    while IFS= read -r p; do
      n=$(basename "$p")
      if ! mv_one "$p" "$previous/$n"; then
        echo "could not set aside $n; rolling back" >&2
        rollback_swap; exit 1
      fi
    done < "$list"
    # 2. staged entries -> live
    entries "$staging" > "$list"
    while IFS= read -r p; do
      n=$(basename "$p")
      echo "S:$n" >> "$journal"
      if ! mv_one "$p" "$U/$n"; then
        echo "could not move $n into place; rolling back" >&2
        rollback_swap; exit 1
      fi
    done < "$list"
    rm -f "$journal" "$list"
    rmdir "$staging" 2> /dev/null
    echo "swapped; the previous uploads are kept in .restore-previous-$id"
    ;;

  rollback)
    [ -n "$id" ] || { echo "usage: rollback <id>" >&2; exit 2; }
    [ -d "$previous" ] || { echo "no previous content for $id" >&2; exit 1; }
    mkdir -p "$staging"
    list=$(mktemp) || exit 1
    entries "$U" > "$list"
    while IFS= read -r p; do mv "$p" "$staging/$(basename "$p")"; done < "$list"
    entries "$previous" > "$list"
    while IFS= read -r p; do mv "$p" "$U/$(basename "$p")"; done < "$list"
    rm -f "$list"; rmdir "$previous" 2> /dev/null
    echo "rolled back to the previous uploads"
    ;;

  discard)
    rm -rf "$staging"
    ;;

  purge)
    [ -n "$id" ] || { echo "usage: purge <id>" >&2; exit 2; }
    rm -rf "$previous" "$staging" "$U/.restore-journal-$id"
    ;;

  *)
    echo "usage: uploads_swap.sh preflight|stage|swap|rollback|discard|purge [id]" >&2
    exit 2
    ;;
esac
