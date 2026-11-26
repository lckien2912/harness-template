- Build and generated output: `apps/backend/.medusa/`, `.mercur/`,
  `apps/*/dist/`, `.turbo/`. These are regenerated; never edit or commit them.
- The lockfile: change it only as a side effect of the package manager.
- Existing migrations: never rewrite one; generate a new migration instead.
