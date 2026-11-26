- **Application:** <framework> on Node.js, TypeScript, in `<path>`.
  <!-- e.g. Next.js app in apps/web, NestJS API in apps/api -->
- **Datastore:** <database and ORM/query builder>.
- **Tooling:** the lockfile names the package manager (`bun.lock`,
  `pnpm-lock.yaml`, `yarn.lock` or `package-lock.json`); exactly one lockfile
  exists. `packageManager` in `package.json` pins its version. The
  `package.json` scripts are the command source of truth; `CLAUDE.md` indexes
  them.
- **Tests:** <vitest/jest/playwright>, `test` for unit, `test:integration` for
  anything that needs live services.
