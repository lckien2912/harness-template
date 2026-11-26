---
description: Implement one feature from feature_list.json following the AGENTS.md harness workflow
argument-hint: <feat-id>  e.g. feat-3
---

Implement feature `$ARGUMENTS`.

`AGENTS.md` is the authoritative contract. Do not restate or reinterpret it;
execute it as written. This command only sets the active feature to
`$ARGUMENTS`; every rule and step comes from AGENTS.md.

0. Work on the feature branch `feat/pN.M-<slug>` cut from the current phase
   branch, in its own worktree (AGENTS.md **Branches and Worktrees**). Create
   the branch if it does not exist; never work on the phase branch or `main`.
   `bash scripts/new-worktree.sh feat/pN.M-<slug>` sets up the worktree and its
   local resources.
1. Follow the **Startup Workflow** in AGENTS.md. At the "take one feature"
   step, that feature is `$ARGUMENTS`: confirm its `dependencies` are all
   `pass` before starting, and stop and report if any are not.
2. Implement per the **Work Policy**, staying inside `$ARGUMENTS` scope. Honor
   **Protected Decisions**: ask before any of them.
3. Do not mark `$ARGUMENTS` as `pass` until every item in **Definition of
   Done** holds, with reproducible `evidence` recorded in `feature_list.json`
   and a report under `verification/reports/$ARGUMENTS.md`.
4. Close out per **End of Session**.
5. Once the feature branch is merged into the phase branch, the coordinating
   session removes this worktree and deletes the feature branch locally and on
   the remote (AGENTS.md **Branches and Worktrees**).

Report what changed, the evidence, and any unresolved risks or failing checks.
