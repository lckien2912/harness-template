# 1. Adopt the agentic development harness

Date: {{DATE}}
Status: Accepted

## Context

{{PROJECT_NAME}} is developed with coding agents. Without a shared contract,
fixed gates and a resumable record, each session re-derives the state of the
project, gates drift, and destructive commands depend on the agent's judgment
alone.

## Decision

We adopt the agent harness template (preset `{{PRESET}}`):

- **Operating contract** in `AGENTS.md`; commands indexed in `CLAUDE.md`.
- **Work loop:** read the contract and `progress.md` → take one feature from
  `feature_list.json` → vertical slice in its own worktree → verify against
  fixed gates → record evidence in `verification/reports/<id>.md` → hand off.
- **Gates** in `init.sh`, configured by `.harness/config.sh`, run identically
  locally and in CI. Integration gates are opt-in (`RUN_INTEGRATION=1`).
- **Architecture check** is small and high-signal: only boundaries a linter
  will not catch, as data in `.harness/architecture.rules`.
- **Guardrails:** `.claude/settings.json` permission rules plus Pre/PostToolUse
  hooks driven by `.harness/guard*.rules` and `.harness/post-edit.rules`, with
  their own test cases.
- **Product scope** is human-owned. `docs/PRODUCT.md` starts as a TBD template
  and `feature_list.json` opens the `{{MILESTONE}}` milestone with an empty
  backlog. The agent does not invent scope.

## Consequences

- Every gate change is a Protected Decision and goes through review.
- The guardrail hooks must be trusted in Claude Code per fresh session
  (restart if added mid-session) for the hook layers to fire.
- The harness scripts need `node` (>= 18) and `git` on every machine and CI
  runner, whatever language the application uses.
