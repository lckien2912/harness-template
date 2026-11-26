#!/usr/bin/env bash
# Architecture boundary check. The rules are data: .harness/architecture.rules,
# one rule per line, `#` comments allowed:
#
#   <name>|<paths>|<extended regex>|<message>
#
#   paths  space-separated directories or files, relative to the repository
#          root; a path that does not exist (yet) is skipped
#   regex  a match anywhere in those paths is a violation (ERE that both
#          ripgrep and grep -E understand: prefer [[:space:]] over \s)
#
# Keep the rules few and high-signal: only boundaries a linter will not catch
# (raw database access, config read outside its boundary, imports across
# layers, framework internals). Files matching HARNESS_ARCH_EXCLUDES (tests by
# default) and HARNESS_GENERATED_DIRS are not searched.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RULES_FILE=".harness/architecture.rules"
HARNESS_ARCH_EXCLUDES=()
HARNESS_GENERATED_DIRS=()
# shellcheck source=/dev/null
[[ -f .harness/config.sh ]] && source .harness/config.sh

echo "=== Architecture Boundary Check ==="

if [[ ! -f "$RULES_FILE" ]]; then
  echo "No $RULES_FILE; nothing to check."
  exit 0
fi

search() {
  # search <regex> <path...>: prints matches as file:line:text.
  local regex="$1"
  shift
  if command -v rg >/dev/null 2>&1; then
    local args=(-n --no-heading)
    for g in ${HARNESS_ARCH_EXCLUDES[@]+"${HARNESS_ARCH_EXCLUDES[@]}"}; do args+=(--glob "!$g"); done
    for d in ${HARNESS_GENERATED_DIRS[@]+"${HARNESS_GENERATED_DIRS[@]}"}; do args+=(--glob "!**/$d/**"); done
    rg "${args[@]}" -e "$regex" -- "$@" 2>/dev/null || true
  else
    local args=(-rnE)
    for g in ${HARNESS_ARCH_EXCLUDES[@]+"${HARNESS_ARCH_EXCLUDES[@]}"}; do args+=("--exclude=$g"); done
    for d in ${HARNESS_GENERATED_DIRS[@]+"${HARNESS_GENERATED_DIRS[@]}"} node_modules .git; do args+=("--exclude-dir=$d"); done
    grep "${args[@]}" -e "$regex" -- "$@" 2>/dev/null || true
  fi
}

violations=0
rules=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  [[ -z "${line//[[:space:]]/}" || "$line" =~ ^[[:space:]]*# ]] && continue
  name="${line%%|*}"
  rest="${line#*|}"
  paths="${rest%%|*}"
  rest="${rest#*|}"
  # The regex may contain `|`; the message is everything after the LAST `|`.
  message="${rest##*|}"
  regex="${rest%|*}"
  rules=$((rules + 1))

  existing=()
  for p in $paths; do
    [[ -e "$p" ]] && existing+=("$p")
  done
  [[ ${#existing[@]} -eq 0 ]] && continue

  found="$(search "$regex" "${existing[@]}")"
  if [[ -n "$found" ]]; then
    echo "VIOLATION ($name): $message"
    echo "$found"
    violations=$((violations + 1))
  fi
done <"$RULES_FILE"

if [[ "$violations" -gt 0 ]]; then
  echo "Architecture check failed with $violations violation group(s)."
  exit 1
fi

echo "Architecture boundaries: PASS ($rules rules)"
