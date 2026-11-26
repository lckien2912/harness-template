---
description: Plan phase N from docs/ROADMAP.md — phase checklist, features split into slices, acceptance criteria — then load them into feature_list.json after approval. Does not implement anything.
argument-hint: <phase-number>  e.g. 1
---

Prepare phase `$ARGUMENTS` of `docs/ROADMAP.md` for implementation. This is
sprint planning: it writes the phase checklist and the backlog, and stops.
`AGENTS.md` stays authoritative; scope and acceptance criteria are
human-owned, so nothing is written to `feature_list.json` before the owner
approves the plan (step 4).

## 1. Preconditions (stop and report if one fails)

- `$ARGUMENTS` is an integer and `docs/ROADMAP.md` has
  `## Phase $ARGUMENTS — <name>` with a feature table.
- `feature_list.json` holds no unfinished feature of another milestone (every
  feature is `pass` or `superseded`, or the list is empty). Otherwise the
  previous phase is still open: suggest `/cleanup-sprint`, do not mix phases.
- Every row of earlier phases that this phase depends on is `done` in the
  roadmap; list the ones that are not.
- The working tree is clean.

## 2. Read

- `docs/ROADMAP.md` (the phase), `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`,
  `progress.md`, `feature_list.json`, `docs/decisions/`.
- The design or spec documents `AGENTS.md` lists under its references: the
  sections for every area the phase touches. They are the source for concrete
  numbers and rules.
- Owner plan documents (`docs/plans/`, when the project keeps them): when one
  covers this phase, it is the most recent owner decision and wins over
  `docs/ROADMAP.md` and the design docs. List every conflict (scope, rules,
  numbers) in the draft and update the roadmap rows only after approval.
- When another repository consumes or provides this one's API, its roadmap:
  which of its features wait for this phase, so the contract each one needs
  is part of the plan.

## 3. Draft (in the conversation, nothing written yet)

**a. Phase checklist**, from the phase's "Done when" line:

- exit criteria, each observable and checkable by a command, a test or a
  screen;
- the phase smoke test: the one automated flow that proves the exit criteria
  (the `phase/… → main` pull request opens only when it is green);
- owner decisions and external prerequisites that must be settled first
  (accounts, keys, legal, design), each with who decides;
- per area touched: schema and migration, public interfaces or events added,
  external services and their sandbox, and how it is rolled out (feature
  flag, staging first);
- the API contract a consumer needs (endpoints, payloads, errors), agreed
  before the feature that consumes it.

**b. Features.** Split each roadmap row into features of size S or M (an L
row is always split). One feature = one vertical slice that can merge on its
own (the slice order in `AGENTS.md` **Work Policy**) and is testable end to
end.

- ids continue from the highest `feat-N` ever used, `docs/archive/` included;
- `name`: `"[P$ARGUMENTS.M] <short title>"`, M following the roadmap row
  (split rows: `P$ARGUMENTS.3a`, `P$ARGUMENTS.3b`);
- `description`: what and why in 1–3 sentences, the files/areas it touches,
  and what is explicitly out of scope;
- `dependencies`: feat ids inside this phase only; a dependency outside it
  that is not done makes the feature `blocked`, said in `evidence`;
- order the list so parallel work is visible: features that touch the same
  files depend on each other, so they never merge at the same time.

**c. Acceptance criteria**, 3–7 per feature. Each criterion:

- states one observable behaviour, with concrete values (inputs, limits,
  status codes, texts), never "works correctly" or "is fast";
- names how it is verified: `[unit]`, `[e2e]`, `[integration]` or
  `[manual: <steps>]`;
- covers the failure path too (invalid input, no permission, a service down),
  not only the happy path.

Add the criteria this project always needs when they apply, for example:

- an endpoint: input validation errors (400), unauthenticated (401), a caller
  outside its scope (403/404) `[e2e]`;
- a migration: applies forward on a fresh database `[integration]`;
- an event or message: a versioned contract; the consumer handles the same
  message twice with one effect `[integration]`;
- an external service: behind an interface with a fake in tests; a wrong
  webhook signature is rejected `[unit]`;
- a UI screen: mobile and desktop screenshots in the report, keyboard and
  screen-reader basics `[manual: …]` or `[e2e]`.

Keep the project's own list in `AGENTS.md` (or here) as it grows: a rule the
owner repeats at review becomes a default criterion.

Do not invent scope: a criterion that needs a number or rule the docs do not
give becomes an owner question, and a feature that cannot start without the
answer is `blocked` with the question in `evidence`.

## 4. Approval

Show the checklist, the feature table (id, name, size, dependencies) and the
criteria, plus the open questions. Wait for the owner's approval or edits; do
not continue on silence.

## 5. Write (after approval)

1. Create the phase branch `phase/p$ARGUMENTS-<slug>` from `main` if it does
   not exist, and work on it (never commit on `main`).
2. `docs/phases/p$ARGUMENTS.md`: the approved checklist as Markdown
   checkboxes (`- [ ]`), the feature table with each feature's id, and the
   open questions with owners.
3. `feature_list.json`: `milestone` = `p$ARGUMENTS-<slug>`, `updatedAt` = now
   (ISO 8601), the features with `status` `not-started` (or `blocked`) and
   `evidence` `""` (or the blocking reason).
4. `docs/ROADMAP.md`: split rows listed under their roadmap code, statuses
   `planned`. `progress.md`: milestone, phase branch, "What's next" = the
   first features that can start.
5. `node scripts/check-harness.mjs` passes, then one commit:
   `docs: prepare phase $ARGUMENTS (<slug>)`.

## Out of scope

No code, no worktree, no feature branch. Finish by reporting the phase branch,
the features that can start now (dependencies met), the blocked ones and the
open questions.
