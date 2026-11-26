# Architecture

Owner: agent keeps it in step with the code; boundary changes are a Protected
Decision (AGENTS.md).

## Layout

```
<repo>/
  <app or package>/   <what it is>
  docs/               product, roadmap, architecture, decisions
  scripts/            harness gates and helpers
  .harness/           harness configuration (gates, rules)
  .claude/            agent settings, hooks, commands
```

## Boundaries

Each boundary below is enforced by a rule in `.harness/architecture.rules`
(`scripts/check-architecture.sh`) or by the linter. A boundary nobody enforces
is a wish: either add a rule, or say here why review is enough.

| Boundary                                        | Why                          | Enforced by                   |
| ----------------------------------------------- | ---------------------------- | ----------------------------- |
| <e.g. transport layer never reads env directly> | <config has one entry point> | `.harness/architecture.rules` |

## Data

<Datastores, who owns which tables/collections, migration tool and policy
(forward-only, generated, reviewed).>

## External services

| Service | Used for | Configured in | Local substitute |
| ------- | -------- | ------------- | ---------------- |
