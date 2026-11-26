1. schema change plus a generated migration;
2. server function (`createServerFn` in `src/server/`): input validator,
   auth check, data access;
3. route: `loader` (or a query) calling the server function, plus `params` /
   `validateSearch` schemas;
4. components;
5. tests: unit tests for the server logic, a Playwright spec for the flow.
