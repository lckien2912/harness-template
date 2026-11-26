# Agent harness template

Template harness cho coding agent (Claude Code), dùng lại được cho nhiều dự án
và framework. Một harness gồm:

- **Hợp đồng làm việc**: `AGENTS.md` (luật), `CLAUDE.md` (chỉ mục lệnh).
- **Vòng làm việc có thể resume**: `feature_list.json` (+ schema),
  `progress.md`, `verification/reports/<id>.md`, ADR trong `docs/decisions/`.
- **Gate cố định**: `init.sh` chạy giống nhau ở local, đầu mỗi phiên agent và CI.
- **Guardrail cơ học**: permission rules trong `.claude/settings.json` + hook
  PreToolUse/PostToolUse, có bộ test riêng.
- **Quy trình nhánh/worktree**: `phase/pN-*` → `feat/pN.M-*`, mỗi feature một
  worktree, lệnh `/prepare-phase`, `/feature` và `/cleanup-sprint`.

Mọi thứ phụ thuộc stack (framework, package manager, layout thư mục,
database…) nằm trong **file dữ liệu** ở `.harness/`. Script và hook trong
`core/` không biết gì về framework.

## Cài vào một dự án

```bash
bash install.sh ../my-project --preset node --name "My Project"
```

| Tuỳ chọn      | Ý nghĩa                                                     |
| ------------- | ----------------------------------------------------------- |
| `--preset`    | `generic` (mặc định), `node`, `nest`, `tanstack-start`, `medusa`, `python`, `go` |
| `--name`      | Tên dự án trong `AGENTS.md` và docs (mặc định: tên thư mục) |
| `--milestone` | Milestone đầu tiên (mặc định `foundation`)                  |
| `--force`     | Ghi đè file đã có (trừ các file thuộc về dự án, xem dưới)   |
| `--dry-run`   | Chỉ in danh sách file sẽ ghi                                |

Sau khi cài:

1. Xem `.harness/config.sh`: thư mục app, các gate, database cho worktree.
2. Sửa `.harness/architecture.rules` và `.harness/post-edit.rules` theo layout thật.
3. Điền các `<placeholder>` trong `AGENTS.md`, `docs/PRODUCT.md`, `docs/ROADMAP.md`.
4. `bash init.sh`.
5. Khởi động lại Claude Code trong dự án để nó trust hook mới.

Cài lại (nâng cấp template) an toàn: file giống hệt thì bỏ qua, file khác thì
giữ nguyên và được liệt kê. Các file **thuộc về dự án** không bao giờ bị ghi
đè, kể cả với `--force`: `docs/PRODUCT.md`, `docs/ROADMAP.md`,
`docs/ARCHITECTURE.md`, `progress.md`, `feature_list.json`,
`.harness/config.sh`, `.harness/post-edit.rules`, `.harness/architecture.rules`,
`.harness/guard.project.*`. `.harness/manifest` ghi version template và preset
đã dùng.

## Cấu trúc template

```
harness-template/
  install.sh            # copy core + preset vào dự án, thay placeholder
  VERSION
  core/                 # dùng chung cho mọi stack
    AGENTS.md CLAUDE.md init.sh progress.md feature_list.json(+schema)
    .claude/settings.json, hooks/, commands/{prepare-phase,feature,cleanup-sprint}.md
    .githooks/pre-push                         # gate trước khi push (tuỳ chọn)
    .harness/guard.rules, guard.cases          # luật guard chung + test
    .harness/guard.project.{rules,cases}       # chỗ cho luật riêng dự án
    .harness/checks/                           # check riêng dự án (tuỳ chọn)
    .harness/boundary.cases                    # test cho check nội dung (tuỳ chọn)
    scripts/check-harness.mjs test-guardrails.sh check-architecture.sh
            cleanup-scanner.sh new-worktree.sh
    docs/ (PRODUCT, ROADMAP, ARCHITECTURE, GUARDRAILS, HARNESS, decisions/)
    verification/reports/TEMPLATE.md
    .github/workflows/ci.yml
  presets/<name>/
    extends             # (tuỳ chọn) preset cha, ví dụ medusa -> node
    files/              # đè lên core: .harness/config.sh, guard.<name>.rules,
                        # guard.<name>.cases, post-edit.rules, architecture.rules, ci.yml
    snippets/           # đoạn chèn vào AGENTS.md / CLAUDE.md
  tests/run.sh          # tự test: cài từng preset vào repo tạm và chạy harness
```

Thứ tự lớp: `core` → `generic` → preset cha → preset. Lớp sau thắng. Dòng
`{{snippet:<tên>}}` trong `AGENTS.md`/`CLAUDE.md` được thay bằng
`snippets/<tên>.md` của lớp gần nhất (giữ nguyên thụt lề). Các snippet:
`stack`, `slice`, `protected`, `references`, `offlimits`, `commands`.

