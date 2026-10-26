#!/usr/bin/env bash
# deploy.sh with a fake docker and git (no containers needed):  bash deploy/deploy_test.sh
# Proves RV-03: no deploy without a verified pre-deploy dump, every deploy is recorded, and a rollback starts the
# previous release from existing images without building, backing up or touching the database.
# A24-03: the automatic rollback target is the last KNOWN-GOOD release (releases.good, written only once a release
# started), never the preceding attempt: after repeated failed attempts at B it still goes back to A.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
pass=0; failed=0
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else failed=$((failed+1)); echo "FAIL $1"; fi; }
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin"
cat > "$work/bin/docker" <<'FAKE'
#!/bin/sh
# docker image inspect <name>   |   docker compose -f <file> <verb> ...
if [ "$1" = image ]; then
  echo "image $* " >> "$FAKE_LOG"
  [ -n "${FAKE_IMAGE_MISSING:-}" ] && exit 1
  exit 0
fi
shift; shift; shift
verb="$1"; shift
echo "$verb $* tag=${RELEASE_TAG:-}" >> "$FAKE_LOG"
case "$verb" in
  config) printf 'aiwa-backend:%s\npostgres:16.15-alpine\naiwa-admin:%s\n' "${RELEASE_TAG:-local}" "${RELEASE_TAG:-local}"; exit 0 ;;
  ps)  [ -n "${FAKE_PG_DOWN:-}" ] || echo 3f2a1b; exit 0 ;;
  run) [ -n "${FAKE_BACKUP_FAILS:-}" ] && exit 1
       [ -n "${FAKE_BACKUP_NO_FILE:-}" ] && exit 0
       sleep 1; touch "backups/db/aiwa-$(date -u +%Y%m%d-%H%M%S).dump.enc"; exit 0 ;;
  up)  [ -n "${FAKE_UP_FAILS:-}" ] && exit 1; exit 0 ;;
esac
FAKE
cat > "$work/bin/git" <<'FAKE'
#!/bin/sh
echo "git $*" >> "$FAKE_LOG"
case "$1" in
  rev-parse) cat "$FAKE_HEAD"; exit 0 ;;
  checkout)  for a; do t="$a"; done; echo "$t" > "$FAKE_HEAD"; exit 0 ;;
esac
FAKE
chmod +x "$work/bin/docker" "$work/bin/git"

# A fresh copy of deploy/ per case, so backups/ and releases.log start as each case says.
setup() {
  rm -rf "$work/d"; mkdir -p "$work/d/backups/db"; cp "$here/deploy.sh" "$work/d/"
  : > "$work/log"; echo "${1:-bbb}" > "$work/head"
}
run() { PATH="$work/bin:$PATH" FAKE_LOG="$work/log" FAKE_HEAD="$work/head" bash "$work/d/deploy.sh" "$@" > "$work/out" 2>&1; }
order() { grep -n "$1" "$work/log" | head -n 1 | cut -d: -f1; }
rel="$work/d/backups/releases.log"
good="$work/d/backups/releases.good"

setup bbb; echo "2026-10-01T00:00:00Z aaa backups/db/aiwa-old.dump.enc" > "$rel"
run; rc=$?
check "deploy: exits 0" '[ $rc = 0 ]'
check "deploy: backup runs before up" '[ -n "$(order "^run --rm -T backup once")" ] && [ "$(order "^run")" -lt "$(order "^up -d --build")" ]'
check "deploy: built and started with the checked-out sha" 'grep -q "^up -d --build --remove-orphans tag=bbb" "$work/log"'
check "deploy: release recorded with its new dump" 'tail -n 1 "$rel" | grep -Eq " bbb backups/db/aiwa-[0-9]{8}-[0-9]{6}\.dump\.enc$"'
check "deploy: a release that started is recorded as known-good" 'tail -n 1 "$good" | grep -Eq "^[^ ]+ bbb$"'

setup bbb; echo "2026-10-01T00:00:00Z aaa x" > "$rel"
FAKE_BACKUP_FAILS=1 run; rc=$?
check "backup fails: refused" '[ $rc != 0 ] && grep -q "DEPLOY REFUSED" "$work/out"'
check "backup fails: nothing started" '! grep -q "^up" "$work/log"'
check "backup fails: not recorded" '[ "$(wc -l < "$rel")" = 1 ]'

setup bbb; echo "2026-10-01T00:00:00Z aaa x" > "$rel"
FAKE_BACKUP_NO_FILE=1 run; rc=$?
check "backup writes no dump: refused" '[ $rc != 0 ] && ! grep -q "^up" "$work/log"'

setup bbb; echo "2026-10-01T00:00:00Z aaa x" > "$rel"
FAKE_PG_DOWN=1 run; rc=$?
check "postgres down on a used host: refused" '[ $rc != 0 ] && ! grep -q "^up" "$work/log" && ! grep -q "^run" "$work/log"'

