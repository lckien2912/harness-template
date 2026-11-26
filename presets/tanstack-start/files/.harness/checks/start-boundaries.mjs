// TanStack Start server/client boundaries that depend on a file's role, which
// the path-based .harness/architecture.rules cannot express. Run by init.sh
// with the repository root as the first argument; exits 1 on a violation.
//
// Route loaders, beforeLoad and components are isomorphic: they run on the
// server AND in the browser. So in client-reachable code (src/routes,
// src/components, src/hooks, src/features):
//   - no process.env: read env in server-only modules and expose what the
//     client needs through a server function;
//   - no database client, ORM or Node-only module: call a server function
//     (createServerFn) defined under src/server/ instead.
// Server-only files (*.server.ts(x), server.ts(x), anything under a server/
// directory), tests and routeTree.gen.ts are not searched. In a workspace,
// list each app's dirs (`apps/<app>/src/routes`, …) and shared UI packages. Adjust CLIENT_DIRS and RULES
// to the project layout.
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join, relative, sep } from "node:path";

const root = process.argv[2] ?? process.cwd();
const CLIENT_DIRS = [
  "src/routes",
  "src/components",
  "src/hooks",
  "src/features",
  "app/routes",
  "app/components",
];
const SKIP_DIRS = new Set(["node_modules", "server", "__tests__", "__mocks__"]);
const SKIP_FILE =
  /\.(test|spec)\.[cm]?[jt]sx?$|(^|\/|\.)server\.[cm]?[jt]sx?$|(^|\/)routeTree\.gen\.ts$/;
const SOURCE = /\.[cm]?[jt]sx?$/;

const RULES = [
  {
    name: "env in client-reachable code",
    regex: /\bprocess\.env\b/,
    message:
      "Loaders and components also run in the browser. Read env in src/server/ (or *.server.ts) and return it from a server function.",
  },
  {
    name: "server-only module in client-reachable code",
    regex:
      /from\s+['"](pg|postgres|mysql2|better-sqlite3|mongodb|kysely|drizzle-orm(\/[^'"]*)?|@prisma\/client|@libsql\/client|@neondatabase\/serverless|(node:)?(fs|fs\/promises|child_process))['"]/,
    message:
      "Put data access in a server function (createServerFn) under src/server/ and call it from the loader or component.",
  },
];

function* walk(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) {
      if (!SKIP_DIRS.has(entry.name)) yield* walk(path);
    } else if (SOURCE.test(entry.name) && !entry.name.endsWith(".d.ts")) {
      yield path;
    }
  }
}

const found = new Map(RULES.map((r) => [r, []]));
for (const top of CLIENT_DIRS) {
  const dir = join(root, top);
  if (!existsSync(dir)) continue;
  for (const file of walk(dir)) {
    const rel = relative(root, file).split(sep).join("/");
    if (SKIP_FILE.test(rel)) continue;
    readFileSync(file, "utf8")
      .split("\n")
      .forEach((line, i) => {
        if (/^\s*(\/\/|\*|\/\*)/.test(line)) return;
        for (const r of RULES)
          if (r.regex.test(line))
            found.get(r).push(`${rel}:${i + 1}:${line.trim()}`);
      });
  }
}

let violations = 0;
for (const [r, hits] of found) {
  if (hits.length === 0) continue;
  violations++;
  console.log(`VIOLATION (${r.name}): ${r.message}`);
  for (const h of hits) console.log(h);
}
if (violations > 0) {
  console.log(
    `Start boundary check failed with ${violations} violation group(s).`,
  );
  process.exit(1);
}
console.log(`Start boundaries: PASS (${RULES.length} rules)`);
