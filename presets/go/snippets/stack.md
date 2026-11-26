- **Application:** Go <version> (`go.mod`), <framework/router>, in
  `cmd/<name>` and `internal/`.
- **Datastore:** <database> via <pgx / sqlc / gorm / ent>; migrations with
  <golang-migrate / goose / atlas>.
- **Tooling:** Go modules; `go.mod`/`go.sum` change only through `go` commands.
  gofmt, go vet and golangci-lint.
- **Tests:** `go test`; tests that need live services carry the
  `integration` build tag.
