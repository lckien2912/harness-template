# Roadmap

Owner: the product owner approves scope and order. Agents update statuses.

## How we work

- **Phases and milestones:** each phase is one milestone in
  `feature_list.json`. This file holds the whole backlog; `feature_list.json`
  holds only the current phase's features.
- **Branches:** one `phase/pN-<slug>` branch per phase, cut from `main`; one
  `feat/pN.M-<slug>` branch and worktree per feature, cut from the phase
  branch, with its pull request into the phase branch; one `phase/… → main`
  pull request at the end of the phase.
- **Parallel work:** a feature starts only when its dependencies are merged
  into the phase branch. Features that touch the same files merge one at a
  time.
- **Numbering:** feature ids continue across phases (`feat-1`, `feat-2`, …).
  The roadmap code goes in `name`, e.g. `"[P1.4] Sign-up"`.
- **Phase smoke test:** each phase's "done when" criteria become one automated
  flow. The `phase/… → main` pull request opens only when it is green, so a
  later phase cannot silently break an earlier one.

**Legend:** size S ≈ 1 agent session, M ≈ 2–3 sessions, L ≈ split it.
Dependencies use the P codes; "—" means none inside the phase.

## Phase 0 — Foundation

Done when: the harness gates pass in CI on an empty application skeleton.

| Code | Feature                                     | Size | Depends on | Status  |
| ---- | ------------------------------------------- | ---- | ---------- | ------- |
| P0.1 | Application skeleton and first passing gate | S    | —          | planned |
| P0.2 | CI runs `init.sh` on every pull request     | S    | P0.1       | planned |

## Phase 1 — <name>

Done when: <observable exit criteria>.

| Code | Feature | Size | Depends on | Status |
| ---- | ------- | ---- | ---------- | ------ |

## Out of scope (for now)

- <item>

## Owner decisions

- <date>: <decision>.
