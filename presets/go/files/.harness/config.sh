# shellcheck shell=bash
# Harness configuration (preset: go). Sourced by init.sh, the hooks and the
# scripts; variables and functions only. Changing a gate is a Protected
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

HARNESS_APP_MARKER="go.mod"

HARNESS_GENERATED_DIRS=(bin dist build coverage tmp)
HARNESS_ARCH_EXCLUDES=('*_test.go' 'testdata')

harness_setup() {
  command -v go >/dev/null 2>&1 || { echo "ERROR: go is required but was not found." >&2; return 1; }
  go version
  go mod download
  # go.mod/go.sum must already be tidy: a dirty diff fails the baseline.
  go mod verify
}

go_fmt() {
  local unformatted
  unformatted="$(gofmt -l $(go list -f '{{.Dir}}' ./... 2>/dev/null) 2>/dev/null || true)"
  if [[ -n "$unformatted" ]]; then
    echo "gofmt needed:"
    echo "$unformatted"
    return 1
  fi
}

go_lint() {
  if command -v golangci-lint >/dev/null 2>&1; then
    golangci-lint run ./...
  else
    echo "golangci-lint is not installed; go vet only."
  fi
}

HARNESS_GATES=(
  "format|go_fmt"
  "vet|go vet ./..."
  "lint|go_lint"
  "unit tests|go test -short -race -count=1 ./..."
  "build|go build ./..."
)

# Integration tests carry the `integration` build tag (//go:build integration).
HARNESS_INTEGRATION_GATES=(
  "integration tests|go test -tags=integration -count=1 ./..."
)

HARNESS_WORKTREE_ENV_FILES=(
  ".env.example:.env"
)
HARNESS_WORKTREE_DB_ENGINE="none" # none | postgres
HARNESS_WORKTREE_DB_PREFIX="{{PROJECT_SLUG}}"
HARNESS_WORKTREE_DB_URL_VAR="DATABASE_URL"
HARNESS_WORKTREE_DB_ENV_FILE=".env"

harness_worktree_next_steps() {
  echo "Next, inside it: go mod download, apply migrations (asks for approval), then bash init.sh."
}
