#!/usr/bin/env bash
# Deploy or roll back the stack (RV-03). Run from the server checkout (/srv/aiwa), after checking out the commit:
#
#   git fetch origin && git checkout --detach <sha> && bash deploy/deploy.sh
#                         backs up the database first (backup.sh once, verified and encrypted like the nightly
#                         one), records the release, then builds and starts that commit. No backup, no deploy.
#   bash deploy/deploy.sh --rollback [<sha>]
#                         starts the release before the last one (or <sha>) from the images already on this host:
#                         no build, no backup, the database is NOT touched. docs/release.md "Releasing and
#                         rolling back" says when the code alone can go back and when the database must too.
#
# backups/releases.log (git-ignored, beside the backups) has one line per deploy: <utc time> <sha> <pre-deploy dump>.
# The whole script is one function, so a rollback's own "git checkout" can't change the lines bash is still reading.
set -u

main() {
  cd "$(dirname "$0")" || exit 1
  local log=backups/releases.log
  dc() { docker compose -f docker-compose.prod.yml "$@"; }

  if [ "${1:-}" = --rollback ]; then
    local target="${2:-}"
    if [ -z "$target" ]; then
      [ -f "$log" ] && [ "$(wc -l < "$log")" -ge 2 ] \
        || { echo "ROLLBACK REFUSED: $log has no earlier release; pass the sha: bash deploy/deploy.sh --rollback <sha>" >&2; return 1; }
      target=$(tail -n 2 "$log" | head -n 1 | awk '{print $2}')
    fi
    echo "Rolling back to $target (code only, the database is not touched)"
    git checkout --quiet --detach "$target" || return 1
    if ! RELEASE_TAG="$target" dc up -d --no-build --remove-orphans; then
      echo "ROLLBACK FAILED: the images of $target are not on this host. Rebuild them with: bash deploy/deploy.sh (it backs up first)" >&2
      return 1
    fi
    echo "$(date -u +%FT%TZ) $target rollback" >> "$log"
    echo "Rolled back to $target. If it can't run on the newer schema, restore that release's pre-deploy dump: see docs/release.md"
    return 0
  fi

  local sha dump=none
  sha=$(git rev-parse HEAD) || return 1
  mkdir -p backups/db
  if [ -n "$(dc ps --status running --quiet postgres 2> /dev/null)" ]; then
    local before after
    before=$(ls -t backups/db/aiwa-*.dump* 2> /dev/null | head -n 1)
    echo "Pre-deploy backup of the live database"
    if ! RELEASE_TAG="$sha" dc run --rm -T backup once; then
      echo "DEPLOY REFUSED: the pre-deploy backup failed (BACKUP FAILED above); nothing was changed" >&2
      return 1
    fi
    after=$(ls -t backups/db/aiwa-*.dump* 2> /dev/null | head -n 1)
    [ -n "$after" ] && [ "$after" != "$before" ] \
      || { echo "DEPLOY REFUSED: the backup reported success but wrote no new dump in backups/db" >&2; return 1; }
    dump="$after"
  elif [ -f "$log" ]; then
    echo "DEPLOY REFUSED: postgres is not running, so the live database can't be backed up first. Start it: docker compose -f docker-compose.prod.yml up -d postgres" >&2
    return 1
  else
    echo "First deploy on this host (no $log, postgres not running): nothing to back up yet"
  fi

  # Recorded before "up", so a release that fails half way is the one --rollback steps back from.
  echo "$(date -u +%FT%TZ) $sha $dump" >> "$log"
  if ! RELEASE_TAG="$sha" dc up -d --build --remove-orphans; then
    echo "DEPLOY FAILED while starting $sha. Go back with: bash deploy/deploy.sh --rollback" >&2
    return 1
  fi
  echo "Deployed $sha (pre-deploy dump: $dump). Check /api/actuator/health; to go back: bash deploy/deploy.sh --rollback"
}

main "$@"
exit $?
