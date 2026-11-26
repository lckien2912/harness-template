#!/usr/bin/env bash
#
# PreToolUse guard (Layer 2).
#
# Regex-based backstop for the declarative rules in .claude/settings.json.
# settings.json can only match command PREFIXES, so it misses dangerous
# patterns embedded in compound commands (`cd x && rm -rf y`,
# `psql -c "DROP TABLE x"`). This hook inspects the full command string (and
# the target path of file edits) and blocks or asks, then audit-logs it.
#
# The rules are data, not code: every `.harness/guard*.rules` file is read.
# `guard.rules` holds the framework-agnostic core; presets and projects add
# `guard.<name>.rules`. One rule per line, `#` comments allowed:
#
#   <kind>|<name>|<extended regex, matched case-insensitively>
#
#   A kind ending in `:cs` (e.g. `ask:cs`) matches case-sensitively.
#   kind = block       Bash command matches -> blocked (exit 2)
#        | ask         Bash command matches -> Claude Code asks the human
#        | block-path  Edit/Write target path matches -> blocked
#        | ask-path    Edit/Write target path matches -> asks the human
#
# The name never contains `|`; everything after the second `|` is the regex,
# so a regex may use as many `|` alternations as it needs. Path rules match the
# project-relative path. `block` rules are checked before `ask` rules.
#
# Contract:
#   - Reads the hook payload (JSON) from stdin.
#   - exit 2 + reason on stderr  -> Claude Code blocks the tool call.
#   - exit 0 + "ask" JSON        -> Claude Code asks for approval.
#   - exit 0                     -> allow (settings.json still applies its own
#                                   allow/ask/deny decision on top of this).
#
# The audit log records the rule name and a TRUNCATED command or path. Secret
# file contents never reach it, but a blocked command that inlines a secret
# could leave a fragment in the local, git-ignored .claude/logs/audit.log.

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$HOOK_DIR/../.." && pwd)}"
RULES_DIR="${HARNESS_RULES_DIR:-$PROJECT_DIR/.harness}"
LOG_DIR="$PROJECT_DIR/.claude/logs"
LOG_FILE="$LOG_DIR/audit.log"

# shellcheck source=/dev/null
source "$HOOK_DIR/lib.sh"

# Parse the payload once. Fail open on a malformed payload.
IFS=$'\x1f' read -r TOOL_NAME COMMAND FILE_PATH < <(parse_payload "$(cat)") || true

case "$TOOL_NAME" in
  Bash)
    [[ -z "$COMMAND" ]] && exit 0
    SUBJECT="$COMMAND"
    PREFIX=""
    ;;
  Edit | Write | MultiEdit | NotebookEdit)
    [[ -z "$FILE_PATH" ]] && exit 0
    SUBJECT="${FILE_PATH#"$PROJECT_DIR"/}"
    PREFIX="-path"
    ;;
  *) exit 0 ;;
esac

audit() {
  # audit <decision> <rule>
  local ts subject
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  subject="$(printf '%s' "$SUBJECT" | cut -c1-200)"
  mkdir -p "$LOG_DIR"
  printf '%s\t%s\t%s\t%s\t%s\n' "$ts" "$1" "$TOOL_NAME" "$2" "$subject" >>"$LOG_FILE"
}

# Collect the rules once: "kind|name|regex" lines, comments and blanks dropped.
RULES=()
while IFS= read -r file; do
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "${line//[[:space:]]/}" || "$line" =~ ^[[:space:]]*# ]] && continue
    RULES+=("$line")
  done <"$file"
done < <(harness_rule_files "$RULES_DIR" 'guard*.rules')

[[ ${#RULES[@]} -eq 0 ]] && exit 0

# check <kind>: prints the name of the first matching rule of that kind.
check() {
  local want="$1" entry kind rest name regex flags
  for entry in "${RULES[@]}"; do
    kind="${entry%%|*}"
    flags="-iqE"
    if [[ "$kind" == *:cs ]]; then
      kind="${kind%:cs}"
      flags="-qE"
    fi
    [[ "$kind" == "$want" ]] || continue
    rest="${entry#*|}"
    name="${rest%%|*}"
    regex="${rest#*|}"
    if printf '%s' "$SUBJECT" | grep "$flags" -- "$regex"; then
      printf '%s' "$name"
      return 0
    fi
  done
  return 1
}

if rule="$(check "block$PREFIX")"; then
  audit "BLOCKED" "$rule"
  echo "GUARDRAIL: blocked (rule: ${rule}). See AGENTS.md Protected Decisions and docs/GUARDRAILS.md. If this is genuinely required, ask the human to do it." >&2
  exit 2
fi

if rule="$(check "ask$PREFIX")"; then
  audit "APPROVAL_REQUIRED" "$rule"
  reason="GUARDRAIL: ${rule//\"/\'} needs approval (see AGENTS.md Protected Decisions)."
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$reason"
  exit 0
fi

exit 0
