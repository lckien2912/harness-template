#!/usr/bin/env bash
# Create a worktree for a feature or phase branch (AGENTS.md "Branches and
# Worktrees"), with its own env files and, optionally, its own dev database.
#
#   bash scripts/new-worktree.sh feat/p1.2-login [phase/p1-foundation]
#   bash scripts/new-worktree.sh phase/p1-foundation main
#
# - The worktree goes to <repo>/.claude/worktrees/<branch with "/" -> "-">.
# - A new branch is cut from the base (second argument; default: the current
#   branch when it is a phase branch). An existing branch is checked out as is.
#   Feature branches must be cut from a phase branch.
# - Every "example:target" pair in HARNESS_WORKTREE_ENV_FILES is copied when
#   the target is missing. Existing env files are never overwritten.
# - With HARNESS_WORKTREE_DB_ENGINE=postgres, a database
#   <HARNESS_WORKTREE_DB_PREFIX>_<branch slug> is created if missing and its URL
#   is written to HARNESS_WORKTREE_DB_URL_VAR in HARNESS_WORKTREE_DB_ENV_FILE.
#   Nothing is ever dropped. Connection: DB_USERNAME, DB_PASSWORD, DB_HOST,
#   DB_PORT, defaulting to HARNESS_WORKTREE_DB_{USER,PASSWORD,HOST,PORT} from
#   .harness/config.sh, else the current user, no password, localhost, 5432.
# - harness_worktree_setup <path> <slug>, when .harness/config.sh defines it,
#   runs last for anything else the stack needs.
set -euo pipefail

branch="${1:-}"
if [[ -z "$branch" ]]; then
  echo "Usage: bash scripts/new-worktree.sh <branch> [base-branch]" >&2
  exit 2
fi

common_dir="$(git rev-parse --path-format=absolute --git-common-dir)"
repo_root="$(dirname "$common_dir")"
here="$(git rev-parse --show-toplevel)"

HARNESS_MAIN_BRANCH="main"
HARNESS_PHASE_PREFIX="phase/"
HARNESS_FEATURE_PREFIX="feat/"
HARNESS_WORKTREE_ENV_FILES=()
HARNESS_WORKTREE_DB_ENGINE="none"
HARNESS_WORKTREE_DB_PREFIX="app"
HARNESS_WORKTREE_DB_URL_VAR="DATABASE_URL"
HARNESS_WORKTREE_DB_ENV_FILE=".env"
HARNESS_WORKTREE_DB_HOST="localhost"
HARNESS_WORKTREE_DB_PORT="5432"
HARNESS_WORKTREE_DB_USER=""
HARNESS_WORKTREE_DB_PASSWORD=""
# shellcheck source=/dev/null
[[ -f "$here/.harness/config.sh" ]] && source "$here/.harness/config.sh"

dir_name="${branch//\//-}"
path="$repo_root/.claude/worktrees/$dir_name"

if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch"; then
  if [[ -d "$path" ]]; then
    echo "Worktree already exists: $path"
  else
    git -C "$repo_root" worktree add "$path" "$branch"
  fi
else
  base="${2:-}"
  if [[ -z "$base" ]]; then
    current="$(git branch --show-current)"
    if [[ "$current" == "$HARNESS_PHASE_PREFIX"* ]]; then
      base="$current"
    else
      echo "ERROR: new branch $branch needs a base branch (second argument)." >&2
      exit 2
    fi
  fi
  if [[ "$branch" == "$HARNESS_FEATURE_PREFIX"* && "$base" != "$HARNESS_PHASE_PREFIX"* ]]; then
    echo "ERROR: feature branches are cut from a phase branch (${HARNESS_PHASE_PREFIX}*), not $base." >&2
    exit 2
  fi
  git -C "$repo_root" worktree add -b "$branch" "$path" "$base"
fi

slug="$(printf '%s' "$dir_name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '_' | sed -E 's/_+/_/g; s/^_//; s/_$//')"

for pair in ${HARNESS_WORKTREE_ENV_FILES[@]+"${HARNESS_WORKTREE_ENV_FILES[@]}"}; do
  example="$path/${pair%%:*}"
  target="$path/${pair#*:}"
  if [[ -f "$target" ]]; then
    echo "Env file kept as it is: ${pair#*:}"
  elif [[ -f "$example" ]]; then
    cp "$example" "$target"
    echo "Env file created from ${pair%%:*}"
  else
    echo "No ${pair%%:*} to copy; create ${pair#*:} yourself."
  fi
done

if [[ "$HARNESS_WORKTREE_DB_ENGINE" == "postgres" ]]; then
  db_name="$(printf '%s_%s' "$HARNESS_WORKTREE_DB_PREFIX" "$slug" | cut -c1-63)"
  db_user="${DB_USERNAME:-${HARNESS_WORKTREE_DB_USER:-$(whoami)}}"
  db_password="${DB_PASSWORD:-$HARNESS_WORKTREE_DB_PASSWORD}"
  db_host="${DB_HOST:-$HARNESS_WORKTREE_DB_HOST}"
  db_port="${DB_PORT:-$HARNESS_WORKTREE_DB_PORT}"
  credentials="$db_user"
  [[ -n "$db_password" ]] && credentials="$db_user:$db_password"
  database_url="postgres://$credentials@$db_host:$db_port/$db_name"

  env_file="$path/$HARNESS_WORKTREE_DB_ENV_FILE"
  var="$HARNESS_WORKTREE_DB_URL_VAR"
  if [[ -f "$env_file" ]] && grep -q "^$var=" "$env_file"; then
    tmp="$(mktemp "${TMPDIR:-/tmp}/harness-env.XXXXXX")"
    awk -v v="$var" -v url="$database_url" 'index($0, v "=") == 1 {print v "=" url; next} {print}' "$env_file" >"$tmp"
    mv "$tmp" "$env_file"
  else
    mkdir -p "$(dirname "$env_file")"
    printf '\n%s=%s\n' "$var" "$database_url" >>"$env_file"
  fi
  echo "$var -> $db_name (in $HARNESS_WORKTREE_DB_ENV_FILE)"

  export PGPASSWORD="$db_password"
  if ! command -v psql >/dev/null 2>&1; then
    echo "psql not found: create database $db_name yourself."
  elif psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -Atqc \
    "SELECT 1 FROM pg_database WHERE datname = '$db_name'" | grep -q 1; then
    echo "Database exists: $db_name"
  else
    createdb -h "$db_host" -p "$db_port" -U "$db_user" "$db_name"
    echo "Database created: $db_name"
  fi
fi

# CodeGraph: .codegraph/ is git-ignored, so a new worktree starts without an
# index. Build one when this checkout has an index and the CLI is installed.
if [[ -d "$here/.codegraph" ]] && command -v codegraph >/dev/null 2>&1; then
  echo "Indexing the worktree with CodeGraph..."
  codegraph init "$path" >/dev/null 2>&1 || echo "CodeGraph indexing failed; run: codegraph init \"$path\""
fi

if declare -F harness_worktree_setup >/dev/null; then
  harness_worktree_setup "$path" "$slug"
fi

echo
echo "Worktree ready: $path (branch $branch)"
if declare -F harness_worktree_next_steps >/dev/null; then
  harness_worktree_next_steps "$path"
fi
echo "When the branch is merged: git worktree remove \"$path\" && git branch -d $branch"