setup bbb
FAKE_PG_DOWN=1 run; rc=$?
check "first deploy: no backup, started, recorded" '[ $rc = 0 ] && ! grep -q "^run" "$work/log" && grep -q "^up -d --build" "$work/log" && grep -q " bbb none$" "$rel"'

setup bbb; echo "2026-10-01T00:00:00Z aaa x" > "$rel"
FAKE_UP_FAILS=1 run; rc=$?
check "up fails: non-zero, recorded, rollback hint" '[ $rc != 0 ] && tail -n 1 "$rel" | grep -q " bbb " && grep -q "deploy.sh --rollback" "$work/out"'
check "up fails: the failed attempt is NOT known-good" '[ ! -f "$good" ] || ! grep -q " bbb$" "$good"'

setup bbb; printf '2026-10-01T00:00:00Z aaa a.dump\n2026-10-02T00:00:00Z bbb b.dump\n' > "$rel"
printf '2026-10-01T00:00:01Z aaa\n2026-10-02T00:00:01Z bbb\n' > "$good"
run --rollback; rc=$?
check "rollback: exits 0" '[ $rc = 0 ]'
check "rollback: checks out the previous release" 'grep -q "^git checkout --quiet --detach aaa" "$work/log"'
check "rollback: starts it without building" 'grep -q "^up -d --no-build --remove-orphans tag=aaa" "$work/log" && ! grep -q -- "--build " "$work/log"'
check "rollback: no backup, no database work" '! grep -q "^run" "$work/log"'
check "rollback: recorded" 'tail -n 1 "$rel" | grep -q " aaa rollback$"'
check "rollback: the release it started is known-good" 'tail -n 1 "$good" | grep -q " aaa$"'

setup aaa; printf '2026-10-01T00:00:00Z aaa a.dump\n2026-10-02T00:00:00Z bbb b.dump\n2026-10-03T00:00:00Z aaa rollback\n' > "$rel"
printf 'x aaa\nx bbb\nx aaa\n' > "$good"
run --rollback; rc=$?
check "AP-04: a second rollback in a row is refused, not a return to the bad release" '[ $rc != 0 ] && grep -q "already a rollback" "$work/out" && ! grep -q "^up" "$work/log" && [ "$(wc -l < "$rel")" = 3 ]'

setup aaa; printf 'x aaa a\nx bbb b\nx aaa rollback\nx ccc c\n' > "$rel"
printf 'x aaa\nx bbb\nx aaa\nx ccc\n' > "$good"
run --rollback; rc=$?
check "AP-04: a deploy after a rollback rolls back to the rolled-back-to release" '[ $rc = 0 ] && grep -q "^up -d --no-build --remove-orphans tag=aaa" "$work/log"'

setup aaa; printf 'x aaa a\nx bbb b\nx aaa rollback\n' > "$rel"
run --rollback 9999fff; rc=$?
check "AP-04: after a rollback an explicit sha still works" '[ $rc = 0 ] && grep -q "^up -d --no-build --remove-orphans tag=9999fff" "$work/log"'

setup bbb; echo "2026-10-02T00:00:00Z bbb b.dump" > "$rel"; echo "x bbb" > "$good"
run --rollback; rc=$?
check "rollback with one release: refused" '[ $rc != 0 ] && ! grep -q "^up" "$work/log" && ! grep -q "^git checkout" "$work/log"'

setup bbb; echo "2026-10-02T00:00:00Z bbb b.dump" > "$rel"
run --rollback 1234abc; rc=$?
check "rollback to a given sha" '[ $rc = 0 ] && grep -q "^up -d --no-build --remove-orphans tag=1234abc" "$work/log"'

setup bbb; printf 'x aaa a\nx bbb b\n' > "$rel"; printf 'x aaa\nx bbb\n' > "$good"
FAKE_UP_FAILS=1 run --rollback; rc=$?
check "rollback start fails: fails, not recorded anywhere" '[ $rc != 0 ] && grep -q "ROLLBACK FAILED" "$work/out" && [ "$(wc -l < "$rel")" = 2 ] && [ "$(wc -l < "$good")" = 2 ]'

