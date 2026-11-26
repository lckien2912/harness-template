#!/usr/bin/env bash
# Self-test of the template: installs every preset into a scratch repository
# and runs the harness there. Run it after changing core/ or a preset.
#
#   bash tests/run.sh            # all presets
#   bash tests/run.sh node go    # some presets
#
# Needs bash, git, node; npm for the node end-to-end case. Exits 1 on failure.
set -uo pipefail

TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/harness-test.XXXXXX")" || exit 1
trap 'rm -rf "${WORK:?}"' EXIT

presets=("$@")
if [[ ${#presets[@]} -eq 0 ]]; then
  for d in "$TEMPLATE_DIR"/presets/*/; do presets+=("$(basename "$d")"); done
fi

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
ko() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; [[ -n "${2:-}" ]] && printf '%s\n' "$2" | sed 's/^/        /' | tail -n 25; }
expect() {
  # expect <description> <want-exit-code> <command...>
  local desc="$1" want="$2" out code
  shift 2
  out="$("$@" 2>&1)"
  code=$?
  if [[ $code -eq $want ]]; then ok "$desc"; else ko "$desc (exit $code, want $want)" "$out"; fi
}

new_repo() {
  # new_repo <preset> <dir>: installs the preset into a fresh git repository.
  local preset="$1" dir="$2"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  bash "$TEMPLATE_DIR/install.sh" "$dir" --preset "$preset" --name "Demo $preset" >/dev/null
  git -C "$dir" add -A
  git -C "$dir" -c user.email=test@example.invalid -c user.name=test commit -qm "install harness"
}

hook() {
  # hook <dir> <script> <tool> <path-or-command>
  local dir="$1" script="$2" tool="$3" value="$4" key=command
  [[ "$tool" != Bash ]] && key=file_path
  printf '{"tool_name":"%s","tool_input":{"%s":"%s"}}' "$tool" "$key" "$value" \
    | CLAUDE_PROJECT_DIR="$dir" bash "$dir/.claude/hooks/$script"
}

for preset in "${presets[@]}"; do
  echo "== preset: $preset"
  repo="$WORK/$preset"
  if ! new_repo "$preset" "$repo"; then
    ko "install"
    continue
  fi
  ok "install"

  leftovers="$(grep -rn '{{\(PROJECT_NAME\|PROJECT_SLUG\|MILESTONE\|DATE\|PRESET\|snippet:[a-z-]*\)}}' "$repo" --exclude-dir=.git || true)"
  if [[ -z "$leftovers" ]]; then ok "no placeholders left"; else ko "no placeholders left" "$leftovers"; fi

  expect "bash -n on every script" 0 bash -c "for f in '$repo'/init.sh '$repo'/scripts/*.sh '$repo'/.claude/hooks/*.sh '$repo'/.harness/config.sh; do bash -n \"\$f\" || exit 1; done"
  expect "settings.json is valid JSON" 0 node -e "JSON.parse(require('fs').readFileSync('$repo/.claude/settings.json','utf8'))"
  expect "check-harness" 0 node "$repo/scripts/check-harness.mjs" "$repo"
  expect "guardrail cases" 0 bash "$repo/scripts/test-guardrails.sh" "$repo"
  if [[ -x /usr/bin/python3 ]]; then
    expect "guardrail cases without node (python3 parser)" 0 env PATH=/usr/bin:/bin bash "$repo/scripts/test-guardrails.sh" "$repo"
  fi
  expect "architecture check (empty repo)" 0 bash "$repo/scripts/check-architecture.sh"
  expect "cleanup scanner" 0 bash "$repo/scripts/cleanup-scanner.sh"

  # Re-running the installer changes nothing.
  out="$(bash "$TEMPLATE_DIR/install.sh" "$repo" --preset "$preset" --name "Demo $preset")"
  if grep -q '^Written (0)' <<<"$out" && ! grep -q '^Kept' <<<"$out"; then ok "reinstall is a no-op"; else ko "reinstall is a no-op" "$out"; fi

  # A project-edited file is kept, even with --force.
  echo "# local change" >>"$repo/.harness/config.sh"
  out="$(bash "$TEMPLATE_DIR/install.sh" "$repo" --preset "$preset" --name "Demo $preset" --force)"
  if grep -q 'config.sh' <<<"$out" && tail -n 1 "$repo/.harness/config.sh" | grep -q 'local change'; then
    ok "--force keeps project-owned files"
  else
    ko "--force keeps project-owned files" "$out"
  fi
  git -C "$repo" checkout -q -- .harness/config.sh

  # Harness drift is caught.
  cp "$repo/progress.md" "$WORK/progress.bak"
  sed -i.bak 's/foundation/something-else/g' "$repo/progress.md"
  expect "check-harness catches milestone drift" 1 node "$repo/scripts/check-harness.mjs" "$repo"
  cp "$WORK/progress.bak" "$repo/progress.md"
  rm -f "$repo/progress.md.bak"

  # A tracked env file fails the scanner.
  echo "SECRET=1" >"$repo/.env"
  git -C "$repo" add -f .env
  expect "cleanup scanner catches a tracked .env" 1 bash "$repo/scripts/cleanup-scanner.sh"
  git -C "$repo" rm -q --cached .env
  rm "$repo/.env"

  # Baseline without an app: harness gates only.
  expect "init.sh before the app exists" 0 bash "$repo/init.sh"
done

# --- Node end-to-end: real gates, post-edit hook, architecture rule. --------
if [[ " ${presets[*]} " == *" node "* ]] && command -v npm >/dev/null 2>&1; then
  echo "== node end-to-end"
  repo="$WORK/node"
  cat >"$repo/package.json" <<'EOF'
{
  "name": "demo-node",
  "private": true,
  "scripts": {
    "lint": "node -e \"console.log('lint ok')\"",
    "test": "node -e \"console.log('tests ok')\"",
    "build": "node -e \"console.log('build ok')\""
  }
}
EOF
  (cd "$repo" && npm install --package-lock-only --silent >/dev/null 2>&1)
  expect "init.sh runs the package gates" 0 bash "$repo/init.sh"
  out="$(bash "$repo/init.sh" 2>&1)"
  if grep -q 'No "typecheck" script' <<<"$out" && grep -q 'tests ok' <<<"$out"; then ok "missing script is skipped, present ones run"; else ko "missing script is skipped, present ones run" "$out"; fi
  touch "$repo/yarn.lock"
  expect "init.sh refuses two lockfiles" 1 bash "$repo/init.sh"
  rm "$repo/yarn.lock"

  # Fake eslint: fails on files containing BAD.
  mkdir -p "$repo/node_modules/.bin" "$repo/src/api" "$repo/dist"
  cat >"$repo/node_modules/.bin/eslint" <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do [[ -f "$a" ]] && grep -q BAD "$a" && { echo "$a: BAD found"; exit 1; }; done
exit 0
EOF
  chmod +x "$repo/node_modules/.bin/eslint"
  echo "export const ok = 1" >"$repo/src/good.ts"
  echo "export const BAD = 1" >"$repo/src/bad.ts"
  echo "BAD" >"$repo/dist/out.js"
  expect "post-edit: clean file passes" 0 hook "$repo" posttooluse-checks.sh Edit "$repo/src/good.ts"
  expect "post-edit: lint error feeds back (exit 2)" 2 hook "$repo" posttooluse-checks.sh Edit "$repo/src/bad.ts"
  expect "post-edit: generated dir is skipped" 0 hook "$repo" posttooluse-checks.sh Write "$repo/dist/out.js"
  expect "post-edit: non-matching file is skipped" 0 hook "$repo" posttooluse-checks.sh Edit "$repo/README.md"

  echo "export const url = process.env.API_URL" >"$repo/src/api/client.ts"
  expect "architecture rule catches env read in src/api" 1 bash "$repo/scripts/check-architecture.sh"
  mv "$repo/src/api/client.ts" "$repo/src/api/client.test.ts"
  expect "architecture rule ignores test files" 0 bash "$repo/scripts/check-architecture.sh"

  expect "guard: path rule asks for migrations" 0 bash -c "out=\$(printf '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$repo/prisma/migrations/1/migration.sql\"}}' | CLAUDE_PROJECT_DIR='$repo' bash '$repo/.claude/hooks/pretooluse-guard.sh'); [[ \$out == *ask* ]]"
  expect "guard: writes the audit log" 0 test -s "$repo/.claude/logs/audit.log"
  expect "audit log is git-ignored" 0 git -C "$repo" check-ignore -q .claude/logs/audit.log

  # Worktree helper.
  git -C "$repo" add -A >/dev/null 2>&1
  git -C "$repo" -c user.email=test@example.invalid -c user.name=test commit -qm app >/dev/null 2>&1
  git -C "$repo" branch phase/p1-demo
  echo "API_URL=http://localhost" >"$repo/.env.example"
  git -C "$repo" add .env.example && git -C "$repo" -c user.email=test@example.invalid -c user.name=test commit -qm env
  git -C "$repo" branch -f phase/p1-demo
  expect "new-worktree refuses a feature branch off main" 2 bash -c "cd '$repo' && bash scripts/new-worktree.sh feat/p1.1-x main"
  expect "new-worktree creates a feature worktree" 0 bash -c "cd '$repo' && bash scripts/new-worktree.sh feat/p1.1-x phase/p1-demo"
  expect "new-worktree copied the env file" 0 test -f "$repo/.claude/worktrees/feat-p1.1-x/.env"
  git -C "$repo" worktree remove --force "$repo/.claude/worktrees/feat-p1.1-x"
fi

# --- Nest end-to-end: lint/typecheck gates, layer check, architecture rules. --
if [[ " ${presets[*]} " == *" nest "* ]] && command -v npm >/dev/null 2>&1; then
  echo "== nest end-to-end"
  repo="$WORK/nest"
  echo '{ "collection": "@nestjs/schematics", "sourceRoot": "src" }' >"$repo/nest-cli.json"
  cat >"$repo/package.json" <<'EOF'
{
  "name": "demo-nest",
  "private": true,
  "scripts": {
    "lint": "eslint \"{src,apps,libs,test}/**/*.ts\" --fix",
    "test": "node -e \"console.log('unit ok')\"",
    "build": "node -e \"console.log('build ok')\""
  },
  "devDependencies": { "typescript": "file:./fake-typescript" }
}
EOF
  # A stand-in typescript whose tsc echoes its arguments; npm ci installs it
  # and links node_modules/.bin/tsc.
  mkdir -p "$repo/fake-typescript/bin" "$repo/src/config" "$repo/src/users"
  echo '{ "name": "typescript", "version": "0.0.0", "bin": { "tsc": "bin/tsc" } }' >"$repo/fake-typescript/package.json"
  printf '#!/usr/bin/env node\nconsole.log("tsc " + process.argv.slice(2).join(" "))\n' >"$repo/fake-typescript/bin/tsc"
  chmod +x "$repo/fake-typescript/bin/tsc"
  (cd "$repo" && npm install --package-lock-only --silent >/dev/null 2>&1)
  out="$(bash "$repo/init.sh" 2>&1)"
  if [[ $? -ne 0 ]] && grep -q 'runs --fix' <<<"$out"; then ok "lint gate refuses a --fix lint script"; else ko "lint gate refuses a --fix lint script" "$out"; fi
  sed -i.bak 's/ --fix//' "$repo/package.json" && rm "$repo/package.json.bak"
  node -e 'const f=process.argv[1],p=require(f);p.scripts.lint="node -e \"console.log(\x27lint ok\x27)\"";require("fs").writeFileSync(f,JSON.stringify(p,null,2))' "$repo/package.json"
  out="$(bash "$repo/init.sh" 2>&1)"
  if [[ $? -eq 0 ]] && grep -q 'tsc --noEmit -p tsconfig.json' <<<"$out" && grep -q 'unit ok' <<<"$out"; then
    ok "init.sh runs lint, tsc --noEmit, test, build"
  else
    ko "init.sh runs lint, tsc --noEmit, test, build" "$out"
  fi

  echo "export default () => ({ port: process.env.PORT })" >"$repo/src/config/app.config.ts"
  echo "const p = process.env.PORT" >"$repo/src/main.ts"
  echo "export class UsersService { find() { return [] } }" >"$repo/src/users/users.service.ts"
  expect "nest layers: env in config and main.ts is allowed" 0 node "$repo/.harness/checks/nest-layers.mjs" "$repo"
  echo "const k = process.env.API_KEY" >"$repo/src/users/users.service.ts"
  expect "nest layers: env in a service fails" 1 node "$repo/.harness/checks/nest-layers.mjs" "$repo"
  echo "export class UsersService {}" >"$repo/src/users/users.service.ts"
  printf 'import { Repository } from "typeorm";\nexport class UsersController { constructor(@InjectRepository(User) r: Repository<User>) {} }\n' >"$repo/src/users/users.controller.ts"
  expect "nest layers: repository in a controller fails" 1 node "$repo/.harness/checks/nest-layers.mjs" "$repo"
  mv "$repo/src/users/users.controller.ts" "$repo/src/users/users.controller.spec.ts"
  expect "nest layers: specs are not searched" 0 node "$repo/.harness/checks/nest-layers.mjs" "$repo"
  echo "TypeOrmModule.forRoot({ synchronize: true })" >"$repo/src/users/users.module.ts"
  expect "architecture rule catches synchronize: true" 1 bash "$repo/scripts/check-architecture.sh"
  rm "$repo/src/users/users.module.ts"
  expect "architecture check passes on a clean tree" 0 bash "$repo/scripts/check-architecture.sh"
fi

# --- TanStack Start end-to-end: gate order, boundary check, VITE_ secrets. ----
if [[ " ${presets[*]} " == *" tanstack-start "* ]] && command -v npm >/dev/null 2>&1; then
  echo "== tanstack-start end-to-end"
  repo="$WORK/tanstack-start"
  cat >"$repo/package.json" <<'EOF'
{
  "name": "demo-start",
  "private": true,
  "scripts": {
    "lint": "biome check --write .",
    "build": "node -e \"console.log('build ok')\"",
    "test": "node -e \"console.log('unit ok')\""
  },
  "devDependencies": { "typescript": "file:./fake-typescript" }
}
EOF
  mkdir -p "$repo/fake-typescript/bin" "$repo/src/routes" "$repo/src/components" "$repo/src/server"
  echo '{ "name": "typescript", "version": "0.0.0", "bin": { "tsc": "bin/tsc" } }' >"$repo/fake-typescript/package.json"
  printf '#!/usr/bin/env node\nconsole.log("tsc " + process.argv.slice(2).join(" "))\n' >"$repo/fake-typescript/bin/tsc"
  chmod +x "$repo/fake-typescript/bin/tsc"
  (cd "$repo" && npm install --package-lock-only --silent >/dev/null 2>&1)
  out="$(bash "$repo/init.sh" 2>&1)"
  if [[ $? -ne 0 ]] && grep -q 'rewrites files' <<<"$out"; then ok "lint gate refuses a --write lint script"; else ko "lint gate refuses a --write lint script" "$out"; fi
  node -e 'const f=process.argv[1],p=require(f);p.scripts.lint="node -e \"console.log(\x27lint ok\x27)\"";require("fs").writeFileSync(f,JSON.stringify(p,null,2))' "$repo/package.json"
  out="$(bash "$repo/init.sh" 2>&1)"
  if [[ $? -eq 0 ]] && grep -q 'tsc --noEmit -p tsconfig.json' <<<"$out" \
    && [[ "$(grep -n '^build ok' <<<"$out" | head -n 1 | cut -d: -f1)" -lt "$(grep -n '^tsc --noEmit' <<<"$out" | head -n 1 | cut -d: -f1)" ]]; then
    ok "init.sh runs lint, build, then tsc --noEmit, then test"
  else
    ko "init.sh runs lint, build, then tsc --noEmit, then test" "$out"
  fi

  check="$repo/.harness/checks/start-boundaries.mjs"
  echo "export const env = () => process.env.DATABASE_URL" >"$repo/src/server/env.ts"
  echo "import { db } from 'drizzle-orm/node-postgres'" >"$repo/src/routes/posts.server.ts"
  echo "export const Route = createFileRoute('/posts')({ loader: () => getPosts() })" >"$repo/src/routes/posts.tsx"
  echo "x = 1" >"$repo/src/routeTree.gen.ts"
  expect "start boundaries: server/ and *.server.ts are allowed" 0 node "$check" "$repo"
  echo "const key = process.env.STRIPE_KEY" >"$repo/src/components/Pay.tsx"
  expect "start boundaries: env in a component fails" 1 node "$check" "$repo"
  echo "export function Pay() {}" >"$repo/src/components/Pay.tsx"
  echo "import { drizzle } from 'drizzle-orm/node-postgres'" >>"$repo/src/routes/posts.tsx"
  expect "start boundaries: ORM import in a route fails" 1 node "$check" "$repo"
  mv "$repo/src/routes/posts.tsx" "$repo/src/routes/posts.test.tsx"
  expect "start boundaries: tests are not searched" 0 node "$check" "$repo"
  echo "VITE_STRIPE_SECRET_KEY=" >"$repo/.env.example"
  expect "architecture rule catches a VITE_ secret" 1 bash "$repo/scripts/check-architecture.sh"
  echo "VITE_PUBLIC_URL=" >"$repo/.env.example"
  expect "architecture rule allows a public VITE_ var" 0 bash "$repo/scripts/check-architecture.sh"
fi

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
