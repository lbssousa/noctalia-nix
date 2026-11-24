#!/usr/bin/env bash
# sync-fork.sh — rebase the nix-config branch of a fork onto the newest
# upstream base.
#
#   scripts/sync-fork.sh <fork owner/repo> <upstream owner/repo> <tag|main>
#
#   tag   the base is the newest upstream release tag (v*, by version order)
#   main  the base is the upstream main branch
#
# Exit status: 0 up to date or rebased and pushed; 2 rebase conflict (the
# branch is left untouched; details in $SYNC_REPORT); 1 other errors.
#
# Environment:
#   GH_TOKEN      token with contents:write on the fork (optional for --dry-run)
#   SYNC_WORKDIR  scratch directory (default: a new temporary directory)
#   SYNC_REPORT   file that receives a Markdown report (default: stdout)
#   DRY_RUN=1     do everything except pushing
#   FORK_URL / UPSTREAM_URL override the clone URLs (tests use local paths)
set -euo pipefail

fork=$1
upstream=$2
mode=$3
branch=nix-config

work=${SYNC_WORKDIR:-$(mktemp -d)}
report=${SYNC_REPORT:-/dev/stdout}
fork_url=${FORK_URL:-https://x-access-token:${GH_TOKEN:-}@github.com/$fork.git}
upstream_url=${UPSTREAM_URL:-https://github.com/$upstream.git}

log() { echo "sync-fork($fork): $*" >&2; }

git clone -q --branch "$branch" "$fork_url" "$work/repo"
cd "$work/repo"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git remote add upstream "$upstream_url"

case $mode in
  tag)
    # Upstream tags only, kept apart from the fork's own nix-config-* tags.
    git fetch -q --no-tags upstream "+refs/tags/v*:refs/upstream-tags/v*"
    target_name=$(git for-each-ref --format='%(refname:lstrip=2)' refs/upstream-tags \
      | sort -V | tail -n1)
    [[ -n $target_name ]] || { log "no upstream release tags"; exit 1; }
    target=$(git rev-parse "refs/upstream-tags/$target_name^{commit}")
    ;;
  main)
    git fetch -q --no-tags upstream main
    target_name="main@$(git rev-parse --short=12 upstream/main)"
    target=$(git rev-parse upstream/main)
    ;;
  *)
    log "unknown mode: $mode"
    exit 1
    ;;
esac

old_head=$(git rev-parse HEAD)
base=$(git merge-base HEAD "$target")

if [[ $base == "$target" ]]; then
  log "already based on $target_name"
  exit 0
fi

# Name of the current base: its upstream tag, or the short commit.
base_name=$(git for-each-ref --points-at "$base" --format='%(refname:lstrip=2)' refs/upstream-tags \
  | sort -V | tail -n1)
base_name=${base_name:-$(git rev-parse --short=12 "$base")}
log "rebasing $(git rev-list --count "$base..HEAD") commits from $base_name onto $target_name"

if ! git rebase -q --onto "$target" "$base" "$branch" >/dev/null 2>&1; then
  failing=$(git log -1 --format='%h %s' REBASE_HEAD 2>/dev/null || echo "?")
  # Literal backticks: Markdown code spans in the issue.
  # shellcheck disable=SC2016
  conflicts=$(git diff --name-only --diff-filter=U | sed 's/^/- `/; s/$/`/')
  git rebase --abort
  {
    echo "Rebase of \`$fork\` \`$branch\` from \`$base_name\` onto \`$upstream\` \`$target_name\` failed."
    echo
    echo "First commit that does not apply: \`$failing\`"
    echo
    echo "Conflicting files:"
    echo
    echo "$conflicts"
    echo
    echo "The branch was left untouched. Rebase it by hand (keep one commit per patch),"
    echo "tag the previous state as \`nix-config-$base_name\` and force-push."
  } >"$report"
  log "conflict; branch untouched"
  exit 2
fi

archive="nix-config-$base_name"
if [[ ${DRY_RUN:-0} == 1 ]]; then
  log "dry run: would tag $archive and push $branch ($old_head -> $(git rev-parse HEAD))"
  exit 0
fi
if ! git ls-remote --exit-code --tags origin "refs/tags/$archive" >/dev/null; then
  git tag -a -m "nix-config patches over $base_name (before the rebase onto $target_name)" "$archive" "$old_head"
  git push -q origin "refs/tags/$archive"
fi
git push -q --force-with-lease="$branch:$old_head" origin "$branch"
echo "Rebased \`$fork\` \`$branch\` onto \`$target_name\` (previous state: tag \`$archive\`)." >"$report"
log "rebased onto $target_name and pushed"
