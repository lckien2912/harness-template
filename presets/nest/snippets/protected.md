- Changing `tsconfig*.json`, the lint config (oxlint or ESLint) or `nest-cli.json` (builder,
  `typeCheck`) in a way that loosens checks.
- Changing global bootstrap in `src/main.ts` (asks): global pipes, filters,
  interceptors and guards, CORS, helmet, global prefix, versioning.
- Making a route skip authentication or authorization, or changing a global
  guard.
- Changing the ORM configuration (asks), turning on `synchronize`, or running
  migrations (asks).
- `nest add` (asks): it installs a package and rewrites code in one step.
