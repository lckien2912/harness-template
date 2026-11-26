# shellcheck shell=bash
# Harness configuration (preset: nest, extends node). NestJS API in
# TypeScript: a standalone app, a Nest CLI monorepo (apps/*, libs/*) or one
# package of a JS workspace. Sourced by init.sh, the hooks and the scripts;
# variables and functions only. Changing a gate is a Protected Decision.

HARNESS_PROJECT_NAME="{{PROJECT_NAME}}"

HARNESS_MAIN_BRANCH="main"
HARNESS_PHASE_PREFIX="phase/"
HARNESS_FEATURE_PREFIX="feat/"

HARNESS_REQUIRED_FILES=(
  docs/PRODUCT.md
  docs/ROADMAP.md
  docs/ARCHITECTURE.md
)

# Directory holding nest-cli.json and the API's package.json: "." for a
# standalone app or a Nest CLI monorepo, e.g. "apps/api" inside a pnpm/turbo
# workspace.
HARNESS_NODE_APP_DIR="."
HARNESS_APP_MARKER="$HARNESS_NODE_APP_DIR/nest-cli.json"

HARNESS_GENERATED_DIRS=(dist build coverage .turbo .nx)
HARNESS_ARCH_EXCLUDES=('*.spec.ts' '*.e2e-spec.ts' '__tests__' '__mocks__')

# The lockfile decides the package manager; exactly one lockfile may exist.
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

# script_body <script> [dir]: prints the package.json script, fails if absent.
script_body() {
  node -e 'const s=(require(require("path").resolve(process.argv[1],"package.json")).scripts||{})[process.argv[2]];if(!s)process.exit(1);console.log(s)' \
    "${2:-$HARNESS_NODE_APP_DIR}" "$1"
}

# node_script <script> [dir]: runs a package.json script with the detected
# package manager; prints "skipped" when the package has no such script, so a
# gate appears the day the script is added.
node_script() {
  local script="$1" dir="${2:-$HARNESS_NODE_APP_DIR}"
  if script_body "$script" "$dir" >/dev/null; then
    (cd "$dir" && "$PM" run "$script")
  else
    echo "No \"$script\" script in $dir/package.json; gate skipped."
  fi
}

# `nest new` writes `eslint ... --fix` as the lint script. A gate that rewrites
# files passes on anything fixable and leaves CI green on unformatted code; the
# post-edit hook already fixes each edited file. Drop --fix from "lint" (or add
# a "lint:check" script without it, which then wins).
nest_lint() {
  if script_body lint:check >/dev/null; then
    node_script lint:check
    return
  fi
  if script_body lint 2>/dev/null | grep -q -- '--fix'; then
    echo "ERROR: the \"lint\" script runs --fix, so the gate cannot fail on fixable problems." >&2
    echo "Remove --fix from it in $HARNESS_NODE_APP_DIR/package.json, or add a \"lint:check\" script." >&2
    return 1
  fi
  node_script lint
}

# `nest build` type-checks only with the tsc builder (swc skips it unless
# "typeCheck": true), and tsconfig.build.json leaves the specs out. So check
# the full tsconfig.json, specs included, unless a "typecheck" script exists.
nest_typecheck() {
  if script_body typecheck >/dev/null; then
    node_script typecheck
    return
  fi
  local root="$PWD" tsc
  for tsc in "$root/$HARNESS_NODE_APP_DIR/node_modules/.bin/tsc" "$root/node_modules/.bin/tsc"; do
    if [[ -x "$tsc" ]]; then
      (cd "$HARNESS_NODE_APP_DIR" && "$tsc" --noEmit -p tsconfig.json)
      return
    fi
  done
  echo "ERROR: typescript is not installed (no node_modules/.bin/tsc); add a \"typecheck\" script or install it." >&2
  return 1
}

# Formatter check (Prettier: `"format:check": "prettier --check ."`); the
# post-edit hook writes. Skipped when package.json has no such script.
nest_format() {
  node_script format:check
}

HARNESS_GATES=(
  "lint|nest_lint"
  "format|nest_format"
  "typecheck|nest_typecheck"
  "unit tests|node_script test"
  "build|node_script build"
)

# e2e specs boot AppModule and usually need the database and other services.
HARNESS_INTEGRATION_GATES=(
  "e2e tests|node_script test:e2e"
  "integration tests|node_script test:integration"
)

HARNESS_WORKTREE_ENV_FILES=(
  ".env.example:.env"
)
# Set to postgres when the API owns a Postgres database: each worktree then
# gets its own <prefix>_<slug> database written to DATABASE_URL in .env.
HARNESS_WORKTREE_DB_ENGINE="none" # none | postgres
HARNESS_WORKTREE_DB_PREFIX="{{PROJECT_SLUG}}"
HARNESS_WORKTREE_DB_URL_VAR="DATABASE_URL"
HARNESS_WORKTREE_DB_ENV_FILE=".env"

harness_worktree_next_steps() {
  cat <<EOF
Next, inside it:
  <pm> install      (the package manager the lockfile names)
  run the ORM's migrations against the worktree database (asks for approval)
  bash init.sh
EOF
}
