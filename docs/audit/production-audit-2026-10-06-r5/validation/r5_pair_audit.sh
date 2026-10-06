#!/usr/bin/env bash
# Audit-only model: a reference exists in the dump, then is deleted before tar.
# No database or Docker is used. Real backup.sh/reconcile_uploads.sh are exercised.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/uploads/public"
printf avatar > "$work/uploads/public/a.jpg"
printf 'public|/files/public/a.jpg\n' > "$work/live-refs"
cat > "$work/bin/pg_dump" <<'STUB'
#!/bin/sh
# Record the dump snapshot, then simulate a deletion committed after it.
printf 'DUMP-REFERENCE public|/files/public/a.jpg\n' > "$3"
head -c 2000 /dev/zero >> "$3"
rm -f "$AUDIT_ROOT/uploads/public/a.jpg"
: > "$AUDIT_ROOT/live-refs"
STUB
cat > "$work/bin/psql" <<'STUB'
#!/bin/sh
# Backup's unqualified query sees the later live database state.
cat "$AUDIT_ROOT/live-refs"
printf 'done|ok\n'
STUB
for name in createdb dropdb pg_restore; do printf '#!/bin/sh\nexit 0\n' > "$work/bin/$name"; done
chmod +x "$work/bin/"*
env PATH="$work/bin:$PATH" AUDIT_ROOT="$work" BACKUP_DIR="$work/out" UPLOADS_DIR="$work/uploads" BACKUP_ALLOW_UNENCRYPTED=1 RECONCILE_SCRIPT="$here/reconcile_uploads.sh" REFERENCES_SQL="$here/uploads_references.sql" sh "$here/backup.sh" once > "$work/log" 2>&1
dump=$(find "$work/out/db" -name '*.dump' | head -1)
archive=$(find "$work/out/uploads" -name '*.tar.gz' | head -1)
manifest=$(find "$work/out/manifest" -name '*.json' | head -1)
grep -aq 'DUMP-REFERENCE public|/files/public/a.jpg' "$dump"
if tar -tzf "$archive" | grep -q 'public/a.jpg'; then echo 'Unexpected: deleted file exists in archive'; exit 1; fi
grep -q '"reconcile":"ok"' "$manifest"
grep -q '"missing_references":0' "$manifest"
echo 'CONFIRMED: dump references a.jpg; archive lacks a.jpg; backup reports reconcile=ok and missing_references=0.'
cat "$manifest"
