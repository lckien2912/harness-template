# Verification Report — <feat-id> <feature name>

Date: <YYYY-MM-DD>
Author: <agent/human>
Feature: <feat-id> — <name> (milestone <milestone>)
Result: <pass | in-progress | blocked>

## Acceptance criteria

| #   | Criterion | Met? | Evidence |
| --- | --------- | ---- | -------- |

## Automated gates

`bash init.sh` result (and `RUN_INTEGRATION=1` when the feature needs it),
plus a link to the CI run of the pull request. List only what failed, was
skipped, or needs explaining.

## Manual verification

<Commands run and observed output (a request against an endpoint, a screen
checked in the browser). Include enough to reproduce.>

## Screenshots (UI features)

<Mobile (375 px) and desktop, light and dark if the app has both. Keep the
files out of git (e.g. `verification/screenshots/<feat-id>/`, git-ignored) and
list each file name with what was checked on it. Delete this section for
non-UI features.>

## Migrations (if any)

<What was generated, and confirmation it applies forward on a fresh database.>

## Decisions for the owner

<Open questions this feature surfaced, if any.>

## Remaining risks

<Anything not covered, follow-ups, or known gaps.>
