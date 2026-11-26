#!/usr/bin/env bash
# Cleanup scanner:
# - FAILS when generated output, real env files or credential-like files are
#   tracked by git;
# - lists local generated directories (informational);
# - lists branches/worktrees with no commits outside the main branch or a
#   phase branch (informational; AGENTS.md "Branches and Worktrees").
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HARNESS_MAIN_BRANCH="main"
HARNESS_PHASE_PREFIX="phase/"
HARNESS_GENERATED_DIRS=()
# shellcheck source=/dev/null
[[ -f .harness/config.sh ]] && source .harness/config.sh

echo "=== Cleanup Scanner ==="

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: not inside a git worktree."
  exit 1
fi

dirs=(node_modules ${HARNESS_GENERATED_DIRS[@]+"${HARNESS_GENERATED_DIRS[@]}"})
alt=""
for d in "${dirs[@]}"; do
  esc="$(printf '%s' "$d" | sed 's/[.[\*^$()+?{}|]/\\&/g')"
  alt="${alt:+$alt|}$esc"
done

# Real local env files (.env, .env.local, .env.*) must never be tracked. The
# committed, non-secret contracts `.env.example` / `.env.template` / `.env.sample`
# are allowlisted.
tracked_violations="$(
  git ls-files \
    | grep -E "(^|/)($alt)/|(^|/)\\.env(\$|\\.)|\\.(pem|key|p12|pfx)\$|(^|/)id_(rsa|ed25519|ecdsa)" \
    | grep -Ev '(^|/)\.env\.(template|example|sample)$' \
    || true
)"

if [[ -n "$tracked_violations" ]]; then
  echo "Tracked generated, environment, or credential-like files found:"
  echo "$tracked_violations"
  exit 1
fi
echo "Tracked artifact scan: PASS"

find_args=()
for d in "${dirs[@]}"; do
  [[ "$d" == node_modules ]] && continue
  find_args+=(${find_args[@]+-o} -name "$d")
done
stale_dirs=""
if [[ ${#find_args[@]} -gt 0 ]]; then
  stale_dirs="$(find . -type d \( "${find_args[@]}" \) -not -path '*/node_modules/*' -not -path './.git/*' -prune -print 2>/dev/null || true)"
fi
if [[ -n "$stale_dirs" ]]; then
  echo "Local generated directories (informational; safe to remove when stale):"
  echo "$stale_dirs"
else
  echo "No local generated directories found."
fi

merged_into() {
  local branch="$1" target
  for target in "$HARNESS_MAIN_BRANCH" $(git for-each-ref --format='%(refname:short)' "refs/heads/${HARNESS_PHASE_PREFIX}*"); do
    [[ "$branch" == "$target" ]] && continue
    git show-ref --verify --quiet "refs/heads/$target" || continue
    if git merge-base --is-ancestor "refs/heads/$branch" "refs/heads/$target" 2>/dev/null; then
      echo "$target"
      return 0
    fi
  done
  return 1
}

stale_branches=""
while IFS= read -r branch; do
  [[ "$branch" == "$HARNESS_MAIN_BRANCH" || "$branch" == "$HARNESS_PHASE_PREFIX"* ]] && continue
  if target="$(merged_into "$branch")"; then
    worktree="$(git worktree list --porcelain | awk -v b="branch refs/heads/$branch" '/^worktree /{w=substr($0,10)} $0==b{print w}')"
    stale_branches+="  $branch (in $target)${worktree:+, worktree $worktree}"$'\n'
  fi
done < <(git for-each-ref --format='%(refname:short)' refs/heads)

if [[ -n "$stale_branches" ]]; then
  echo "Branches with no commits outside $HARNESS_MAIN_BRANCH or a phase branch (informational; remove when done):"
  printf '%s' "$stale_branches"
else
  echo "No merged branches or worktrees left behind."
fi
