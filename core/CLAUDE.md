# CLAUDE.md

`AGENTS.md` is the operating contract: read it first. This file only indexes
commands; `.harness/config.sh` (gates) and the project's own manifests are the
source of truth.

Slash commands: `/prepare-phase <N>` (plan a roadmap phase: checklist,
features, acceptance criteria), `/feature <feat-id>`, `/cleanup-sprint [next]`.

```bash
# Baseline gates (harness, guardrails, project gates, architecture)
bash init.sh
# Same, plus the integration gates
RUN_INTEGRATION=1 bash init.sh
```

{{snippet:commands}}

```bash
# Harness
node scripts/check-harness.mjs
bash scripts/test-guardrails.sh
bash scripts/check-architecture.sh
bash scripts/cleanup-scanner.sh   # also lists merged branches and worktrees
bash scripts/new-worktree.sh feat/pN.M-<slug>   # worktree + env files (+ dev database)
bash .githooks/pre-push           # the pre-push gates, ahead of a push (optional hook)
```
