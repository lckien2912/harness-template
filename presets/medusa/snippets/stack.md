- **Backend:** Medusa v2 in `apps/backend`<!-- , with Mercur as the marketplace layer -->.
  PostgreSQL via MikroORM.
- **Admin / storefront:** <where they live; if another repository uses this
  API, `docs/openapi/` is the contract>.
- **Tooling:** TypeScript; one package manager, named by the single lockfile
  (`bun.lock` or `pnpm-lock.yaml`), pinned in `packageManager`. Node is the
  runtime.
- **Tests:** Jest for backend unit (`*.unit.spec.ts`) and integration
  (`integration-tests/http`, `src/modules/*/__tests__`) tests.

`@medusajs/*` (and `@mercurjs/*`) packages are pinned exactly to one release,
with `overrides`/`resolutions`, and are always upgraded together.
