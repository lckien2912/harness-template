# shellcheck shell=bash
# Harness configuration (preset: medusa, extends node). Medusa v2 backend in
# a Bun/pnpm workspace, optionally with Mercur on top. Sourced by init.sh, the
# hooks and the scripts; variables and functions only. Changing a gate is a
# Protected Decision.

HARNESS_PROJECT_NAME="{{PROJECT_NAME}}"

HARNESS_MAIN_BRANCH="main"
HARNESS_PHASE_PREFIX="phase/"
HARNESS_FEATURE_PREFIX="feat/"

HARNESS_REQUIRED_FILES=(
  docs/PRODUCT.md
  docs/ROADMAP.md
  docs/ARCHITECTURE.md
)

# The Medusa backend package.
HARNESS_NODE_APP_DIR="apps/backend"
HARNESS_APP_MARKER="$HARNESS_NODE_APP_DIR/package.json"

HARNESS_GENERATED_DIRS=(dist build coverage .medusa .mercur .turbo)
HARNESS_ARCH_EXCLUDES=('*.spec.ts' '*.unit.spec.ts')

harness_detect_pm() {
  local found=()
  [[ -f bun.lock || -f bun.lockb ]] && found+=(bun)
  [[ -f pnpm-lock.yaml ]] && found+=(pnpm)
  [[ -f yarn.lock ]] && found+=(yarn)
  [[ -f package-lock.json ]] && found+=(npm)
  if [[ ${#found[@]} -ne 1 ]]; then
    echo "ERROR: expected exactly one lockfile, found: ${found[*]:-none}." >&2
    return 1
  fi
  PM="${found[0]}"
  command -v "$PM" >/dev/null 2>&1 || { echo "ERROR: $PM is required but was not found." >&2; return 1; }
  export PM
}

harness_setup() {
  harness_detect_pm
  echo "Package manager: $PM"
  case "$PM" in
    npm) npm ci ;;
    yarn) yarn install --immutable 2>/dev/null || yarn install --frozen-lockfile ;;
    *) "$PM" install --frozen-lockfile ;;
  esac
}

backend() { (cd "$HARNESS_NODE_APP_DIR" && "$PM" run "$@"); }

# jest exits non-zero on "no tests found": run the unit gate once a unit spec exists.
backend_unit() {
  if find "$HARNESS_NODE_APP_DIR/src" -name '*.unit.spec.ts' -not -path '*/node_modules/*' 2>/dev/null | grep -q .; then
    backend test:unit
  else
    echo "No *.unit.spec.ts files yet; unit gate skipped."
  fi
}

# `medusa build` type-checks; there is no separate typecheck gate.
HARNESS_GATES=(
  "backend lint|backend lint"
  "backend unit tests|backend_unit"
  "backend build|backend build"
)

# Medusa integration suites need a live Postgres (DB_USERNAME, DB_PASSWORD,
# DB_HOST, DB_PORT).
HARNESS_INTEGRATION_GATES=(
  "backend integration tests (modules)|backend test:integration:modules"
  "backend integration tests (http)|backend test:integration:http"
)

HARNESS_WORKTREE_ENV_FILES=(
  "apps/backend/.env.example:apps/backend/.env"
)
HARNESS_WORKTREE_DB_ENGINE="postgres"
HARNESS_WORKTREE_DB_PREFIX="{{PROJECT_SLUG}}"
HARNESS_WORKTREE_DB_URL_VAR="DATABASE_URL"
HARNESS_WORKTREE_DB_ENV_FILE="apps/backend/.env"

harness_worktree_next_steps() {
  cat <<EOF
Next, inside it:
  $([[ -f "$1/bun.lock" ]] && echo bun || echo pnpm) install
  cd apps/backend && npx medusa db:migrate   # asks for approval
Fill the other variables in apps/backend/.env as the feature needs them.
EOF
}
