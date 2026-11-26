#!/usr/bin/env node
// Harness consistency check. No dependencies: run with `node` (>= 18).
// - feature_list.json has the shape feature_list.schema.json describes;
// - ids are unique and dependencies point at existing features;
// - every `pass` feature has verification/reports/<id>.md;
// - every report belongs to a feature in the list (no orphans);
// - a `superseded` feature says why in `evidence`;
// - progress.md names the current milestone (drift between the two files).
//
// Project-specific checks (for example "every API area has an isolation
// test") go in .harness/checks/; init.sh runs them after this script.
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

// Optional argument: another repository root (used to test this script).
const root =
  process.argv[2] ?? join(dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => JSON.parse(readFileSync(join(root, p), "utf8"));
const errors = [];

const schema = read("feature_list.schema.json");
const item = schema.properties.features.items;
const statuses = item.properties.status.enum;
const idPattern = new RegExp(item.properties.id.pattern);
const list = read("feature_list.json");

for (const key of schema.required) {
  if (!(key in list)) errors.push(`feature_list.json: missing "${key}"`);
}
for (const key of Object.keys(list)) {
  if (!(key in schema.properties))
    errors.push(`feature_list.json: unknown key "${key}"`);
}
if (typeof list.milestone !== "string" || !list.milestone.trim())
  errors.push(`feature_list.json: "milestone" must be a non-empty string`);

const features = Array.isArray(list.features) ? list.features : [];
const ids = new Set();
for (const f of features) {
  const where = `feature ${f.id ?? "(no id)"}`;
  for (const key of item.required) {
    if (!(key in f)) errors.push(`${where}: missing "${key}"`);
  }
  for (const key of Object.keys(f)) {
    if (!(key in item.properties))
      errors.push(`${where}: unknown key "${key}"`);
  }
  if (!idPattern.test(f.id ?? ""))
    errors.push(`${where}: id does not match ${idPattern}`);
  if (ids.has(f.id)) errors.push(`${where}: duplicate id`);
  ids.add(f.id);
  if (!statuses.includes(f.status))
    errors.push(`${where}: status "${f.status}" not in ${statuses.join("|")}`);
  if (
    !Array.isArray(f.acceptanceCriteria) ||
    f.acceptanceCriteria.length === 0
  ) {
    errors.push(`${where}: needs at least one acceptance criterion`);
  }
  if (f.status === "superseded" && !f.evidence?.trim()) {
    errors.push(`${where}: superseded without a reason in "evidence"`);
  }
}

const reportsDir = join(root, "verification/reports");
for (const f of features) {
  for (const dep of f.dependencies ?? []) {
    if (!ids.has(dep))
      errors.push(
        `feature ${f.id}: dependency ${dep} is not in feature_list.json`,
      );
  }
  if (f.status === "pass" && !existsSync(join(reportsDir, `${f.id}.md`))) {
    errors.push(
      `feature ${f.id}: pass but verification/reports/${f.id}.md is missing`,
    );
  }
}

if (existsSync(reportsDir)) {
  for (const file of readdirSync(reportsDir)) {
    if (!file.endsWith(".md") || file === "TEMPLATE.md") continue;
    const id = file.slice(0, -3);
    if (idPattern.test(id) && !ids.has(id))
      errors.push(
        `verification/reports/${file}: no feature ${id} in feature_list.json`,
      );
  }
}

const progressPath = join(root, "progress.md");
if (existsSync(progressPath) && list.milestone) {
  const progress = readFileSync(progressPath, "utf8");
  if (!progress.includes(list.milestone))
    errors.push(
      `progress.md does not mention the milestone "${list.milestone}" from feature_list.json`,
    );
}

if (errors.length) {
  console.error("Harness check: FAIL");
  for (const e of errors) console.error(`  - ${e}`);
  process.exit(1);
}
console.log(
  `Harness check: PASS (${features.length} features, milestone ${list.milestone})`,
);
