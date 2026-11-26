#!/usr/bin/env bash
# Install the agent harness into a project.
#
#   bash install.sh <target-dir> [--preset NAME] [--name "Project Name"]
#                   [--milestone NAME] [--force] [--dry-run]
#
#   --preset     generic (default) | node | nest | tanstack-start | medusa |
#                python | go  (ls presets/)
#   --name       project name used in AGENTS.md and the docs (default: the
#                target directory's name)
#   --milestone  first milestone in feature_list.json (default: foundation)
#   --force      overwrite files that already exist (default: keep them and
#                list them as skipped)
#   --dry-run    print what would be written, write nothing
#
# Layering: core/ first, then presets/generic, then each ancestor named in a
# preset's `extends` file, then the preset itself; later layers win. Lines in
# AGENTS.md/CLAUDE.md that hold only `{{snippet:<name>}}` are replaced by the
# nearest layer's snippets/<name>.md, indented like the placeholder.
# {{PROJECT_NAME}}, {{PROJECT_SLUG}}, {{MILESTONE}}, {{DATE}} and {{PRESET}}
# are substituted everywhere.
set -euo pipefail

TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(cat "$TEMPLATE_DIR/VERSION" 2>/dev/null || echo dev)"

usage() { sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

target=""
preset="generic"
name=""
milestone="foundation"
force=0
dry_run=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --preset) preset="${2:?--preset needs a value}"; shift 2 ;;
    --name) name="${2:?--name needs a value}"; shift 2 ;;
    --milestone) milestone="${2:?--milestone needs a value}"; shift 2 ;;
    --force) force=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    -h | --help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)
      [[ -z "$target" ]] || { echo "Only one target directory." >&2; exit 2; }
      target="$1"; shift ;;
  esac
done
[[ -n "$target" ]] || { usage >&2; exit 2; }

if [[ ! -d "$TEMPLATE_DIR/presets/$preset" ]]; then
  echo "Unknown preset: $preset (available: $(ls "$TEMPLATE_DIR/presets" | tr '\n' ' '))" >&2
  exit 2
fi

mkdir -p "$target"
target="$(cd "$target" && pwd)"
[[ -n "$name" ]] || name="$(basename "$target")"
slug="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '_' | sed -E 's/_+/_/g; s/^_//; s/_$//')"
[[ -n "$slug" ]] || slug="app"
today="$(date -u +%Y-%m-%d)"

# Preset chain: generic, ancestors (outermost first), the preset.
chain=()
p="$preset"
seen=" "
while [[ -n "$p" && "$p" != "generic" ]]; do
  [[ "$seen" == *" $p "* ]] && { echo "Preset cycle at $p" >&2; exit 2; }
  seen="$seen$p "
  chain=("$p" ${chain[@]+"${chain[@]}"})
  ext="$TEMPLATE_DIR/presets/$p/extends"
  p=""
  if [[ -f "$ext" ]]; then p="$(tr -d '[:space:]' <"$ext")"; fi
done
chain=(generic ${chain[@]+"${chain[@]}"})
[[ "$preset" == "generic" ]] && chain=(generic)
label="${chain[*]}"
label="${label// / > }"

stage="$(mktemp -d "${TMPDIR:-/tmp}/harness-install.XXXXXX")"
trap 'rm -r "$stage"' EXIT

# 1. Layer the files.
cp -R "$TEMPLATE_DIR/core/." "$stage/"
for layer in "${chain[@]}"; do
  [[ -d "$TEMPLATE_DIR/presets/$layer/files" ]] && cp -R "$TEMPLATE_DIR/presets/$layer/files/." "$stage/"
done

find "$stage" -name .DS_Store -delete

