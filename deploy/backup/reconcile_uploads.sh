#!/bin/sh
# Reconciles the database with the uploads volume (audit I-03). A database dump and an uploads tarball are two
# snapshots taken seconds or minutes apart while the app keeps writing, so a restored pair can disagree:
#   - missing: the database points at a file that is not in the volume (deleted between the two snapshots)
#   - orphan:  a file in the volume that nothing points at (uploaded after the dump; harmless)
# Backups take the dump FIRST and the tarball second on purpose: that order can only produce missing files for
# uploads deleted inside the window, never for ones created inside it, and orphans are harmless.
#
# Input (stdin): "kind|value" lines from uploads_references.sql, ending with the terminator line "done|ok". backup.sh
# feeds it the references read from the scratch restore of the dump being archived (R5-02), restore.sh the restored
# database's; never the references of a live database that has moved on since the dump.
# Output: a summary, and every missing file.
# Exit code: 0 the scan COMPLETED (missing files are reported, not fatal: restore.sh does not fail a restore over
# them); 2 the scan did NOT complete (the input has no terminator because the reference query failed or was cut off).
# A failed scan prints "RECONCILE FAILED" and never a "0 missing" summary, so it cannot be read as a clean result.
# UPLOADS_DIR (default /uploads) is the volume root. RECONCILE_FILE_LIST=<file>: check against that list of relative
# paths (one per line, e.g. "tar -tzf" output without "./") instead of the volume, to check a backup tarball.
set -u
U="${UPLOADS_DIR:-/uploads}"
LIST="${RECONCILE_FILE_LIST:-}"
refs=$(mktemp) || exit 2
cat > "$refs"
if ! grep -qx 'done|ok' "$refs"; then
  rm -f "$refs"
  echo "RECONCILE FAILED: the list of file references is incomplete (no terminator: the database query failed or was cut off). No result can be trusted."
  exit 2
fi
present() {
  if [ -n "$LIST" ]; then grep -qxF "$1" "$LIST"; else [ -f "$U/$1" ]; fi
}
missing=0
total=0
while IFS='|' read -r kind value; do
  [ -n "${value:-}" ] || continue
  case "$kind" in
    public) rel="public/${value#/files/public/}" ;;
    private) rel="${value#uploads/}" ;;
    *) continue ;;
  esac
  case "$rel" in *..*) echo "MISSING (suspicious path) $value"; missing=$((missing + 1)); total=$((total + 1)); continue ;; esac
  total=$((total + 1))
  if ! present "$rel"; then
    echo "MISSING $kind $value"
    missing=$((missing + 1))
  fi
done < "$refs"

# orphans: files under public/ and private/ that no reference names
files=$(mktemp) || exit 2
if [ -n "$LIST" ]; then
  grep -E '^(public|private)/' "$LIST" | sort > "$files"
else
  ( cd "$U" 2> /dev/null && find public private -type f 2> /dev/null ) | sort > "$files"
fi
named=$(mktemp) || exit 2
while IFS='|' read -r kind value; do
  [ -n "${value:-}" ] || continue
  case "$kind" in public) echo "public/${value#/files/public/}" ;; private) echo "${value#uploads/}" ;; esac
done < "$refs" | sort > "$named"
orphans=$(comm -23 "$files" "$named" | wc -l | tr -d ' ')
rm -f "$refs" "$files" "$named"

echo "reconcile: $total database references checked, $missing missing, $orphans orphan files"
[ "$missing" -eq 0 ] || echo "WARNING: $missing referenced files are missing from the restored uploads; the matching images will not load until they are re-uploaded"
exit 0