## Các file cấu hình trong `.harness/`

**`config.sh`**: nơi duy nhất biết về stack. Được `source` bởi `init.sh`, hook và
script, nên chỉ chứa biến và hàm.

| Biến / hàm                                                                                                         | Dùng cho                                                                    |
| ------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| `HARNESS_GATES=("tên\|lệnh" …)`                                                                                    | Gate bắt buộc, chạy theo thứ tự (lệnh được `eval`, gọi được hàm trong file) |
| `HARNESS_INTEGRATION_GATES`                                                                                        | Gate chạy khi `RUN_INTEGRATION=1`                                           |
| `harness_setup()`                                                                                                  | Cài dependency với lockfile đóng băng                                       |
| `HARNESS_APP_MARKER`                                                                                               | Chưa có file này → chỉ chạy phần harness (repo chưa scaffold)               |
| `HARNESS_REQUIRED_FILES`                                                                                           | File bắt buộc thêm                                                          |
| `HARNESS_GENERATED_DIRS`                                                                                           | Output sinh ra: không lint, không tìm, không được commit                    |
| `HARNESS_ARCH_EXCLUDES`                                                                                            | Glob bỏ qua khi check kiến trúc (test)                                      |
| `HARNESS_MAIN_BRANCH`, `HARNESS_PHASE_PREFIX`, `HARNESS_FEATURE_PREFIX`                                            | Mô hình nhánh                                                               |
| `HARNESS_WORKTREE_ENV_FILES`, `HARNESS_WORKTREE_DB_*`, `harness_worktree_setup()`, `harness_worktree_next_steps()` | `scripts/new-worktree.sh`                                                   |

**`guard*.rules`**: luật cho hook PreToolUse, mỗi dòng
`kind|tên|regex` (ERE, không phân biệt hoa thường; thêm `:cs` sau kind để
phân biệt). `kind`: `block` / `ask` cho lệnh Bash (khớp ở bất kỳ đâu trong lệnh,
kể cả `cd x && …`), `block-path` / `ask-path` cho đường dẫn file mà Edit/Write
nhắm tới.

**`guard*.cases`**: test cho các luật trên, mỗi dòng
`block|ask|allow` + `|Bash|lệnh` hoặc `|Edit|đường-dẫn`. `init.sh` chạy hết.

**`post-edit.rules`**: `glob…|cwd|lệnh {file}`. Sau mỗi lần sửa file, hook
chạy linter/fixer đã cài sẵn (node_modules/.bin, .venv/bin, PATH) trên đúng file
đó; lỗi → exit 2 để Claude tự sửa. Không bao giờ tải tool qua mạng.

**`architecture.rules`**: `tên|đường-dẫn…|regex|thông điệp`. Regex khớp trong
các đường dẫn là vi phạm. Chỉ giữ vài luật tín hiệu cao mà linter không bắt
được.

**`checks/`**: script `.sh`/`.mjs`/`.py` riêng của dự án, `init.sh` chạy sau
`check-harness.mjs`. Ví dụ: mỗi route của một tenant phải có integration test
dùng fixture hai tenant. Mỗi check cần test trong `test-guardrails.sh`:

- **`boundary.cases`**: `pass|fail` + `|<check>|<đường-dẫn>|<nội dung>`; mỗi
  case ghi một file vào cây tạm rồi chạy `checks/<check>.mjs` (hoặc `arch` =
  `architecture.rules`).
- **`checks/fixtures/<check>/<case>/`**: repo mẫu nhỏ + file `expect` (tên luật
  check phải báo, dạng `VIOLATION (<luật>): …`, hoặc `pass`).

## Presets

