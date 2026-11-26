- `src/routeTree.gen.ts`: generated from `src/routes/` (edits are denied).
- Build and generated output: `.output/`, `.nitro/`, `.tanstack/`, `.vinxi/`,
  `dist/`, `coverage/`, `playwright-report/` (`HARNESS_GENERATED_DIRS`).
  Never edit or commit them.
- Lockfiles: change them only as a side effect of the package manager.
- Existing migrations: never rewrite one; generate a new migration instead.
