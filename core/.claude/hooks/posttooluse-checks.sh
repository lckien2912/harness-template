#!/usr/bin/env bash
#
# PostToolUse checks (Layer 3).
#
# After Claude edits a file, run the project's fast fixers/linters on THAT file
# so problems surface immediately instead of at the end of a long change.
#
# The checks are data: `.harness/post-edit.rules`, one rule per line:
#
#   <globs>|<cwd>|<command>
#
#   globs    space-separated bash globs against the project-relative path
#            (`*` spans `/`, so `src/*.ts` matches nested files)
#   cwd      directory to run in: `.` (project root), a relative directory, or
#            `{pkgdir}` = the nearest ancestor of the file that holds a package
#            marker (package.json, pyproject.toml, go.mod, Cargo.toml, ...)
#   command  `{file}` is replaced by the edited file's path (shell-quoted)
#
# Every matching rule runs. The first word of the command is resolved to an
# already-installed binary only: node_modules/.bin (of <cwd>, then the root),
# then .venv/bin (same order), then PATH. Nothing is downloaded (no npx/bunx
# fallback); a missing tool is skipped silently and the init.sh gates still
# apply. A non-zero exit prints the output and exits 2, so Claude fixes the
# file it just touched.
#
# Whole-project type-checking, the build and the test suites are deliberately
# NOT run per edit; they run at the Definition-of-Done gates (init.sh).

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$HOOK_DIR/../.." && pwd)}"
RULES_FILE="$PROJECT_DIR/.harness/post-edit.rules"

# shellcheck source=/dev/null
source "$HOOK_DIR/lib.sh"

[[ -f "$RULES_FILE" ]] || exit 0

IFS=$'\x1f' read -r TOOL_NAME _COMMAND FILE_PATH < <(parse_payload "$(cat)") || true

case "$TOOL_NAME" in
  Edit | Write | MultiEdit | NotebookEdit) ;;
  *) exit 0 ;;
esac
[[ -n "$FILE_PATH" && -f "$FILE_PATH" ]] || exit 0

REL="${FILE_PATH#"$PROJECT_DIR"/}"
# Outside the project: nothing to do.
[[ "$REL" == /* ]] && exit 0

# Generated directories are never checked (HARNESS_GENERATED_DIRS in config).
HARNESS_GENERATED_DIRS=()
# shellcheck source=/dev/null
[[ -f "$PROJECT_DIR/.harness/config.sh" ]] && source "$PROJECT_DIR/.harness/config.sh"
for d in ${HARNESS_GENERATED_DIRS[@]+"${HARNESS_GENERATED_DIRS[@]}"} node_modules .git; do
  case "/$REL" in */"$d"/*) exit 0 ;; esac
done

PKG_MARKERS=(package.json pyproject.toml go.mod Cargo.toml composer.json Gemfile pom.xml build.gradle build.gradle.kts mix.exs)
pkgdir() {
  local dir
  dir="$(dirname "$FILE_PATH")"
  while [[ "$dir" == "$PROJECT_DIR"* ]]; do
    for m in "${PKG_MARKERS[@]}"; do
      [[ -f "$dir/$m" ]] && { printf '%s' "$dir"; return; }
    done
    [[ "$dir" == "$PROJECT_DIR" ]] && break
    dir="$(dirname "$dir")"
  done
  printf '%s' "$PROJECT_DIR"
}

resolve_bin() {
  # resolve_bin <name> <cwd>
  local name="$1" cwd="$2"
  if [[ "$name" == */* ]]; then
    [[ "$name" == /* ]] || name="$cwd/$name"
    [[ -x "$name" ]] && printf '%s' "$name"
    return
  fi
  for candidate in "$cwd/node_modules/.bin/$name" "$PROJECT_DIR/node_modules/.bin/$name" \
    "$cwd/.venv/bin/$name" "$PROJECT_DIR/.venv/bin/$name"; do
    [[ -x "$candidate" ]] && { printf '%s' "$candidate"; return; }
  done
  command -v "$name" 2>/dev/null || true
}

failed=0
quoted_file="$(printf '%q' "$FILE_PATH")"
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  [[ -z "${line//[[:space:]]/}" || "$line" =~ ^[[:space:]]*# ]] && continue
  globs="${line%%|*}"
  rest="${line#*|}"
  cwd_spec="${rest%%|*}"
  cmd="${rest#*|}"

  matched=0
  for g in $globs; do
    # shellcheck disable=SC2254
    case "$REL" in $g) matched=1; break ;; esac
  done
  [[ $matched -eq 1 ]] || continue

  case "$cwd_spec" in
    "{pkgdir}") cwd="$(pkgdir)" ;;
    "." | "") cwd="$PROJECT_DIR" ;;
    *) cwd="$PROJECT_DIR/$cwd_spec" ;;
  esac
  [[ -d "$cwd" ]] || continue

  bin_name="${cmd%% *}"
  args=""
  [[ "$cmd" == *" "* ]] && args="${cmd#* }"
  bin="$(resolve_bin "$bin_name" "$cwd")"
  [[ -n "$bin" ]] || continue
  args="${args//\{file\}/$quoted_file}"

  if ! out="$(cd "$cwd" && eval "$(printf '%q' "$bin") $args" 2>&1)"; then
    echo "GUARDRAIL: \`$bin_name\` reported errors for $REL. Fix them before continuing." >&2
    printf '%s\n' "$out" | tail -n 60 >&2
    failed=1
  fi
done <"$RULES_FILE"

[[ $failed -eq 1 ]] && exit 2
exit 0
