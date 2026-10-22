#!/usr/bin/env bash
# Apply the standard GitHub setup (labels + repo settings) from WORKFLOW.md to repos.
# Usage: scripts/setup-github.sh <owner/repo> [--prune]
#        scripts/setup-github.sh --all [--prune]
#   --all    run over every repo in repos.txt.
#   --prune  also delete labels not in labels.json (GitHub's defaults, old labels).
#            Issues lose those labels, so map them to standard ones first.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
labels="$root/labels.json"
target="${1:?usage: $0 <owner/repo>|--all [--prune]}"
prune="${2:-}"

setup_repo() {
  local repo="$1"

  jq -c '.[]' "$labels" | while read -r label; do
    gh label create "$(jq -r .name <<<"$label")" --repo "$repo" --force \
      --color "$(jq -r .color <<<"$label")" \
      --description "$(jq -r .description <<<"$label")"
  done

  if [[ "$prune" == "--prune" ]]; then
    comm -13 <(jq -r '.[].name' "$labels" | sort) \
      <(gh label list --repo "$repo" --limit 200 --json name --jq '.[].name' | sort) |
      while read -r name; do gh label delete "$name" --repo "$repo" --yes; done
  fi

  # Squash-merge only, PR title + body as the commit (so "Closes #N" lands on main),
  # and delete merged branches.
  gh repo edit "$repo" \
    --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false \
    --delete-branch-on-merge --enable-issues
  gh api -X PATCH "repos/$repo" -f squash_merge_commit_title=PR_TITLE \
    -f squash_merge_commit_message=PR_BODY >/dev/null

  # Security: Dependabot alerts on, and actions must be pinned to a full commit SHA.
  gh api -X PUT "repos/$repo/vulnerability-alerts" --silent
  gh api -X PUT "repos/$repo/actions/permissions" -F enabled=true -f allowed_actions=all \
    -F sha_pinning_required=true --silent

  echo "Done: $repo"
}

if [[ "$target" == "--all" ]]; then
  # Read repos on fd 3 so gh can't swallow the list from stdin.
  while read -r repo <&3; do
    setup_repo "$repo"
  done 3< <(grep -Ev '^[[:space:]]*(#|$)' "$root/repos.txt")
else
  setup_repo "$target"
fi