| Preset                    | Gate                                                                                   | Guard thêm                                                                                                    | Ghi chú                                                       |
| ------------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| `generic`                 | (trống, tự điền)                                                                       | —                                                                                                             | Mọi stack khác: Rust, Java, Ruby…                             |
| `node`                    | `lint`, `typecheck`, `test`, `build` (script nào thiếu thì bỏ qua), `test:integration` | thêm dependency, Prisma/Drizzle/TypeORM/Knex, sửa lockfile, migration                                         | Package manager suy từ lockfile; chỉ cho một lockfile         |
| `nest` (extends `node`)   | `lint` (không `--fix`), `typecheck` (`tsc --noEmit` cả spec), `test`, `build`; `test:e2e`, `test:integration` | `nest add`/`nest new`, MikroORM schema drop/fresh (chặn) và migration, TypeORM `schema:sync`, sửa `src/main.ts`, `nest-cli.json`, config ORM | Marker `nest-cli.json`; `.harness/checks/nest-layers.mjs`: `process.env` chỉ trong config, controller không đụng ORM; luật kiến trúc `synchronize: true`, `console.log` |
| `tanstack-start` (extends `node`) | `lint` (không `--fix`/`--write`), `build`, `typecheck` (`tsc --noEmit`, sau build vì cần `routeTree.gen.ts`), `test`; `test:e2e`, `test:integration` | Chặn sửa `routeTree.gen.ts`; hỏi `shadcn add`, sửa `vite.config.ts`/`app.config.ts`, `src/start.ts` | `.harness/checks/start-boundaries.mjs`: route/component/hook (chạy cả ở browser) không đọc `process.env`, không import DB/ORM/`fs`; luật kiến trúc: secret mang tiền tố `VITE_` |
| `medusa` (extends `node`) | backend lint, unit, build; integration modules + http                                  | `medusa db:reset` (chặn), `db:migrate/generate/rollback`, `mercurjs add`, sửa migration và `medusa-config.ts` | Medusa v2 (tuỳ chọn Mercur); worktree tự tạo DB Postgres       |
| `python`                  | ruff check, ruff format, mypy, pytest (`not integration` / `integration`)              | `uv/poetry/pip add`, Django flush/migrate, Alembic                                                            | uv hoặc Poetry suy từ lockfile; tool chưa cài thì gate bỏ qua |
| `go`                      | gofmt, go vet, golangci-lint, `go test -short -race`, `go build`; `-tags=integration`  | `go get`, golang-migrate/goose/atlas, sửa `go.sum`, migration                                                 |                                                               |

Tạo preset mới: copy `presets/generic` sang `presets/<tên>`, sửa
`files/.harness/config.sh`, thêm `files/.harness/guard.<tên>.rules` kèm
`guard.<tên>.cases`, các snippet và `files/.github/workflows/ci.yml`. Muốn kế
thừa thì ghi tên preset cha vào file `extends`. Rồi chạy `bash tests/run.sh <tên>`.

## Ghi chú thiết kế

- **Payload của hook tách bằng `0x1F`, không dùng tab.** `IFS=$'\t' read` gộp
  các tab liên tiếp, nên với Edit/Write (command rỗng) đường dẫn file rơi vào
  biến command và `FILE_PATH` rỗng: hook PostToolUse thoát sớm và không bao
  giờ chạy linter.
- Hook parse JSON bằng node, rồi python3, rồi jq, nên chạy được trong dự án
  không dùng Node. Riêng `check-harness.mjs` vẫn cần node ≥ 18.
- Hook PreToolUse xử lý cả Edit/Write (`block-path`/`ask-path`), chặn ghi file
  `.env` thật và private key.
- `check-harness.mjs` còn báo lỗi khi `progress.md` không nhắc đến milestone hiện tại.
- Mọi script chạy được với bash 3.2 (mặc định trên macOS).

## Lịch sử

**1.1.0** (2026-11-26):

- Guard git bắt được global option (`git -C <repo> push`, `git --no-pager …`,
  dạng thường gặp khi chạy từ workspace cha) và refspec (`HEAD:main`,
  `+main`, `x:refs/heads/production`), thêm case allow chống false positive.
- `test-guardrails.sh` test cả check nội dung: `.harness/boundary.cases` và
  fixture repo trong `.harness/checks/fixtures/<check>/`.
- `/prepare-phase <N>`: lập checklist phase, chia feature, acceptance
  criteria, chỉ ghi `feature_list.json` sau khi owner duyệt.
- `.githooks/pre-push` (tuỳ chọn): `RUN_INTEGRATION=1 bash init.sh` trước khi
  push, nhớ commit đã pass để push lại không chạy lại.
- `new-worktree.sh`: `HARNESS_WORKTREE_DB_{HOST,PORT,USER,PASSWORD}` trong
  `config.sh`; tự index CodeGraph cho worktree mới nếu checkout có `.codegraph/`.
- Report có mục Screenshots cho feature UI.
- Preset `nest`: post-edit Prettier + oxlint (Nest 12) bên cạnh ESLint, gate
  `format` (`format:check`), link `llms.txt`.
- Preset `tanstack-start`: `start-boundaries.mjs` quét thêm `src/features`, bỏ
  qua `server.ts`; seed `boundary.cases`.
- Script dùng `mktemp` với `$TMPDIR` tường minh (macOS sandbox).

## Kiểm thử template

```bash
bash tests/run.sh             # tất cả preset
bash tests/run.sh node        # một preset
```

Mỗi preset được cài vào một repo git tạm, rồi chạy `check-harness`, toàn bộ
guard case (cả khi không có node), check kiến trúc, cleanup scanner,
`init.sh`, cài lại (phải không đổi gì) và các case phát hiện lỗi (lệch
milestone, `.env` bị track). Preset `node` có thêm một vòng end-to-end: gate
thật, hook PostToolUse với một eslint giả, luật kiến trúc, audit log và
`new-worktree.sh`.