# ---- A24-03: the target is a known-good release, not the preceding attempt --------------------------------------
setup aaa; echo "2026-10-01T00:00:00Z aaa a.dump" > "$rel"; echo "2026-10-01T00:00:01Z aaa" > "$good"
echo bbb > "$work/head"; FAKE_UP_FAILS=1 run; rc1=$?
FAKE_UP_FAILS=1 run; rc2=$?
check "A24-03: A ok, B fails twice: both attempts stay on record, with their backups" '[ $rc1 != 0 ] && [ $rc2 != 0 ] && [ "$(wc -l < "$rel")" = 3 ] && [ "$(grep -c " bbb backups/db/" "$rel")" = 2 ] && [ "$(grep -c "^run" "$work/log")" = 2 ]'
check "A24-03: failed attempts are not known-good" '[ "$(wc -l < "$good")" = 1 ] && ! grep -q bbb "$good"'
: > "$work/log"
run --rollback; rc=$?
check "A24-03: A ok, B fails twice: rollback selects A" '[ $rc = 0 ] && grep -q "^git checkout --quiet --detach aaa" "$work/log" && [ "$(cat "$work/head")" = aaa ]'
check "A24-03: rollback starts A without building or backing up" 'grep -q "^up -d --no-build --remove-orphans tag=aaa" "$work/log" && ! grep -q -- "--build " "$work/log" && ! grep -q "^run" "$work/log"'
run --rollback; rc=$?
check "A24-03: then a second rollback in a row is still refused" '[ $rc != 0 ] && grep -q "already a rollback" "$work/out"'

setup aaa; echo "2026-10-01T00:00:00Z aaa a.dump" > "$rel"; echo "2026-10-01T00:00:01Z aaa" > "$good"
echo bbb > "$work/head"; FAKE_UP_FAILS=1 run
echo ccc > "$work/head"; FAKE_UP_FAILS=1 run
: > "$work/log"
run --rollback; rc=$?
check "A24-03: A ok, B fails, C fails: rollback selects A" '[ $rc = 0 ] && grep -q "^up -d --no-build --remove-orphans tag=aaa" "$work/log" && ! grep -q "tag=bbb\|tag=ccc" "$work/log"'

setup aaa; echo "2026-10-01T00:00:00Z aaa a.dump" > "$rel"; echo "2026-10-01T00:00:01Z aaa" > "$good"
echo bbb > "$work/head"; run
echo ccc > "$work/head"; FAKE_UP_FAILS=1 run
: > "$work/log"
run --rollback; rc=$?
check "A24-03: A ok, B ok, C fails: rollback selects B, the last good one" '[ $rc = 0 ] && grep -q "^up -d --no-build --remove-orphans tag=bbb" "$work/log"'

setup aaa; echo "2026-10-01T00:00:00Z aaa a.dump" > "$rel"; echo "2026-10-01T00:00:01Z aaa" > "$good"
echo bbb > "$work/head"; run; run
: > "$work/log"
run --rollback; rc=$?
check "A24-03: the same sha deployed twice is still one release: rollback selects A" '[ $rc = 0 ] && grep -q "^up -d --no-build --remove-orphans tag=aaa" "$work/log"'

setup aaa; echo "2026-10-01T00:00:00Z aaa a.dump" > "$rel"; echo "2026-10-01T00:00:01Z aaa" > "$good"
echo bbb > "$work/head"; FAKE_UP_FAILS=1 run; run
: > "$work/log"
run --rollback; rc=$?
check "A24-03: B fails then succeeds: rollback selects A" '[ $rc = 0 ] && grep -q "^up -d --no-build --remove-orphans tag=aaa" "$work/log"'

setup bbb; printf '2026-10-01T00:00:00Z aaa a.dump\n2026-10-02T00:00:00Z bbb b.dump\n' > "$rel"
run --rollback; rc=$?
check "A24-03: history with no known-good record is not guessed from: refused, nothing changed" '[ $rc != 0 ] && grep -q "no known-good release" "$work/out" && ! grep -q "^up" "$work/log" && ! grep -q "^git checkout" "$work/log" && [ "$(wc -l < "$rel")" = 2 ]'

setup bbb; printf '2026-10-01T00:00:00Z aaa a.dump\n2026-10-02T00:00:00Z bbb b.dump\n' > "$rel"; echo "x bbb" > "$good"
run --rollback; rc=$?
check "A24-03: the only known-good release is the current one: refused" '[ $rc != 0 ] && grep -q "no known-good release" "$work/out" && ! grep -q "^up" "$work/log"'

setup bbb; printf 'x aaa a\nx bbb b\n' > "$rel"; printf 'x aaa\nx bbb\n' > "$good"
FAKE_IMAGE_MISSING=1 run --rollback; rc=$?
check "A24-03: the target's image is missing: refused before the checkout or any start" '[ $rc != 0 ] && grep -q "ROLLBACK REFUSED: image aiwa-backend:aaa" "$work/out" && ! grep -q "^git checkout" "$work/log" && ! grep -q "^up" "$work/log" && [ "$(cat "$work/head")" = bbb ] && [ "$(wc -l < "$rel")" = 2 ]'

setup bbb; printf 'x aaa a\nx bbb b\n' > "$rel"; printf 'x aaa\nx bbb\n' > "$good"
FAKE_IMAGE_MISSING=1 run --rollback 1234abc; rc=$?
check "A24-03: an explicit sha with a missing image is refused too" '[ $rc != 0 ] && grep -q "ROLLBACK REFUSED: image" "$work/out" && ! grep -q "^up" "$work/log"'

echo "$pass passed, $failed failed"
[ "$failed" = 0 ]
