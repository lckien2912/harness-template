# Project checks

`init.sh` runs every `*.sh`, `*.mjs`/`*.js` and `*.py` file in this directory
after `scripts/check-harness.mjs`, with the repository root as the first
argument. Exit non-zero to fail the baseline.

Use it for rules that are about the *project*, not the stack, for example:

- every API area under `src/api/<area>/` is called by an integration test that
  also uses the cross-tenant fixture (tenant isolation is tested, not assumed);
- every public route has an entry in `docs/openapi/`;
- every migration has a matching rollback note.

Keep each check fast and dependency-free (it runs on every `init.sh`).

## Testing a check

`scripts/test-guardrails.sh` tests checks two ways; give every check one of
them, with a passing and a failing case:

- **One file:** a line in `.harness/boundary.cases`,
  `<pass|fail>|<check>|<path>|<content>` (`<check>` = the file name without
  `.mjs`, or `arch` for `architecture.rules`; `\n` in content is a newline).
  Example: `fail|start-boundaries|src/routes/x.tsx|const k = process.env.KEY`.
- **A small repository:** `fixtures/<check>/<case>/` holds the files (paths
  from the repository root) and `expect`, the rule names the check must
  report, one per line, or `pass`. The check runs with the fixture as its
  working directory and first argument, next to a copy of the real
  `.harness/`, and reports each finding as a line
  `VIOLATION (<rule>): <message>`.

Only top-level files here are run by `init.sh`; `fixtures/` is never run.
