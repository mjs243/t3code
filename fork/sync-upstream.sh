#!/usr/bin/env bash
# fork/sync-upstream.sh — nightly: mirror upstream/main into main, rebase `malik` onto it,
# reinstall deps if the lockfile moved, typecheck, push. Notify (ntfy) only on conflict/failure.
#
#   sync-upstream.sh            # full run
#   sync-upstream.sh --build    # also build desktop artifact after a green typecheck
#   sync-upstream.sh --dry-run  # fetch + report what would happen, change nothing
#
# Conflict policy: the rebase is ABORTED and reported; resolve by hand with
#   git rebase upstream/main   (rerere replays past resolutions automatically)
set -euo pipefail

REPO="${T3_FORK_DIR:-$HOME/Projects/t3code}"
WORK_BRANCH="malik"
LOG_DIR="$REPO/fork/logs"; mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/sync-$(date +%Y-%m-%d).log"
NTFY_TOPIC_FILE="$HOME/.config/tradebot/ntfy-topic"
BUILD=0; DRY=0
for a in "$@"; do case "$a" in --build) BUILD=1;; --dry-run) DRY=1;; esac; done

exec > >(tee -a "$LOG") 2>&1
echo "== t3code sync $(date '+%F %T')"
cd "$REPO"
# shellcheck disable=SC1091
. "$REPO/fork/env.sh"

notify() {  # title, body
  [ -f "$NTFY_TOPIC_FILE" ] || return 0
  curl -fsS -H "Title: $1" -H "Priority: high" -d "$2" "https://ntfy.sh/$(cat "$NTFY_TOPIC_FILE")" >/dev/null || true
}
fail() { echo "!! $1"; notify "t3code sync FAILED" "$1 — see $LOG"; exit 1; }

[ -z "$(git status --porcelain)" ] || fail "working tree dirty; refusing to sync"

git fetch upstream --prune --tags
git fetch origin --prune
BEFORE=$(git rev-parse upstream/main@{1} 2>/dev/null || git rev-parse main)
AFTER=$(git rev-parse upstream/main)
NEW=$(git rev-list --count "main..upstream/main")
echo "upstream/main: $NEW new commit(s) since local main"
git log --oneline "main..upstream/main" | head -40

if [ "$DRY" = 1 ]; then
  git checkout -q "$WORK_BRANCH"
  echo "-- dry run: would rebase $WORK_BRANCH ($(git rev-list --count upstream/main..$WORK_BRANCH) own commits) onto upstream/main"
  exit 0
fi

# 1. main = untouched mirror
git checkout -q main
git merge --ff-only upstream/main
git push -q origin main

# 2. rebase personal branch
git checkout -q "$WORK_BRANCH"
OWN=$(git rev-list --count "main..$WORK_BRANCH")
echo "rebasing $WORK_BRANCH ($OWN own commit(s)) onto main"
if ! git rebase main; then
  CONFLICTS=$(git diff --name-only --diff-filter=U | tr '\n' ' ')
  git rebase --abort
  fail "REBASE CONFLICT in: $CONFLICTS. Run: cd $REPO && git rebase main"
fi

# 3. deps + checks
if ! git diff --quiet "$BEFORE" "$AFTER" -- pnpm-lock.yaml package.json pnpm-workspace.yaml 2>/dev/null; then
  echo "lockfile changed → vp i"; vp i --frozen-lockfile || vp i
fi
vp run --filter @t3tools/web --filter @t3tools/server typecheck || fail "typecheck failed after rebase ($NEW upstream commits)"

# 4. publish
git push -q --force-with-lease origin "$WORK_BRANCH"
echo "pushed $WORK_BRANCH"

if [ "$BUILD" = 1 ]; then
  vp run build:desktop || fail "desktop build failed"
  echo "desktop build ok"
fi
echo "== done $(date '+%T')"
