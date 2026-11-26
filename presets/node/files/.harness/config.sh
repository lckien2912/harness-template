# shellcheck shell=bash
# Harness configuration (preset: node). The only place that knows the stack.
# Sourced by init.sh, the hooks and the scripts; keep it to variables and
# functions (no side effects at source time). Changing a gate is a Protected
# Decision.

HARNESS_PROJECT_NAME="{{PROJECT_NAME}}"

HARNESS_MAIN_BRANCH="main"
HARNESS_PHASE_PREFIX="phase/"
HARNESS_FEATURE_PREFIX="feat/"

HARNESS_REQUIRED_FILES=(
  docs/PRODUCT.md
  docs/ROADMAP.md
  docs/ARCHITECTURE.md
)

# Directory of the package whose scripts are the gates ("." for a single
# package or a workspace root that fans out with turbo/nx/pnpm -r).
HARNESS_NODE_APP_DIR="."
HARNESS_APP_MARKER="$HARNESS_NODE_APP_DIR/package.json"

HARNESS_GENERATED_DIRS=(dist build out coverage .next .nuxt .svelte-kit .turbo .output .vercel storybook-static)
HARNESS_ARCH_EXCLUDES=('*.test.*' '*.spec.*' '__tests__' '__mocks__' '*.stories.*')

# The lockfile decides the package manager; exactly one lockfile may exist.
# Node stays the runtime for bun projects too unless the project says otherwise.
harness_detect_pm() {
  local found=()
  [[ -f bun.lock || -f bun.lockb ]] && found+=(bun)
  [[ -f pnpm-lock.yaml ]] && found+=(pnpm)
  [[ -f yarn.lock ]] && found+=(yarn)
  [[ -f package-lock.json ]] && found+=(npm)
  if [[ ${#found[@]} -gt 1 ]]; then
    echo "ERROR: several lockfiles (${found[*]}); keep exactly one." >&2
    return 1
  elif [[ ${#found[@]} -eq 0 ]]; then
    echo "ERROR: no lockfile (bun.lock, pnpm-lock.yaml, yarn.lock or package-lock.json)." >&2
    return 1
  fi
  PM="${found[0]}"
  if ! command -v "$PM" >/dev/null 2>&1; then
    echo "ERROR: $PM is required but was not found." >&2
    return 1
  fi
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

# node_script <script> [dir]: runs a package.json script with the detected
# package manager; prints "skipped" when the package has no such script, so a
# gate appears the day the script is added.
node_script() {
  local script="$1" dir="${2:-$HARNESS_NODE_APP_DIR}"
  if node -e 'const s=require(require("path").resolve(process.argv[1],"package.json")).scripts||{};process.exit(s[process.argv[2]]?0:1)' "$dir" "$script"; then
    (cd "$dir" && "$PM" run "$script")
  else
    echo "No \"$script\" script in $dir/package.json; gate skipped."
  fi
}

HARNESS_GATES=(
  "lint|node_script lint"
  "typecheck|node_script typecheck"
  "unit tests|node_script test"
  "build|node_script build"
)

HARNESS_INTEGRATION_GATES=(
  "integration tests|node_script test:integration"
)

HARNESS_WORKTREE_ENV_FILES=(
  ".env.example:.env"
)
HARNESS_WORKTREE_DB_ENGINE="none" # none | postgres
HARNESS_WORKTREE_DB_PREFIX="app"
HARNESS_WORKTREE_DB_URL_VAR="DATABASE_URL"
HARNESS_WORKTREE_DB_ENV_FILE=".env"

harness_worktree_next_steps() {
  echo "Next, inside it: install dependencies with the project's package manager, then bash init.sh."
}
