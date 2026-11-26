# Harness

Owner: human for policy; agent keeps the list current.

The harness is the set of files that let a coding agent resume work safely. The
rules for using them are in `AGENTS.md`. How to close a milestone is in
`.claude/commands/cleanup-sprint.md` (the only place that describes rotation).
The harness was installed from a template; `.harness/manifest` records which
template version and preset.

| Artifact                                     | Lifecycle                 | Notes                                                                                                                      |
| -------------------------------------------- | ------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `AGENTS.md`                                  | Persistent                | The contract; humans own policy                                                                                            |
| `CLAUDE.md`                                  | Persistent                | Command index                                                                                                              |
| `docs/PRODUCT.md`, `docs/ROADMAP.md`         | Persistent                | Scope (human-owned) and the phased backlog                                                                                 |
| `docs/ARCHITECTURE.md`, `docs/GUARDRAILS.md` | Persistent                | Kept in step with the code, `.claude/` and `.harness/`                                                                     |
| `docs/decisions/`                            | Append-only               | ADRs; a superseded ADR keeps its text and gains a status line                                                              |
| `feature_list.json` (+ schema)               | Per milestone (one phase) | Status and evidence of the current phase's features                                                                        |
| `verification/reports/<id>.md`               | Per feature               | Evidence; archived with the milestone                                                                                      |
| `progress.md`                                | Current state             | Phase-level resume point; fixed sections, overwritten                                                                      |
| `docs/archive/<milestone>-<date>/`           | Frozen                    | Closed milestones                                                                                                          |
| `.harness/`                                  | Persistent                | Gates (`config.sh`), guard rules and cases, post-edit rules, architecture rules, extra checks (`checks/`)                  |
| `.claude/`                                   | Persistent                | Settings, hooks, commands (`/prepare-phase`, `/feature`, `/cleanup-sprint`)                                                |
| `init.sh`, `scripts/`                        | Persistent                | Gates: `check-harness.mjs`, `test-guardrails.sh`, `check-architecture.sh`, `cleanup-scanner.sh`; helper: `new-worktree.sh` |
| `.github/workflows/ci.yml`                   | Persistent                | Runs `init.sh` (and the integration gates) on every pull request                                                           |
| `.githooks/pre-push`                         | Persistent (optional)     | `RUN_INTEGRATION=1 bash init.sh` before every push, once `git config core.hooksPath .githooks` is set                      |
| `docs/phases/pN.md`                          | Per phase                 | Approved phase checklist, written by `/prepare-phase`                                                                      |
