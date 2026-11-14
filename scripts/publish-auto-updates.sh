#!/usr/bin/env bash
set -euo pipefail

updates_dir="$(realpath "$1")"
shopt -s nullglob
results=("$updates_dir"/*/result.json)
if [ "${#results[@]}" -eq 0 ]; then
  exit 0
fi

open_pr() {
  local result="$1" reason="$2" auto_merge="$3"
  local branch title body pr_number pr_url
  branch="$(jq -r .branch "$result")"
  title="$(jq -r .title "$result")"
  body="Automated update. $reason / 自动更新。$4"
  git push --force --no-verify origin "$branch:$branch"
  pr_number="$(gh pr list --repo "$GITHUB_REPOSITORY" --head "$branch" \
    --state open --json number --jq '.[0].number // empty')"
  if [ -n "$pr_number" ]; then
    gh pr edit "$pr_number" --repo "$GITHUB_REPOSITORY" --title "$title" --body "$body"
  else
    pr_url="$(gh pr create --repo "$GITHUB_REPOSITORY" --base main --head "$branch" \
      --title "$title" --body "$body")"
    pr_number="${pr_url##*/}"
  fi
  if [ "$auto_merge" = true ]; then
    gh pr merge "$pr_number" --repo "$GITHUB_REPOSITORY" --auto --squash --delete-branch
  else
    gh pr merge "$pr_number" --repo "$GITHUB_REPOSITORY" --disable-auto
  fi
}

cleanup() {
  local result="$1" branch pr_numbers
  branch="$(jq -r .branch "$result")"
  # Cleanup is best effort because main already contains the update.
  pr_numbers="$(gh pr list --repo "$GITHUB_REPOSITORY" --head "$branch" \
    --state open --json number --jq '.[].number' || true)"
  for pr in $pr_numbers; do
    gh pr close "$pr" --repo "$GITHUB_REPOSITORY" --delete-branch || true
  done
  git push --no-verify origin --delete "$branch" 2>/dev/null || true
}

git fetch --quiet origin main
git switch -C auto-update-batch origin/main
accepted=()
conflicts=()
for result in "${results[@]}"; do
  branch="$(jq -r .branch "$result")"
  git fetch --quiet "${result%/*}/update.bundle" "HEAD:refs/heads/$branch"
  commit_list="$(git rev-list --reverse "origin/main..$branch")"
  commits=()
  if [ -n "$commit_list" ]; then
    mapfile -t commits <<< "$commit_list"
  fi
  if [ "${#commits[@]}" -gt 0 ] && ! git cherry-pick --empty=drop "${commits[@]}"; then
    git cherry-pick --abort
    conflicts+=("$result")
    continue
  fi
  accepted+=("$result")
done

pushed=false
if [ "${#accepted[@]}" -gt 0 ]; then
  for attempt in 1 2 3 4 5; do
    git fetch --quiet origin main
    if ! git rebase origin/main; then
      git rebase --abort
      break
    fi
    if git diff --quiet origin/main HEAD || git push --no-verify origin HEAD:main; then
      pushed=true
      break
    fi
    if [ "$attempt" -lt 5 ]; then
      sleep "$((attempt * 10))"
    fi
  done
fi

# Persist every fallback before attempting best-effort cleanup.
for result in "${conflicts[@]}"; do
  open_pr "$result" \
    "Combining validated updates caused a conflict. Auto-merge is off." false \
    "合并已验证更新时发生冲突，已关闭自动合并。"
done
if [ "$pushed" = true ]; then
  for result in "${accepted[@]}"; do
    cleanup "$result"
  done
else
  for result in "${accepted[@]}"; do
    open_pr "$result" \
      "Validation passed, but publishing the batch failed. Auto-merge is on." true \
      "验证通过，但汇总推送失败，已启用自动合并。"
  done
fi
