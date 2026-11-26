- Changing `tsconfig*.json`, the ESLint/Biome config or `vite.config.ts`
  (asks) in a way that loosens checks or changes SSR or prerendering.
- Changing global request/function middleware (`src/start.ts`, asks) or the
  auth check of a server function or server route.
- Giving a variable the `VITE_` prefix (it ships to every browser).
- Adding registry components (`shadcn add`, asks).
