# AGENTS.md

This file is the project-wide operating contract for coding agents working on
**{{PROJECT_NAME}}**. Product requirements and quality thresholds are
human-owned. Agents may maintain implementation details and evidence, but must
not silently weaken a rule, acceptance criterion, or verification gate.

Companion documents:

- `CLAUDE.md`: command index.
- `docs/PRODUCT.md`: scope (human-owned).
- `docs/ROADMAP.md`: the phased backlog.
- `docs/ARCHITECTURE.md`: layout and boundaries.
- `docs/GUARDRAILS.md`: mechanical enforcement.
- `docs/HARNESS.md`: harness artifacts.
<!-- Add per-app contracts here, e.g. `apps/api/AGENTS.md`: API conventions. -->

## Target Stack

{{snippet:stack}}

**Versions are pinned.** Upgrading the framework or a major dependency is a
feature of its own: read its changelog, upgrade the related packages together,
and pass the smoke tests.

## Branches and Worktrees

- **One branch per phase:** `phase/pN-<slug>`, cut from `main`.
- **One branch per feature:** `feat/pN.M-<slug>`, cut from the phase branch, in
  its own worktree.
- A feature starts only when its dependencies are merged into the phase branch.
- Rebase on the phase branch before merging.
- The phase branch reaches `main` through one reviewed pull request.

When features run in parallel:

- each feature edits only its own `feature_list.json` entry and its own
  `verification/reports/<id>.md`;
- only the coordinating session updates `progress.md`;
- each worktree uses its own local resources (env files, dev database, ports).

**Creating a worktree.** Run `bash scripts/new-worktree.sh <branch> [base]`. It
creates the worktree in `.claude/worktrees/<branch-with-dashes>`, cuts the
branch, and prepares the env files and dev database `.harness/config.sh`
describes.

Cleaning up after a merge (the coordinating session does it):

- **After a feature branch merges into the phase branch:**
  1. remove its worktree with `git worktree remove <path>`; refuse if the
     worktree has uncommitted changes and report them instead;
  2. delete the branch locally with `git branch -d` (never `-D`), and on the
     remote with `git push origin --delete`;
  3. optionally drop the feature's dev database (asks for approval);
  4. record the merge in `progress.md`.
- **After the phase branch merges into `main`:** remove the phase worktree and
  delete the phase branch in the same way (`/cleanup-sprint`).
- `bash scripts/cleanup-scanner.sh` lists worktrees and branches that have no
  commits outside `main` or a phase branch.
- Force-pushing is denied to agents. A rebase of a pushed branch is pushed by
  the owner.

## Startup Workflow

Before editing code:

1. Confirm the working directory, branch and `git status`.
2. Read this file, then `progress.md`.
3. Read the relevant parts of `docs/PRODUCT.md`, `docs/ROADMAP.md` and
   `docs/ARCHITECTURE.md`.
4. Read `feature_list.json` and take **one** feature for this worktree.
5. Run `bash init.sh`.
6. State the selected feature, intended files, and verification plan.

If the baseline fails, record the failure and fix it before adding feature work.
Do not convert a baseline failure into a weaker gate.

## Work Policy

**One feature per worktree.** For each feature:

1. Work one vertical slice at a time:
   {{snippet:slice}}
2. Keep changes inside the feature's scope.
3. Add or update tests with behavioural changes.
4. Run the narrowest relevant checks while implementing, and the full gates
   before marking the feature `pass`.
5. Record evidence in `feature_list.json` and write
   `verification/reports/<feat-id>.md` (from `verification/reports/TEMPLATE.md`).

Statuses:

- `not-started`, `in-progress`, `blocked`, `pass`;
- `superseded`, with the reason and where the work went in `evidence`.

A feature may return from `pass` to `in-progress` when a regression is found.

## Definition of Done

A feature is complete only when:

1. Its acceptance criteria are satisfied.
2. Relevant tests pass: unit always; integration for anything touching a
   database, a network boundary or a public interface.
3. `bash init.sh` passes (and `RUN_INTEGRATION=1 bash init.sh` when the
   feature needs it). That covers the harness check, the guardrail tests, every
   gate in `.harness/config.sh`, and `scripts/check-architecture.sh`. CI runs
   the same on every pull request.
4. Schema changes ship as a forward migration that applies cleanly. No existing
   migration is rewritten.
5. Documentation reflects any public API, schema, or boundary change.
6. `feature_list.json` holds current evidence, and
   `verification/reports/<feat-id>.md` exists.
7. The repository is left in a resumable state.

## Protected Decisions

Agents must ask before:

- Changing product scope or acceptance criteria.
- Changing authentication, authorization, privacy, or data-retention policy.
- Adding a production dependency.
- Changing module boundaries or introducing a new shared module.
- Changing the migration strategy, or running a destructive database command
  against any non-disposable database.
- Changing deployment, environment, or secret-management strategy.
- Upgrading the framework or a major dependency.
- Modifying or removing a verification threshold or gate (including anything
  in `.harness/`, `init.sh` and `.github/workflows/`).
- Performing destructive data or git operations.

{{snippet:protected}}

Accepting an ADR or an approved phase plan approves the decisions it lists.
Each one still goes through its own pull request.

## Deployment and Review Discipline

- Never auto-deploy to production. Land changes through pull requests and wait
  for human review.
- Flag any change that touches payment, checkout, authentication, or
  authorization logic in the pull-request description for careful review.

## Enforced Guardrails

Permission rules in `.claude/settings.json`, plus PreToolUse and PostToolUse
hooks under `.claude/hooks/` driven by the rule files in `.harness/`, back
parts of this contract mechanically. `scripts/test-guardrails.sh` tests the
hooks. `docs/GUARDRAILS.md` lists what each layer enforces. Guardrails are a
backstop, not a substitute for following this contract.

## Framework References

{{snippet:references}}

## Off-Limits

{{snippet:offlimits}}

- `.env` files: never read, commit, print, or copy secrets out. Document
  variables in the matching `.env.example`.
- Destructive data or git operations without explicit confirmation.

## End of Session

1. `bash init.sh` passes, or the failure is recorded.
2. The feature's status and evidence in `feature_list.json` are current, and so
   is its report.
3. The coordinating session updates `progress.md`. It overwrites the fixed
   sections (Current state, What's next, Blockers, Decisions) with only what a
   new session needs to resume.
4. Unresolved risks and failing checks are recorded explicitly.
