#!/usr/bin/env bash
set -eu
source_deploy=${1:?pass the project deploy.sh}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/deploy/backups/db"
cp "$source_deploy" "$work/deploy/deploy.sh"
cat > "$work/bin/git" <<'FAKE'
#!/usr/bin/env bash
case "$1" in
  rev-parse) cat "$AUDIT_HEAD" ;;
  checkout) for arg; do target=$arg; done; printf '%s\n' "$target" > "$AUDIT_HEAD" ;;
esac
FAKE
cat > "$work/bin/docker" <<'FAKE'
#!/usr/bin/env bash
shift 3
case "$1" in
  ps) echo fake-running-postgres ;;
  run) sleep 1; touch "backups/db/aiwa-$(date -u +%Y%m%d-%H%M%S).dump.enc" ;;
  up)
    printf 'up tag=%s args=%s\n' "$RELEASE_TAG" "$*" >> "$AUDIT_CALLS"
    if [[ "$*" == *--build* ]]; then exit 1; fi
    ;;
esac
FAKE
chmod +x "$work/bin/git" "$work/bin/docker"
export PATH="$work/bin:$PATH" AUDIT_HEAD="$work/head" AUDIT_CALLS="$work/calls"
printf 'good-A\n' > "$AUDIT_HEAD"
printf '2026-10-01T00:00:00Z good-A a.dump.enc\n' > "$work/deploy/backups/releases.log"
printf 'bad-B\n' > "$AUDIT_HEAD"
if bash "$work/deploy/deploy.sh"; then echo 'unexpected success'; exit 1; fi
if bash "$work/deploy/deploy.sh"; then echo 'unexpected success'; exit 1; fi
bash "$work/deploy/deploy.sh" --rollback
printf '\nRelease log after two failed deploys and rollback:\n'
cat "$work/deploy/backups/releases.log"
printf '\nCompose calls:\n'
cat "$AUDIT_CALLS"
actual=$(cat "$AUDIT_HEAD")
test "$actual" = bad-B
echo 'DEFECT REPRODUCED: automatic rollback selected failed bad-B, not last good good-A.'
