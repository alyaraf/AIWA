#!/usr/bin/env bash
# SA-04 test for the restore steps in restore.sh, on a real PostgreSQL in Docker:
#   bash deploy/restore_test.sh
# A dump whose table of contents is intact but whose payload is cut off passes `pg_restore --list`.
# This shows that (1) restoring it into a scratch database fails, so restore.sh stops before touching
# the live database, and (2) even a live restore of it, run as restore.sh does it (one transaction,
# exit on first error), rolls back and leaves the live rows in place.
set -u
img="${PG_IMAGE:-postgres:16-alpine}"
name="restore-test-$$"
pass=0; failed=0
check() { if eval "$2"; then pass=$((pass+1)); echo "ok   $1"; else failed=$((failed+1)); echo "FAIL $1"; fi; }
cleanup() { docker rm -f "$name" > /dev/null 2>&1; }
trap cleanup EXIT

docker run -d --name "$name" -e POSTGRES_PASSWORD=t -e POSTGRES_USER=aiwa -e POSTGRES_DB=live "$img" > /dev/null || exit 1
for _ in $(seq 1 40); do docker exec "$name" pg_isready -U aiwa -d live > /dev/null 2>&1 && break; sleep 1; done
sleep 2
q() { docker exec -i "$name" psql -U aiwa -d "${DB:-live}" -tA "$@"; }

q -c "create table t (id int primary key, pad text); insert into t select g, md5(g::text) from generate_series(1,10000) g; create table sentinel (v text); insert into sentinel values ('live');" > /dev/null
docker exec "$name" pg_dump -U aiwa -Fc live > /tmp/restore-test-good.dump
size=$(wc -c < /tmp/restore-test-good.dump | tr -d ' ')
head -c $((size * 3 / 4)) /tmp/restore-test-good.dump > /tmp/restore-test-cut.dump

check "the cut dump still passes pg_restore --list" 'docker exec -i "$name" pg_restore --list < /tmp/restore-test-cut.dump > /dev/null'

docker exec "$name" createdb -U aiwa scratch
check "restoring the cut dump into a scratch database fails" '! docker exec -i "$name" pg_restore --no-owner --exit-on-error -U aiwa -d scratch < /tmp/restore-test-cut.dump > /dev/null 2>&1'
docker exec "$name" dropdb -U aiwa --if-exists scratch

check "the live restore of the cut dump fails" '! docker exec -i "$name" pg_restore --clean --if-exists --no-owner --single-transaction --exit-on-error -U aiwa -d live < /tmp/restore-test-cut.dump > /dev/null 2>&1'
check "and the live rows and sentinel are still there" '[ "$(q -c "select count(*) from t")" = 10000 ] && [ "$(q -c "select v from sentinel")" = live ]'

docker exec "$name" createdb -U aiwa scratch2
check "the intact dump restores into a scratch database" 'docker exec -i "$name" pg_restore --no-owner --exit-on-error -U aiwa -d scratch2 < /tmp/restore-test-good.dump > /dev/null 2>&1'
check "the intact dump restores over the live database" 'docker exec -i "$name" pg_restore --clean --if-exists --no-owner --single-transaction --exit-on-error -U aiwa -d live < /tmp/restore-test-good.dump > /dev/null 2>&1'
check "and the live rows are back" '[ "$(q -c "select count(*) from t")" = 10000 ]'

rm -f /tmp/restore-test-good.dump /tmp/restore-test-cut.dump
echo "$pass passed, $failed failed"
[ "$failed" -eq 0 ]
