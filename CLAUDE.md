# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

The authoritative architecture and conventions live in two files you should treat as primary:

- **[AGENTS.md](AGENTS.md)** — what Mudda is, dev/test commands, and the big-picture architecture (URL-based multi-tenancy, passwordless auth + passkeys, core domain models, the fixed-column card lifecycle, due dates, UUIDv7 keys, Solid Queue jobs, SQLite full-text search).
- **[STYLE.md](STYLE.md)** — house style (conditional returns over guard clauses, method/invocation ordering, bang conventions, CRUD-only controllers, vanilla Rails, `_later`/`_now` job naming).

## This is a standalone build

Mudda began as a fork of **Fizzy** (37signals), which shipped as a dual OSS + hosted-SaaS
product. This repository has been **trimmed to a single-tenant, standalone app** run only
through Docker Compose ([DOCKER.md](DOCKER.md)). Removed: the `saas/` engine and second
Gemfile, Kamal deploy tooling, MySQL/Trilogy (now SQLite-only), S3/object storage (local
disk only), web push notifications, cross-instance import/export, the Mission Control jobs
dashboard, and the CI/security wrapper scripts.

`Mudda.saas?` (`lib/mudda.rb`) is hardcoded `false`; the predicate remains only because a
handful of view/job branches still reference it.

## Running and testing

Everything goes through Docker Compose — run `make` to list targets:

- `make setup` / `make fresh` — start / wipe-and-restart the app
- `make test` — unit/integration tests; `make lint` — RuboCop
- `docker compose run --rm web bin/rails test PATH` — a single test file
- `docker compose run --rm -e PARALLEL_WORKERS=1 web bin/rails test` — serial run

There is no `bin/ci`, no GitHub Actions, and no production `Dockerfile` — quality is just
RuboCop + the test suite, both run locally.

## Toolchain

- Ruby is pinned in `.ruby-version` (3.4.x); the dev image (`Dockerfile.dev`) installs it.
- Rails runs off `main` (edge) plus a couple of forked/branch gems (see `Gemfile`) — expect
  APIs slightly ahead of the latest stable Rails release.
- Style is `rubocop-rails-omakase` with a thin house override in `.rubocop.yml`. Run via
  `make lint`.
- The `:bc` git_source (`github.com/basecamp/...`) in the `Gemfile` resolves real forked
  upstream gems — do **not** repoint it. `Integration::Basecamp` / `for_basecamp?` webhook
  code is a genuine Basecamp integration feature, not branding.

## Branding placeholders

Some fork placeholders may still need real values: onboarding media URLs in
`app/models/account/seeder.rb` (`videos.37signals.com/...`), the `https://nexus.ai` colophon
link, `support@mudda.do`, the `mudda.do` domain, and the `nexus-ai/mudda` GitHub org.
