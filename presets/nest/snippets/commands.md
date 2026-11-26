```bash
# Project (the lockfile names the package manager; examples use <pm>)
<pm> install
<pm> run start:dev
<pm> run lint                 # reports only; the post-edit hook fixes per file
<pm> run test                 # unit (*.spec.ts)
<pm> run test:e2e             # e2e (test/*.e2e-spec.ts), needs live services
<pm> run build

# Scaffolding (preview first)
npx nest g resource <name> --dry-run
npx nest g module|controller|service <name>

# Migrations (ask for approval); keep the one the project uses
<pm> run migration:generate   # TypeORM: wrap typeorm migration:generate -d <data-source>
npx prisma migrate dev --name <change>
npx mikro-orm migration:create
```
