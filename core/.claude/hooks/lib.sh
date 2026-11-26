#!/usr/bin/env bash
#
# Shared helpers for the Claude Code guardrail hooks.
# Sourced by pretooluse-guard.sh and posttooluse-checks.sh.

# parse_payload <json-string>
#
# Parses a Claude Code hook payload once and prints three fields separated by
# the ASCII unit separator (0x1F) on a single line, followed by a newline:
#
#   <tool_name> US <tool_input.command> US <tool_input.file_path or notebook_path>
#
# Read it with `IFS=$'\x1f' read -r a b c`. The separator must not be
# whitespace: with IFS=$'\t', bash collapses consecutive tabs, so an empty
# command would shift the file path into the command field.
#
# Missing fields are empty. Invalid JSON yields three empty fields (never fails
# the caller, so hooks fail open rather than crashing). Separators/CR/LF inside any
# value are collapsed to spaces so the output stays exactly one line / three
# fields; for command matching a newline is equivalent to a space anyway.
#
# Uses node, then python3, then jq: whichever exists first. The harness does
# not care which language the project itself is written in.
parse_payload() {
  local payload="$1"
  if command -v node >/dev/null 2>&1; then
    printf '%s' "$payload" | node -e '
      let s = "";
      process.stdin.on("data", d => (s += d)).on("end", () => {
        let t = "", c = "", f = "";
        try {
          const j = JSON.parse(s);
          t = String(j.tool_name || "");
          const ti = j.tool_input || {};
          c = String(ti.command || "");
          f = String(ti.file_path || ti.notebook_path || "");
        } catch {}
        const clean = v => v.replace(/[\x1f\r\n]+/g, " ");
        process.stdout.write(clean(t) + "\x1f" + clean(c) + "\x1f" + clean(f) + "\n");
      });
    '
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$payload" | python3 -I -c '
import json, re, sys
t = c = f = ""
try:
    j = json.loads(sys.stdin.read())
    t = str(j.get("tool_name") or "")
    ti = j.get("tool_input") or {}
    c = str(ti.get("command") or "")
    f = str(ti.get("file_path") or ti.get("notebook_path") or "")
except Exception:
    pass
clean = lambda v: re.sub(r"[\x1f\r\n]+", " ", v)
sys.stdout.write(clean(t) + "\x1f" + clean(c) + "\x1f" + clean(f) + "\n")
'
  elif command -v jq >/dev/null 2>&1; then
    printf '%s' "$payload" | jq -r '[
        (.tool_name // ""),
        (.tool_input.command // ""),
        (.tool_input.file_path // .tool_input.notebook_path // "")
      ] | map(tostring | gsub("[\u001f\r\n]+"; " ")) | join("\u001f")' 2>/dev/null \
      || printf '\037\037\n'
  else
    printf '\037\037\n'
  fi
}

# harness_rule_files <dir> <glob>
#
# Prints the rule files matching <glob> inside <dir>, one per line, sorted.
harness_rule_files() {
  local dir="$1" glob="$2" f
  [[ -d "$dir" ]] || return 0
  for f in "$dir"/$glob; do
    [[ -f "$f" ]] && printf '%s\n' "$f"
  done
}
