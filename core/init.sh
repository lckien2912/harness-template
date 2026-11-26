#!/usr/bin/env bash
# Baseline gates: the same script runs locally, at the start of every agent
# session, before a feature is marked `pass`, in CI, and before every push when
# the optional .githooks/pre-push is on (with RUN_INTEGRATION=1).
#
#   bash init.sh                    # harness + required gates
#   RUN_INTEGRATION=1 bash init.sh  # also the integration gates
#
# Everything project-specific lives in .harness/config.sh (gates, setup,
# required files). This file is the framework-agnostic driver; do not weaken a
# gate here, change it in the config and say so in the pull request.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .harness/config.sh ]]; then
  echo "ERROR: .harness/config.sh is missing (install the harness first)."
  exit 1
fi

HARNESS_REQUIRED_FILES=()
HARNESS_GATES=()
HARNESS_INTEGRATION_GATES=()
HARNESS_APP_MARKER=""
harness_setup() { :; }
# shellcheck source=/dev/null
source .harness/config.sh

echo "=== ${HARNESS_PROJECT_NAME:-project} harness baseline ==="

missing=0
for file in AGENTS.md CLAUDE.md feature_list.json feature_list.schema.json progress.md \
  ${HARNESS_REQUIRED_FILES[@]+"${HARNESS_REQUIRED_FILES[@]}"}; do
  if [[ ! -f "$file" ]]; then
    echo "MISSING: $file"
    missing=1
  fi
done
[[ $missing -eq 0 ]] || exit 1

if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: node (>= 18) is required by the harness scripts (not by the app)."
  exit 1
fi
node scripts/check-harness.mjs

echo "=== guardrail hooks ==="
bash scripts/test-guardrails.sh >/dev/null && echo "Guardrail hooks: PASS" || {
  echo "Guardrail hooks: FAIL (run bash scripts/test-guardrails.sh for details)"
  exit 1
}

# Project checks: every file in .harness/checks/ (sh, mjs/js, py) is run.
if [[ -d .harness/checks ]]; then
  for check in .harness/checks/*; do
    [[ -f "$check" ]] || continue
    case "$check" in
      *.sh) runner=(bash) ;;
      *.mjs | *.js) runner=(node) ;;
      *.py) runner=(python3 -I) ;;
      *) continue ;;
    esac
    echo "=== check: ${check#.harness/checks/} ==="
    "${runner[@]}" "$check" "$ROOT_DIR"
  done
fi

if [[ -n "$HARNESS_APP_MARKER" && ! -e "$HARNESS_APP_MARKER" ]]; then
  echo "$HARNESS_APP_MARKER not present yet; app gates skipped."
  echo "=== Initialization complete ==="
  exit 0
fi

echo "=== setup ==="
harness_setup

# run_gate "<name>|<command>": the command is evaluated in this shell's
# environment (functions from .harness/config.sh are available) inside a
# subshell rooted at the repository.
run_gate() {
  local name="${1%%|*}" cmd="${1#*|}"
  echo "=== $name ==="
  (cd "$ROOT_DIR" && eval "$cmd")
}

for gate in ${HARNESS_GATES[@]+"${HARNESS_GATES[@]}"}; do
  run_gate "$gate"
done

echo "=== architecture boundaries ==="
bash scripts/check-architecture.sh

if [[ "${RUN_INTEGRATION:-0}" == "1" ]]; then
  if [[ ${#HARNESS_INTEGRATION_GATES[@]} -eq 0 ]]; then
    echo "RUN_INTEGRATION=1 but no integration gates are configured."
  fi
  for gate in ${HARNESS_INTEGRATION_GATES[@]+"${HARNESS_INTEGRATION_GATES[@]}"}; do
    run_gate "$gate"
  done
elif [[ ${#HARNESS_INTEGRATION_GATES[@]} -gt 0 ]]; then
  echo "Integration gates skipped (set RUN_INTEGRATION=1 to run them)."
fi

echo "=== Initialization complete ==="
