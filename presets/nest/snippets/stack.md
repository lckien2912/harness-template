- **Application:** NestJS <major> API on Node.js, TypeScript (`strict`), in
  `<path>`; `nest-cli.json` marks it (`"monorepo": true` → `apps/*`, `libs/*`).
  <!-- HTTP adapter: Express or Fastify; REST, GraphQL, microservices? -->
- **Structure:** one feature module per domain area (`src/<area>/`:
  `<area>.module.ts`, controller, service, `dto/`, entities). Cross-module use
  goes through a provider the owning module `exports`, never a deep import.
- **Datastore:** <PostgreSQL via TypeORM / Prisma / MikroORM>; schema changes
  only through migrations (`synchronize` stays off).
- **Config:** `@nestjs/config`, one `registerAs` namespace per area in
  `src/config/`, validated at boot. `process.env` is read nowhere else.
- **Validation:** DTO classes with `class-validator`, global `ValidationPipe`
  (`whitelist`, `forbidNonWhitelisted`, `transform`) set in `src/main.ts`.
- **Tooling:** the lockfile names the package manager (exactly one lockfile;
  `packageManager` pins its version). The `package.json` scripts are the
  command source of truth; `CLAUDE.md` indexes them.
- **Tests:** Jest. Unit: `*.spec.ts` next to the code, built with
  `Test.createTestingModule` and mocked providers. E2E: `test/*.e2e-spec.ts`,
  the real `AppModule` over supertest; needs live services.

`@nestjs/*` packages are pinned to one major and always upgraded together.