# 2. Expand snippets.
snippet_file() {
  local snippet="$1" i
  for ((i = ${#chain[@]} - 1; i >= 0; i--)); do
    local f="$TEMPLATE_DIR/presets/${chain[$i]}/snippets/$snippet.md"
    [[ -f "$f" ]] && { printf '%s' "$f"; return; }
  done
}
expand_snippets() {
  local file="$1" out line indent snippet src s
  out="$(mktemp "${TMPDIR:-/tmp}/harness-snippet.XXXXXX")"
  {
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ ^([[:space:]]*)\{\{snippet:([a-z0-9-]+)\}\}[[:space:]]*$ ]]; then
        indent="${BASH_REMATCH[1]}"
        snippet="${BASH_REMATCH[2]}"
        src="$(snippet_file "$snippet")"
        if [[ -n "$src" ]]; then
          while IFS= read -r s || [[ -n "$s" ]]; do
            if [[ -n "$s" ]]; then printf '%s%s\n' "$indent" "$s"; else echo; fi
          done <"$src"
        fi
      else
        printf '%s\n' "$line"
      fi
    done <"$file"
  } | cat -s >"$out" # an empty snippet leaves blank lines: squeeze them
  mv "$out" "$file"
}
for f in AGENTS.md CLAUDE.md; do
  [[ -f "$stage/$f" ]] && expand_snippets "$stage/$f"
done

# 3. Substitute placeholders in every text file.
sed_escape() { printf '%s' "$1" | sed -e 's/[\/&|\\]/\\&/g'; }
e_name="$(sed_escape "$name")"
e_slug="$(sed_escape "$slug")"
e_milestone="$(sed_escape "$milestone")"
e_preset="$(sed_escape "$label")"
while IFS= read -r -d '' f; do
  grep -Iq . "$f" 2>/dev/null || continue
  grep -q '{{' "$f" || continue
  sed -e "s|{{PROJECT_NAME}}|$e_name|g" \
    -e "s|{{PROJECT_SLUG}}|$e_slug|g" \
    -e "s|{{MILESTONE}}|$e_milestone|g" \
    -e "s|{{DATE}}|$today|g" \
    -e "s|{{PRESET}}|$e_preset|g" "$f" >"$f.tmp"
  mv "$f.tmp" "$f"
done < <(find "$stage" -type f -print0)

cat >"$stage/.harness/manifest" <<EOF
# Written by the harness template installer; used for upgrades.
template_version=$VERSION
preset=$preset
chain=${chain[*]}
installed=$today
EOF

chmod +x "$stage/init.sh" "$stage"/scripts/*.sh "$stage"/scripts/*.mjs "$stage"/.claude/hooks/*.sh "$stage"/.githooks/*

# 4. Copy into the target; existing files are kept unless --force. Files the
#    project owns after installation are never overwritten, even with --force.
project_owned=(
  docs/PRODUCT.md docs/ROADMAP.md docs/ARCHITECTURE.md progress.md feature_list.json
  .harness/config.sh .harness/guard.project.rules .harness/guard.project.cases .harness/boundary.cases
  .harness/post-edit.rules .harness/architecture.rules
)
is_project_owned() {
  local rel="$1" o
  for o in "${project_owned[@]}"; do [[ "$rel" == "$o" ]] && return 0; done
  return 1
}

written=()
skipped=()
while IFS= read -r -d '' f; do
  rel="${f#"$stage"/}"
  dest="$target/$rel"
  if [[ -e "$dest" ]]; then
    if [[ $force -eq 0 ]] || is_project_owned "$rel"; then
      cmp -s "$f" "$dest" || skipped+=("$rel")
      continue
    fi
  fi
  written+=("$rel")
  if [[ $dry_run -eq 0 ]]; then
    mkdir -p "$(dirname "$dest")"
    cp -p "$f" "$dest"
  fi
done < <(find "$stage" -type f -print0 | sort -z)

echo "Harness template $VERSION, preset $label -> $target"
echo "Written (${#written[@]}):"
for r in ${written[@]+"${written[@]}"}; do echo "  $r"; done
if [[ ${#skipped[@]} -gt 0 ]]; then
  echo "Kept as they are (${#skipped[@]}; differ from the template; compare by hand or rerun with --force):"
  for r in "${skipped[@]}"; do echo "  $r"; done
fi
[[ $dry_run -eq 1 ]] && echo "(dry run: nothing written)"

cat <<EOF

Next steps:
  1. Review .harness/config.sh (gates, app directory, worktree database).
  2. Adjust .harness/architecture.rules and .harness/post-edit.rules to the layout.
  3. Fill the <placeholders> in AGENTS.md, docs/PRODUCT.md and docs/ROADMAP.md.
  4. Run: cd "$target" && bash init.sh
  5. Restart Claude Code in the project so it trusts the new hooks.
EOF
