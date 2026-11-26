# Guardrails

Owner: human for policy; agent keeps this page in step with `.claude/` and
`.harness/`.

The Claude Code enforcement layer backs parts of `AGENTS.md` mechanically. The
rules themselves are data in the files below; this page says where each one is.
`scripts/test-guardrails.sh` (run by `init.sh`) feeds every case in
`.harness/guard*.cases` to the hook and fails on any mismatch. It then tests
the content checks, when the project has any:

- `.harness/boundary.cases`: each case writes one file into a fresh scratch
  tree and runs `scripts/check-architecture.sh` (`arch`) or
  `.harness/checks/<name>.mjs` on it; the case says `pass` or `fail`.
- `.harness/checks/fixtures/<name>/<case>/`: a small fixture repository for
  `.harness/checks/<name>.mjs` (the real `.harness/` plus the case's files);
  `<case>/expect` lists exactly the rules the check must report, or `pass`.

| Layer               | File                                                                | What it does                                                                                                                                                                                                                                           |
| ------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1. Permission rules | `.claude/settings.json`                                             | **Deny:** reading real `.env*` and secret files; `rm -rf`; force-pushing or pushing to `main`/`master`/`production`; docker volume wipes. **Ask:** `git reset --hard`, `dropdb`. Prefix matches only                                                   |
| 2. PreToolUse hook  | `.claude/hooks/pretooluse-guard.sh` + `.harness/guard*.rules`       | Inspects the **whole** Bash command (`cd x && …`) and the target path of every edit. `block` / `ask` rules for commands, `block-path` / `ask-path` rules for files. Logs blocked and approval-required calls to `.claude/logs/audit.log` (git-ignored) |
| 3. PostToolUse hook | `.claude/hooks/posttooluse-checks.sh` + `.harness/post-edit.rules`  | After an edit, runs the matching installed fixers/linters on that file only. A failure makes Claude fix the file. No network fallback (no `npx`/`bunx` downloads)                                                                                      |
| 4. Gates            | `init.sh` + `.harness/config.sh`, `.harness/architecture.rules`, CI, `.githooks/pre-push` | Harness consistency, guardrail tests, project gates, architecture boundaries; the same in CI and (optionally) before every push                                                                                                         |
| 5. Contract         | `AGENTS.md`                                                         | Everything a regex cannot judge                                                                                                                                                                                                                        |

## Rule files

| File                                                                            | Owner                               | Upgraded with the template?      |
| ------------------------------------------------------------------------------- | ----------------------------------- | -------------------------------- |
| `.harness/guard.rules`, `.harness/guard.cases`                                  | template core                       | yes; add project rules elsewhere |
| `.harness/guard.<preset>.rules` / `.cases`                                      | stack preset                        | yes, unless edited               |
| `.harness/guard.project.rules` / `.cases`                                       | this project                        | never                            |
| `.harness/post-edit.rules`, `.harness/architecture.rules`, `.harness/config.sh` | this project (seeded by the preset) | never                            |
| `.harness/boundary.cases`, `.harness/checks/fixtures/`                          | this project                        | never                            |

Every new rule gets at least one case, and an `allow` case where a false
positive is likely.

## Why two layers

Permission rules match command **prefixes** only, so a dangerous command inside
a compound command (`cd app && …`, `psql -c "DROP …"`) slips past them. The
PreToolUse hook reads the full string. Keep both: the rules give a clear
prompt, the hook is the backstop.

The hooks **fail open** on a malformed payload, so a parsing bug never blocks
work. They are not a security boundary against a hostile actor.

## Known side effects

- **Text matches too.** Command patterns match text anywhere, including commit
  messages, inline scripts and file names (`git rm -r … some-file.md` reads as
  `-r … -f`). Write such text to a file, or split the command.
- **`ask` and bypass mode.** The PreToolUse `ask` decision relies on Claude
  Code honouring `permissionDecision: "ask"`. A session that bypasses
  permissions may not prompt; the audit log still records the call.
- **Trust the hooks.** Claude Code must trust the hooks in a new session.
  Restart the session if they were added mid-session.
