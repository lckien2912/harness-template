# shellcheck shell=bash
# Harness configuration: the only place that knows the stack. Sourced by
# init.sh, the hooks and the scripts; keep it to variables and functions (no
# side effects at source time). Changing a gate is a Protected Decision.

HARNESS_PROJECT_NAME="{{PROJECT_NAME}}"

# Branch model (AGENTS.md "Branches and Worktrees").
HARNESS_MAIN_BRANCH="main"
HARNESS_PHASE_PREFIX="phase/"
HARNESS_FEATURE_PREFIX="feat/"

# Files init.sh requires on top of AGENTS.md, CLAUDE.md, feature_list.json,
# feature_list.schema.json and progress.md.
HARNESS_REQUIRED_FILES=(
  docs/PRODUCT.md
  docs/ROADMAP.md
  docs/ARCHITECTURE.md
)

# When set and missing, init.sh stops after the harness checks (the app is not
# scaffolded yet), e.g. "package.json", "pyproject.toml", "go.mod".
HARNESS_APP_MARKER=""

# Generated output: never edited, never committed, never searched or linted.
HARNESS_GENERATED_DIRS=(dist build out coverage)

# Globs check-architecture.sh never searches (tests, fixtures).
HARNESS_ARCH_EXCLUDES=()

# Install dependencies reproducibly (frozen lockfile). Runs before the gates.
harness_setup() {
  :
}

# Required gates, in order: "name|command". The command is eval'ed from the
# repository root and may call functions defined in this file. Every gate must
# be deterministic and must not need network services.
HARNESS_GATES=(
  # "lint|make lint"
  # "unit tests|make test"
  # "build|make build"
)

# Opt-in gates (RUN_INTEGRATION=1): need a database or other live services.
HARNESS_INTEGRATION_GATES=(
  # "integration tests|make test-integration"
)

# scripts/new-worktree.sh: "example:target" env files copied into a new
# worktree, and an optional per-worktree dev database.
HARNESS_WORKTREE_ENV_FILES=(
  # ".env.example:.env"
)
HARNESS_WORKTREE_DB_ENGINE="none" # none | postgres
HARNESS_WORKTREE_DB_PREFIX="app"
HARNESS_WORKTREE_DB_URL_VAR="DATABASE_URL"
HARNESS_WORKTREE_DB_ENV_FILE=".env"

harness_worktree_next_steps() {
  echo "Next, inside it: install dependencies, then run bash init.sh."
}
