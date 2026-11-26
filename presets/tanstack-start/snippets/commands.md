```bash
# Project (the lockfile names the package manager; examples use <pm>)
<pm> install
<pm> run dev                  # vite dev; another worktree: -- --port <n>
<pm> run lint                 # reports only; the post-edit hook fixes per file
<pm> run build                # vite build; regenerates src/routeTree.gen.ts
<pm> run typecheck            # or tsc --noEmit (vite build does not type-check)
<pm> run test                 # vitest run
<pm> run test:e2e             # playwright
<pm> run start                # serve the production build

# Migrations (ask for approval); keep the one the project uses
npx drizzle-kit generate && npx drizzle-kit migrate
npx prisma migrate dev --name <change>
```
