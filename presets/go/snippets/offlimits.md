- Build output: `bin/`, `dist/`, `tmp/`. Never edit or commit it.
- `go.sum`: change it only through `go` commands. `vendor/` only through
  `go mod vendor`.
- Generated code (`*_gen.go`, sqlc/protobuf output): regenerate it, never edit it.
