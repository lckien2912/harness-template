```bash
# Install, develop, build (from the repo root; <pm> = bun or pnpm, per the lockfile)
<pm> install
<pm> run dev
<pm> run build

# Backend (cd apps/backend)
<pm> run lint
<pm> run test:unit
<pm> run test:integration:http
<pm> run test:integration:modules
npx medusa db:generate <module>   # after a model change (asks for approval)
npx medusa db:migrate             # asks for approval
```
