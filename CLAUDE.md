# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

The authoritative architecture and conventions live in these files, which you should treat as primary:

- **[AGENTS.md](AGENTS.md)** — what Mudda is, dev/test commands, and the big-picture architecture (single account resolved from the signed-in user, owner-password auth + optional passkeys, core domain models, the fixed-column card lifecycle, due dates, per-board card numbers, in-process background jobs, SQLite full-text search).
- **[API.md](API.md)** — the JSON API a script or agent drives: bearer tokens, the resource table, the error envelope, pagination.
- **[ERD.md](ERD.md)** — the full database schema: every table, column, index, and
  relationship, plus the enumerated values.
- **[STYLE.md](STYLE.md)** — house style (conditional returns over guard clauses, method/invocation ordering, bang conventions, CRUD-only controllers, vanilla Rails, `_later`/`_now` job naming).

## This is a standalone, single-person build

Mudda began as a fork of **Fizzy** (37signals), which shipped as a dual OSS + hosted-SaaS
**team** product. This repository has been **trimmed to a single-tenant, single-person,
standalone app** run only through Docker Compose ([DOCKER.md](DOCKER.md)).

Removed infrastructure: the `saas/` engine and second Gemfile, Kamal deploy tooling,
MySQL/Trilogy (now SQLite-only), S3/object storage (local disk only), cross-instance
import/export, the CI/security wrapper scripts, all email/mailers (Action Mailer +
Action Mailbox, SMTP — the app sends no email), and the hosted-SaaS account lifecycle
(the multi-tenant signup toggle, account cancellation, and the scheduled incineration of
cancelled accounts). Also gone: Solid Queue and Solid Cache (jobs now run in-process on the
`:async` adapter; caching uses memory/null stores) and the per-account storage
byte-accounting/quota ledger. Auth is a standing owner password (`MUDDA_OWNER_PASSWORD`) with
optional passkeys layered on top (never required); the old email magic-link OTP and web signup
are gone (see AGENTS.md → Authentication).

Removed team-collaboration features: notifications and mentions, assignments, watching,
reactions, board access control (`Access`) and roles, membership/invites/join codes, and
public board sharing (`Board::Publication`). `Comment` is now `Note`. The single user can
reach every board and card in their account. The recent-activity/timeline page has also been
removed: `Event` rows are still written as an audit trail, but the app now lands on the board
you last had open (remembered in the browser via `localStorage`; see the `LandingsController`
and the `last-board` Stimulus controller).

## Running and testing

Everything goes through Docker Compose — run `make` to list targets:

- `make setup` / `make fresh` — start / wipe-and-restart the app
- `make test` — unit/integration tests; `make lint` — RuboCop
- `docker compose run --rm web bin/rails test PATH` — a single test file
- `docker compose run --rm -e PARALLEL_WORKERS=1 web bin/rails test` — serial run
- `docker compose run --rm web bin/rails test:system` — system tests (`test/system/`), which
  `make test` does **not** run; they drive headless Chrome via Capybara/Selenium

There is no `bin/ci` and no CI test workflow — quality is just RuboCop + the test suite,
both run locally. The one GitHub Actions workflow, `.github/workflows/deploy.yml`, only
builds and deploys (the `Dockerfile`'s `production` target → GHCR → the box over SSH); see [DEPLOY.md](DEPLOY.md).

## Toolchain

- Ruby is pinned in `.ruby-version` (3.4.x); the dev image (the `Dockerfile`'s `dev` target) installs it.
- Rails runs off `main` (edge) plus a couple of forked/branch gems (see `Gemfile`) — expect
  APIs slightly ahead of the latest stable Rails release.
- Style is `rubocop-rails-omakase` with a thin house override in `.rubocop.yml`. Run via
  `make lint`.
- The `:bc` git_source (`github.com/basecamp/...`) in the `Gemfile` resolves real forked
  upstream gems — do **not** repoint it.

## Branding placeholders

One fork placeholder may still need a real value: the `nexus-ai/mudda` GitHub org. The
public sign-in-page logo links to `root_path`. The app no longer renders a colophon, so the
old `mudda.do`/`nexus.ai` links and the `support@mudda.do` footer email are gone.

The permitted dev host is `app.mudda.localhost` (`config/environments/development.rb`), so
use **http://app.mudda.localhost:3006** (or `http://localhost:3006`).
