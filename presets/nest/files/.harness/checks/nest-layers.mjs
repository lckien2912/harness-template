// NestJS layer boundaries that depend on a file's role, which the path-based
// .harness/architecture.rules cannot express. Run by init.sh with the
// repository root as the first argument; exits 1 on a violation.
//
//   - process.env is read only in config files (src/config/**, *.config.ts)
//     and main.ts; everything else injects ConfigService or a registerAs
//     namespace.
//   - Controllers, resolvers and gateways call services: no repository, ORM
//     or raw database client in them, and no hand-built providers.
//
// Specs, e2e tests and generated directories are not searched. Adjust ROOTS
// and RULES to the project layout.
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join, relative, sep } from "node:path";

const root = process.argv[2] ?? process.cwd();
const ROOTS = ["src", "apps", "libs"];
const SKIP_DIRS = new Set([
  "node_modules",
  "dist",
  "build",
  "coverage",
  ".turbo",
  "test",
  "__tests__",
  "__mocks__",
]);
const IS_TEST = /\.(spec|e2e-spec|test)\.ts$/;

const isConfig = (f) =>
  /(^|\/)config\//.test(f) ||
  /\.config\.ts$/.test(f) ||
  /(^|\/)main\.ts$/.test(f);
const isTransport = (f) => /\.(controller|resolver|gateway)\.ts$/.test(f);

const RULES = [
  {
    name: "env outside config",
    applies: (f) => !isConfig(f),
    regex: /\bprocess\.env\b/,
    message:
      "Read configuration in src/config/ (registerAs) and inject ConfigService or the namespace.",
  },
  {
    name: "persistence in transport layer",
    applies: isTransport,
    regex:
      /@Inject(Repository|Model|EntityManager|DataSource|Connection)\b|\b(PrismaService|PrismaClient|EntityManager|DataSource)\b|from\s+['"](pg|mysql2|mongodb|typeorm|@mikro-orm\/[^'"]+)['"]/,
    message:
      "Controllers, resolvers and gateways call a service; the service owns the repository/ORM.",
  },
  {
    name: "hand-built provider in transport layer",
    applies: isTransport,
    regex: /\bnew\s+[A-Z]\w*(Service|Repository)\s*\(/,
    message:
      "Inject providers through the constructor so they can be replaced in tests.",
  },
];

function* walk(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) {
      if (!SKIP_DIRS.has(entry.name)) yield* walk(path);
    } else if (
      entry.name.endsWith(".ts") &&
      !entry.name.endsWith(".d.ts") &&
      !IS_TEST.test(entry.name)
    ) {
      yield path;
    }
  }
}

const found = new Map(RULES.map((r) => [r, []]));
for (const top of ROOTS) {
  const dir = join(root, top);
  if (!existsSync(dir)) continue;
  for (const file of walk(dir)) {
    const rel = relative(root, file).split(sep).join("/");
    const rules = RULES.filter((r) => r.applies(rel));
    if (rules.length === 0) continue;
    readFileSync(file, "utf8")
      .split("\n")
      .forEach((line, i) => {
        if (/^\s*(\/\/|\*|\/\*)/.test(line)) return;
        for (const r of rules)
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
  console.log(`Nest layer check failed with ${violations} violation group(s).`);
  process.exit(1);
}
console.log(`Nest layers: PASS (${RULES.length} rules)`);
