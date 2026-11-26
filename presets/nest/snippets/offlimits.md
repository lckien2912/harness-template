- Build and generated output: `dist/`, `coverage/`, `.turbo/`
  (`HARNESS_GENERATED_DIRS`). Never edit or commit them.
- Lockfiles: change them only as a side effect of the package manager.
- Existing migrations: never rewrite one; generate a new migration instead.
