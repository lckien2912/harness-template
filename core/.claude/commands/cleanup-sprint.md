---
description: Close out the current milestone/sprint — verify it is done, archive its record, and reset the backlog + progress for the next milestone. Does not plan the next sprint.
argument-hint: [next-milestone]  e.g. catalog
---

Close out the current sprint (milestone) and open the next one, `$ARGUMENTS`.
This **packages up** the finished sprint; it does **not** plan or populate the
next backlog.

`AGENTS.md` (**End of Session**) is authoritative. This command is the only
description of milestone rotation (`docs/HARNESS.md` lists the artifacts). A
milestone is one roadmap phase (`docs/ROADMAP.md`). `$ARGUMENTS` is the next
milestone's name; if it is empty, ask for it (or use `next` as a placeholder).
First read `feature_list.json` and `progress.md` to learn the **current**
milestone name (call it `<old>`), and use today's UTC date as `<YYYY-MM-DD>`.

## 1. Readiness and drift check — abort and report on ANY failure

Never archive a half-done sprint. Stop with a clear report if:

- **Any feature is neither `pass` nor `superseded`.** List every
  `not-started` / `in-progress` / `blocked` feature.
- **The backlog is empty** (`features: []`). Report "nothing to close" and
  stop; do not create an empty archive.
- **A `pass` feature is missing its report**, or a report exists with no
  matching feature (orphan).
- **`progress.md` drifts from `feature_list.json`**: the milestone name
  differs, or "Current state" contradicts the feature statuses. Report the
  drift and stop; the human reconciles it.
- **The working tree is dirty.** The close makes its own commit; commit or set
  aside unrelated work first.

Then a freeze check: `node scripts/check-harness.mjs` and
`bash scripts/cleanup-scanner.sh` pass. Optionally run `bash init.sh` for a
stronger freeze.

Before archiving, remove the worktrees and branches the scanner lists as
merged, for every feature of the phase (AGENTS.md **Branches and Worktrees**).

## 2. Archive the finished milestone

Create `docs/archive/<old>-<YYYY-MM-DD>/` and populate it:

- `git mv verification/reports/<id>.md` for every feature into
  `docs/archive/<old>-<YYYY-MM-DD>/reports/`. Keep
  `verification/reports/TEMPLATE.md`. These reports are the authoritative
  per-feature evidence.
- Snapshot `progress.md` verbatim into the folder.
- Snapshot `feature_list.json` into the folder, replacing each feature's
  `evidence` with a pointer, `"See reports/<id>.md"`. Keep every other field
  verbatim, and keep `evidence` a non-empty string so the snapshot stays valid
  against `feature_list.schema.json`.
- Write `docs/archive/<old>-<YYYY-MM-DD>/README.md`: what the folder is, that
  `reports/` holds the evidence the snapshot points to, and that any
  `verification/reports/…` path inside the frozen snapshots now resolves to
  `reports/` here.
- Before resetting `progress.md`, confirm every durable decision is captured
  in an ADR (`docs/decisions/`) or a doc; promote any that is not.

## 3. Reset for the next milestone

- `feature_list.json` → `{ "$schema": "./feature_list.schema.json",
"milestone": "$ARGUMENTS", "updatedAt": "<today, ISO 8601>", "features": [] }`.
- `progress.md` → a fresh, lean resumable state: milestone `$ARGUMENTS`, no
  active feature, **Current state** = "`<old>` milestone complete, archived at
  `docs/archive/<old>-<YYYY-MM-DD>/`", **What's next** = "sprint planning
  (separate): populate the `$ARGUMENTS` backlog", plus carried-forward
  Decisions and open Blockers.
- Fix live references to the moved reports.

## 4. Commit

One commit on the current phase branch (never directly on `main`):
`chore: roll over <old> -> $ARGUMENTS`. The body lists the archive path and the
reset.

## 5. Load the next phase (optional)

If the next phase is listed in `docs/ROADMAP.md`, its features may be loaded
into `feature_list.json` (ids continue from the highest used; the roadmap code
goes in `name`). Acceptance criteria come from the roadmap row and the owner.
Open owner decisions that block a feature make it `blocked`, not guessed.

## Out of scope

Do not start implementing any feature. Finish by reporting what was archived
(path), the new milestone, and any drift or abort condition you hit.
