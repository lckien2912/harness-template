# shellcheck shell=bash
# Harness configuration (preset: python). Works with uv, Poetry or a plain
# virtualenv; Django, FastAPI, Flask alike. Sourced by init.sh, the hooks and
# the scripts; variables and functions only. Changing a gate is a Protected
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

HARNESS_APP_MARKER="pyproject.toml"

HARNESS_GENERATED_DIRS=(.venv venv build dist htmlcov .pytest_cache .mypy_cache .ruff_cache __pycache__ .tox site)
HARNESS_ARCH_EXCLUDES=('test_*.py' '*_test.py' 'conftest.py' 'tests')

# The lockfile decides the runner: uv.lock -> uv, poetry.lock -> Poetry,
# otherwise the active virtualenv.
harness_detect_runner() {
  if [[ -f uv.lock ]]; then
    PY_RUN=(uv run --frozen)
  elif [[ -f poetry.lock ]]; then
    PY_RUN=(poetry run)
  else
    PY_RUN=()
  fi
}

harness_setup() {
  harness_detect_runner
  if [[ -f uv.lock ]]; then
    uv sync --frozen
  elif [[ -f poetry.lock ]]; then
    poetry install --no-interaction --sync
  elif [[ -n "${VIRTUAL_ENV:-}" ]]; then
    echo "No uv.lock/poetry.lock; using the active virtualenv $VIRTUAL_ENV as is."
  else
    echo "ERROR: no uv.lock or poetry.lock and no active virtualenv." >&2
    return 1
  fi
}

# py_tool <tool> [args...]: runs a dev tool through the project runner; skips
# the gate when the tool is not installed, so it appears once it is added to
# the dev dependencies.
py_tool() {
  local tool="$1"
  shift
  if [[ ${#PY_RUN[@]} -gt 0 ]]; then
    if ! "${PY_RUN[@]}" "$tool" --version >/dev/null 2>&1; then
      echo "$tool is not a dev dependency; gate skipped."
      return 0
    fi
    "${PY_RUN[@]}" "$tool" "$@"
  elif command -v "$tool" >/dev/null 2>&1; then
    "$tool" "$@"
  else
    echo "$tool is not installed; gate skipped."
  fi
}

# pytest exits 5 when no test was collected: treat that as "no tests yet".
py_pytest() {
  local code=0
  py_tool pytest "$@" || code=$?
  if [[ $code -eq 5 ]]; then
    echo "No tests collected; gate skipped."
    return 0
  fi
  return $code
}

HARNESS_GATES=(
  "lint|py_tool ruff check ."
  "format|py_tool ruff format --check ."
  "types|py_tool mypy ."
  "unit tests|py_pytest -q -m 'not integration'"
)

# Mark tests that need live services with @pytest.mark.integration.
HARNESS_INTEGRATION_GATES=(
  "integration tests|py_pytest -q -m integration"
)

HARNESS_WORKTREE_ENV_FILES=(
  ".env.example:.env"
)
HARNESS_WORKTREE_DB_ENGINE="none" # none | postgres
HARNESS_WORKTREE_DB_PREFIX="{{PROJECT_SLUG}}"
HARNESS_WORKTREE_DB_URL_VAR="DATABASE_URL"
HARNESS_WORKTREE_DB_ENV_FILE=".env"

harness_worktree_next_steps() {
  echo "Next, inside it: uv sync (or poetry install), apply migrations (asks for approval), then bash init.sh."
}
