#!/usr/bin/env bash
# Deploy or roll back the stack (RV-03). Run from the server checkout (/srv/aiwa), after checking out the commit:
#
#   git fetch origin && git checkout --detach <sha> && bash deploy/deploy.sh
#                         backs up the database first (backup.sh once, verified and encrypted like the nightly
#                         one), records the release, then builds and starts that commit. No backup, no deploy.
#   bash deploy/deploy.sh --rollback [<sha>]
#                         starts the last KNOWN-GOOD release other than the current one (or <sha>) from the images
#                         already on this host: no build, no backup, the database is NOT touched. docs/release.md
#                         "Releasing and rolling back" says when the code alone can go back and when the database
#                         must too.
#
# backups/releases.log (git-ignored, beside the backups) has one line per deploy ATTEMPT: <utc time> <sha> <pre-deploy
# dump>, written before the build, so failed attempts stay on record. backups/releases.good has one line
# "<utc time> <sha>" per release that was actually started (A24-03): the only source of an automatic rollback target.
# A release that failed, or one that only appears in an older log (nothing proves it ran), is never a target.
# The whole script is one function, so a rollback's own "git checkout" can't change the lines bash is still reading.
set -u

main() {
  cd "$(dirname "$0")" || exit 1
  local log=backups/releases.log good=backups/releases.good
  dc() { docker compose -f docker-compose.prod.yml "$@"; }

  if [ "${1:-}" = --rollback ]; then
    local target="${2:-}"
    if [ -z "$target" ]; then
      [ -f "$log" ] && [ -s "$log" ] \
        || { echo "ROLLBACK REFUSED: $log has no release; pass the sha: bash deploy/deploy.sh --rollback <sha>" >&2; return 1; }
      # AP-04: right after a rollback the line before the last is the release just rolled back from, so a second
      # "--rollback" would start the bad release again. Going further back needs the sha.
      if tail -n 1 "$log" | grep -q ' rollback$'; then
        echo "ROLLBACK REFUSED: the last action was already a rollback (to $(tail -n 1 "$log" | awk '{print $2}')); to go further back pass the sha: bash deploy/deploy.sh --rollback <sha>" >&2
        return 1
      fi
      # A24-03: the current release is the last thing the log says was started or attempted. The target is the most
      # recent release that really ran and is a different one, so repeated failed attempts at B still lead back to A.
      local current
      current=$(tail -n 1 "$log" | awk '{print $2}')
      target=""
      [ -f "$good" ] && target=$(awk -v cur="$current" '$2 != "" && $2 != cur {t = $2} END {print t}' "$good")
      if [ -z "$target" ]; then
        echo "ROLLBACK REFUSED: no known-good release other than $current is recorded in $good (a release counts once it has been started; older history is not trusted); pass the sha: bash deploy/deploy.sh --rollback <sha>" >&2
        return 1
      fi
    fi
    # The images must already be on this host: a rollback never builds. Refuse before touching the checkout.
    local img
    while read -r img; do
      case "$img" in *":$target") ;; *) continue ;; esac
      docker image inspect "$img" > /dev/null 2>&1 || {
        echo "ROLLBACK REFUSED: image $img is not on this host, so $target cannot start without a build. Rebuild it with: git checkout --detach $target && bash deploy/deploy.sh (it backs up first)" >&2
        return 1
      }
    done < <(RELEASE_TAG="$target" dc config --images 2> /dev/null)
    echo "Rolling back to $target (code only, the database is not touched)"
    git checkout --quiet --detach "$target" || return 1
    if ! RELEASE_TAG="$target" dc up -d --no-build --remove-orphans; then
      echo "ROLLBACK FAILED: the images of $target are not on this host. Rebuild them with: bash deploy/deploy.sh (it backs up first)" >&2
      return 1
    fi
    echo "$(date -u +%FT%TZ) $target rollback" >> "$log"
    echo "$(date -u +%FT%TZ) $target" >> "$good"
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

  # Recorded before "up" so a failed attempt stays on record with its pre-deploy dump. Only a release that started
  # is added to $good (A24-03), so --rollback goes back to a release that ran, however many attempts failed since.
  echo "$(date -u +%FT%TZ) $sha $dump" >> "$log"
  if ! RELEASE_TAG="$sha" dc up -d --build --remove-orphans; then
    echo "DEPLOY FAILED while starting $sha. Go back with: bash deploy/deploy.sh --rollback" >&2
    return 1
  fi
  echo "$(date -u +%FT%TZ) $sha" >> "$good"
  echo "Deployed $sha (pre-deploy dump: $dump). Check /api/actuator/health; to go back: bash deploy/deploy.sh --rollback"
}

main "$@"
exit $?
