#!/bin/sh
# Reconciles the database with the uploads volume (audit I-03). A database dump and an uploads tarball are two
# snapshots taken seconds or minutes apart while the app keeps writing, so a restored pair can disagree:
#   - missing: the database points at a file that is not in the volume (deleted between the two snapshots)
#   - orphan:  a file in the volume that nothing points at (uploaded after the dump; harmless)
# Backups take the dump FIRST and the tarball second on purpose: that order can only produce missing files for
# uploads deleted inside the window, never for ones created inside it, and orphans are harmless.
#
# Input (stdin): "kind|value" lines from uploads_references.sql. Output: a summary, and every missing file.
# Exit code is 0 either way: this is a report, restore.sh does not fail a restore over it.
# UPLOADS_DIR (default /uploads) is the volume root.
set -u
U="${UPLOADS_DIR:-/uploads}"
refs=$(mktemp) || exit 1
cat > "$refs"
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
  if [ ! -f "$U/$rel" ]; then
    echo "MISSING $kind $value"
    missing=$((missing + 1))
  fi
done < "$refs"

# orphans: files under public/ and private/ that no reference names
files=$(mktemp) || exit 1
( cd "$U" 2> /dev/null && find public private -type f 2> /dev/null ) | sort > "$files"
named=$(mktemp) || exit 1
while IFS='|' read -r kind value; do
  [ -n "${value:-}" ] || continue
  case "$kind" in public) echo "public/${value#/files/public/}" ;; private) echo "${value#uploads/}" ;; esac
done < "$refs" | sort > "$named"
orphans=$(comm -23 "$files" "$named" | wc -l | tr -d ' ')
rm -f "$refs" "$files" "$named"

echo "reconcile: $total database references checked, $missing missing, $orphans orphan files"
[ "$missing" -eq 0 ] || echo "WARNING: $missing referenced files are missing from the restored uploads; the matching images will not load until they are re-uploaded"
exit 0
