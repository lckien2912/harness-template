Read the version-matched docs before writing code against a package:
`node_modules/@nestjs/<package>/README.md` (and any bundled `llms.txt`), then
https://docs.nestjs.com/llms.txt (one markdown page per chapter) for the pinned
major; prefer the first-party package (`@nestjs/config`, `@nestjs/bullmq`,
`@nestjs/throttler`, …) before another library. The same for the ORM. Generate
building blocks with the Nest CLI so they follow the conventions and are
registered in their module: `nest g resource|module|controller|service <name>`,
with `--dry-run` first. Use a NestJS agent skill or docs MCP server when the
session has one.
