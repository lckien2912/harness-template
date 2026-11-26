#!/usr/bin/env bash
# Feeds the trial inputs in .harness/guard*.cases to the PreToolUse guard and
# prints its decision for each. Then tests the content checks, when the
# project has any:
#
# - .harness/boundary.cases: each case writes one file into a fresh scratch
#   tree and runs one check on it. Format: <expect>|<check>|<path>|<content>,
#   expect = pass|fail, check = `arch` (scripts/check-architecture.sh with the
#   real architecture.rules) or <name> (.harness/checks/<name>.mjs <tree>).
#   `\n` in <content> is a newline.
# - .harness/checks/fixtures/<name>/<case>/: a fixture repository for
#   .harness/checks/<name>.mjs. The scratch repo is the real .harness/ plus the
#   case's files; <case>/expect lists the rules the check must report (lines
#   `VIOLATION (<rule>): ...` on its output), exactly those, or `pass`. `#`
#   lines are comments.
#
#   bash scripts/test-guardrails.sh [repo-root]    # exits 1 on any mismatch
#
# Case format: <expect>|<tool>|<command or path>, expect = block|ask|allow.
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
HOOK="$ROOT/.claude/hooks/pretooluse-guard.sh"
RULES_DIR="$ROOT/.harness"

# shellcheck source=/dev/null
source "$ROOT/.claude/hooks/lib.sh"

payload() {
  # payload <tool> <value>: a hook payload, JSON-escaped without dependencies.
  local tool="$1" value="$2" key=command
  [[ "$tool" != "Bash" ]] && key=file_path
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '{"tool_name":"%s","tool_input":{"%s":"%s"}}' "$tool" "$key" "$value"
}

fail=0
count=0
scratch="$(mktemp -d "${TMPDIR:-/tmp}/guardrails.XXXXXX")" || exit 1
[[ -d "$scratch" ]] || { echo "No scratch directory" >&2; exit 1; }
trap 'rm -rf "${scratch:?}"' EXIT

while IFS= read -r file; do
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "${line//[[:space:]]/}" || "$line" =~ ^[[:space:]]*# ]] && continue
    want="${line%%|*}"
    rest="${line#*|}"
    tool="${rest%%|*}"
    value="${rest#*|}"
    out="$(payload "$tool" "$value" | CLAUDE_PROJECT_DIR="$scratch" HARNESS_RULES_DIR="$RULES_DIR" bash "$HOOK" 2>/dev/null)"
    code=$?
    if [[ $code -eq 2 ]]; then
      got=block
    elif [[ "$out" == *'"permissionDecision":"ask"'* ]]; then
      got=ask
    else
      got=allow
    fi
    count=$((count + 1))
    mark=ok
    [[ "$got" == "$want" ]] || { mark=FAIL; fail=1; }
    printf '%-4s want=%-5s got=%-5s %-5s %s\n' "$mark" "$want" "$got" "$tool" "$value"
  done <"$file"
done < <(harness_rule_files "$RULES_DIR" 'guard*.cases')

if [[ $count -eq 0 ]]; then
  echo "No guard cases found in $RULES_DIR/guard*.cases" >&2
  exit 1
fi
echo "$count guard cases, $([[ $fail -eq 0 ]] && echo PASS || echo FAIL)"

# Content checks, one case per fresh scratch tree.
boundary_count=0
boundary_fail=0
if [[ -f "$RULES_DIR/boundary.cases" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "${line//[[:space:]]/}" || "$line" =~ ^[[:space:]]*# ]] && continue
    want="${line%%|*}"
    rest="${line#*|}"
    check="${rest%%|*}"
    rest="${rest#*|}"
    file="${rest%%|*}"
    content="${rest#*|}"
    tree="$(mktemp -d "$scratch/tree.XXXXXX")"
    mkdir -p "$tree/$(dirname "$file")"
    printf '%b\n' "$content" >"$tree/$file"
    if [[ "$check" == arch ]]; then
      mkdir -p "$tree/scripts" "$tree/.harness"
      cp "$ROOT/scripts/check-architecture.sh" "$tree/scripts/"
      cp "$RULES_DIR/architecture.rules" "$RULES_DIR/config.sh" "$tree/.harness/"
      (cd "$tree" && bash scripts/check-architecture.sh >/dev/null 2>&1)
      code=$?
    elif [[ -f "$RULES_DIR/checks/$check.mjs" ]] && ! command -v node >/dev/null 2>&1; then
      printf 'skip (no node) %-12s %s\n' "$check" "$file"
      continue
    elif [[ -f "$RULES_DIR/checks/$check.mjs" ]]; then
      (cd "$tree" && node "$RULES_DIR/checks/$check.mjs" "$tree" >/dev/null 2>&1)
      code=$?
    else
      echo "FAIL unknown check '$check' in boundary.cases" >&2
      code=99
    fi
    [[ $code -eq 0 ]] && got=pass || got=fail
    [[ $code -eq 99 ]] && got=error
    boundary_count=$((boundary_count + 1))
    mark=ok
    [[ "$got" == "$want" ]] || { mark=FAIL; boundary_fail=1; }
    printf '%-4s want=%-4s got=%-5s %-12s %s\n' "$mark" "$want" "$got" "$check" "$file"
  done <"$RULES_DIR/boundary.cases"
  echo "$boundary_count boundary cases, $([[ $boundary_fail -eq 0 ]] && echo PASS || echo FAIL)"
fi

# Fixture repositories for the checks in .harness/checks/.
fixture_count=0
fixture_fail=0
for case_dir in "$RULES_DIR"/checks/fixtures/*/*/; do
  [[ -f "$case_dir/expect" ]] || continue
  command -v node >/dev/null 2>&1 || { echo "skip (no node) fixture $case_dir"; continue; }
  check="$(basename "$(dirname "$case_dir")")"
  name="$check/$(basename "$case_dir")"
  repo="$(mktemp -d "$scratch/fixture.XXXXXX")"
  cp -R "$RULES_DIR" "$repo/.harness"
  rm -rf "${repo:?}/.harness/checks/fixtures"
  cp -R "$case_dir/." "$repo/"
  rm -f "${repo:?}/expect"
  want="$(grep -v '^[[:space:]]*#' "$case_dir/expect" | sed '/^[[:space:]]*$/d' | sort -u)"
  if [[ -f "$RULES_DIR/checks/$check.mjs" ]]; then
    out="$(cd "$repo" && node "$RULES_DIR/checks/$check.mjs" "$repo" 2>&1)"
    code=$?
  else
    out="no .harness/checks/$check.mjs"
    code=99
  fi
  got="$(printf '%s\n' "$out" | sed -n 's/^VIOLATION (\([^)]*\)): .*/\1/p' | sort -u)"
  if [[ $code -eq 0 ]]; then
    [[ -z "$got" ]] && got=pass || got="exit 0 with: $got"
  elif [[ -z "$got" ]]; then
    got="error (exit $code)"
  fi
  fixture_count=$((fixture_count + 1))
  mark=ok
  [[ "$got" == "$want" ]] || { mark=FAIL; fixture_fail=1; }
  printf '%-4s %-44s want=[%s] got=[%s]\n' "$mark" "$name" "${want//$'\n'/; }" "${got//$'\n'/; }"
  [[ $mark == FAIL ]] && printf '%s\n' "$out" | sed 's/^/     /'
done
if [[ $fixture_count -gt 0 ]]; then
  echo "$fixture_count check fixtures, $([[ $fixture_fail -eq 0 ]] && echo PASS || echo FAIL)"
fi

[[ $fail -eq 0 && $boundary_fail -eq 0 && $fixture_fail -eq 0 ]]
