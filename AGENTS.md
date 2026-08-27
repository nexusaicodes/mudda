# Mudda

This file provides guidance to AI coding agents working with this repository.

## What is Mudda?

Mudda is a personal project management and issue-tracking app: a single-person Kanban tool
to create and manage **cards** (tasks/issues) on **boards**, move them through a **fixed set
of columns** (the workflow), and capture progress with **notes**. Opening the app lands you
on the **board you last had open** (remembered in the browser).

Mudda is maintained by **Nexus AI** and is a fork of **Fizzy**, originally created by
**37signals**. This repository is the standalone, single-person build (see `CLAUDE.md`).

## Development Commands

This is a standalone, single-tenant SQLite build run entirely through Docker Compose.
See [DOCKER.md](DOCKER.md) for the full reference; `make` lists every target.

### Setup and Server
```bash
make setup    # Build the image and start the app (first run)
make logs     # Tail the server log
make down     # Stop, keeping data
make fresh    # Wipe all data and rebuild from scratch
```

Development URL: http://app.mudda.localhost:3006 (or http://localhost:3006)
Login: the owner email + password come from `MUDDA_OWNER_EMAIL` / `MUDDA_OWNER_PASSWORD`
(dev defaults `saksham@nexusai.world` / `mudda-dev-password` in `docker-compose.yml`). The password
is the standing sign-in method; enrolling a passkey (under `my/passkeys`) is optional. `make
reset-auth` removes all passkeys and signs out every session.

### Testing
```bash
make test                                          # Run unit/integration tests
make lint                                          # RuboCop
docker compose run --rm web bin/rails test PATH    # Run a single test file
docker compose run --rm -e PARALLEL_WORKERS=1 web bin/rails test   # Serial run
```

### Database
```bash
docker compose exec web bin/rails db:migrate   # Run migrations
make reset-db                                  # Drop, recreate, and reseed
```

## Deploy

Runs on a **single VPS box** via Docker: the `Dockerfile`'s `production` target, `docker-compose.prod.yml`
(app behind Caddy for auto-HTTPS over an `*.sslip.io` name), and a GitHub Actions workflow
(`.github/workflows/deploy.yml`) that builds/pushes to GHCR and deploys over **SSH** (streams the
compose file, Caddyfile, and a rendered `.env` over the SSH exec channel, then runs
`deploy/remote-deploy.sh` on the box). See
[DEPLOY.md](DEPLOY.md). Kamal and the SaaS engine remain removed. For local runs, use the
Compose setup in [DOCKER.md](DOCKER.md).

## Architecture Overview

### One Account, Resolved From the Signed-in Identity

Mudda serves a single account per deployment, and **URLs carry no account prefix** —
paths are `/boards/:id`, not `/{account_id}/boards/:id`. (Upstream Fizzy prefixed every
path and rewrote `PATH_INFO`/`SCRIPT_NAME` in a Rack middleware; that middleware and
`Account#slug` are gone.)

- `Current.account` is derived in `app/models/current.rb`: session → identity → user →
  account. An identity owns exactly one user, so the first user is the user.
- `Current.account` is therefore **nil on unauthenticated requests**. Anything reachable
  while signed out must not depend on it (see `Users::AvatarsController`).
- Models still carry `account_id` for data isolation, and `Account#external_account_id`
  still exists — it keys the browser-local "last opened board" (`ApplicationHelper#last_board_storage_key`)
  and identifies the account in seeds and error context.
- Background jobs serialize and restore `Current.account` explicitly (see Background Jobs),
  since they run with no session.

**Key insight:** the account follows the credential, not the URL — so there is exactly one
canonical path for every resource, which is what lets a fixed API/MCP endpoint work.

### Authentication

**Owner password (standing) + optional passkeys:**
- A global `Identity` (email-based) owns the single `User` in the account.
- **Password sign-in:** the owner signs in with their email + a deployment secret held in
  `ENV["MUDDA_OWNER_PASSWORD"]`. `OwnerPassword` (`app/models/owner_password.rb`) verifies the
  secret with `secure_compare` and is `enabled?` whenever the secret is configured.
  `Sessions::PasswordsController` handles `POST /session/password`. There is **no password
  column** — the secret lives only in the env. Password stays available regardless of passkeys.
- **Passkeys are optional:** enrolling a passkey (WebAuthn) is a convenience for biometric/device
  sign-in, never required. The owner can add or remove any/all passkeys under `my/passkeys`; doing
  so never disables password sign-in.
- **Recovery:** `bin/rails auth:reset` (`make reset-auth`) removes all passkeys and signs out every
  session. The seed (`db/seeds.rb`) is the source of truth for the owner identity/account, and warns
  only when there is neither a password secret nor a passkey (no way to sign in).
- Passkeys (WebAuthn) via `Identity has_passkeys` + `lib/action_pack/passkey/` and the
  `sessions/passkeys`, `my/passkeys` controllers. (There is no `Credential` model.)
- `Session belongs_to :identity`; `Current` resolves session → identity → active user →
  account (the account is derived from the user, not the URL — see above). A deactivated user
  resolves to no user and no account, and `Authorization` refuses the request: a browser is
  signed out and redirected to the login page, while a JSON client keeps its session and gets
  a 403.
- **No roles, no per-board access control.** The single user can reach every board and card
  in their account (`User#boards => account.boards`, `User#accessible_cards => account.cards`).

### Core Domain Models

**Account** → the tenant/organization. Concerns: `Searchable`.
Has users, boards, cards, columns. `create_with_owner` provisions the single account user.

**Identity** → global, email-based principal. `has_passkeys`, `has_many :sessions, :users,
:accounts (through users)`.

**User** → the account's person (`belongs_to :account, :identity`). Concerns: `Accessor`,
`Avatar`, `Configurable`, `Named`, `Searcher`. Owns filters and notes.
`deactivate` nulls the identity.

**Board** → primary organizational unit. Concerns: `Cards`, `Filterable`,
`Triageable`. **Every board has the same five
fixed columns** (see below). All of the account's boards are visible to the user.

**Column** → a fixed workflow lane (`Colored`, `Positioned`); `has_many :cards`. Names are
fixed; only color is editable.

**Card** → the main work item. Sequential per-account `number` (via
`account.increment!(:cards_count)`), rich-text description, image attachment, steps, and
**notes**. Status enum is `drafted` / `published` (`Card::Statuses`); a card is published via
`publish` (which also requires a due date). Concerns: `Attachments`,
`Colored`, `Notable`, `Due`, `Eventable`, `Golden`, `Multistep`, `Promptable`,
`Searchable`, `Statuses`, `Triageable`.

**Note** → a timestamped, rich-text entry on a published card (`Card::Notable`). Created via
`card.notes.create!`; only the creator can edit or delete it.

**Event** → records significant actions (card triage/publish/board-change, note creation).
Polymorphic `eventable`, JSON `particulars`. Kept as an audit trail written via the
`Eventable` concern; there is **no activity/timeline page** that renders it (removed — the
app lands on your last-opened board instead).

> **Removed in this fork's refactor (vs. upstream Fizzy):** team collaboration entirely —
> notifications, mentions, assignments, watching, reactions, board access control (`Access`),
> roles, membership/invites/join codes, and public board sharing (`Board::Publication`).
> Also gone: `Tag`/`Tagging` (see `db/migrate/*_drop_tags.rb`) and the `Entropy`
> auto-postpone system (replaced by due dates; see below). `Comment` was renamed to `Note`.
> All email/mailers (Action Mailer + Action Mailbox, SMTP) are removed — the app sends no email.
> The email **magic-link OTP** and the web **signup** flow are gone too, replaced by the standing
> owner password with optional passkeys (see Authentication); the owner is provisioned by `db/seeds.rb`.

### Card Lifecycle — Fixed Columns

A card **always lives in exactly one column**, and `column_id` is the **single source of
truth** for its lifecycle. There are no separate closed/not-now/triage state tables.

Every board is created (`Board::Triageable`) with five fixed lanes, in order:

| Column  | Meaning                                  |
|---------|------------------------------------------|
| Triage  | Awaiting triage (default for new cards)  |
| Backlog | Postponed / "not now"                    |
| Todo    | Triaged, queued                          |
| Doing   | In progress                              |
| Done    | Closed                                    |

`Card::Triageable` derives predicates and scopes from the column name:
- `closed?` = in **Done**; `open?` = not Done.
- `postponed?` = in **Backlog**.
- `awaiting_triage?` = in **Triage**; `triaged?` = not Triage.
- `active?` = published and not Done/Backlog.

`triage_into(column)` moves a card between lanes (and records a `triaged` event);
`move_to(new_board)` reparents a card to another board (re-homing its events) and drops it
into the destination board's Triage column. Cards are dropped between columns through
`columns/cards/drops/columns_controller.rb`.

### Due Dates (replaces the old entropy/auto-postpone system)

Cards carry an explicit **`due_on`** date (`Card::Due`):
- `due_on` is required whenever a card is published (`validates :due_on, presence: true, if: :published?`),
  so no save path — including the JSON create/update — can persist a published card without one.
- `overdue?` is true for a published card whose `due_on` is in the past.

This replaces the previous "entropy" system (auto-postponing stale cards after inactivity),
which has been removed along with the `entropies` table and the hourly auto-postpone job.

### Web endpoints (REST resources)

Routes (`config/routes.rb`) model behavior as CRUD on resources. Nested resources on `cards`:
`draft`, `board`, `column`, `goldness`, `image`, `publish`, `steps`, and `notes`.
Boards expose read-only `columns` (`index`/`show`/`update` only — columns are fixed, so there
is no create/destroy/reorder) and a nested read-only `columns/:id/cards` index.

Every resource also renders a JSON representation (jbuilder views) that mirrors the web UI.
There is **no separate/token-based API**: JSON requests authenticate with the same session
cookie as the browser, so scripting the app means reusing a signed-in session.

### UUID Primary Keys

Primary keys are UUIDs (`lib/rails_ext/active_record_uuid_type.rb`): UUIDv7 generated, then
hex → base36, left-padded to a fixed **25-char** string (`36^25 > 2^128`), stored as a
SQLite blob. Note that `Account#external_account_id` and
`Card#number` are **separate integer sequences**, not UUIDs.

### Background Jobs

Jobs run on Rails' in-process `:async` Active Job adapter in every environment — no Solid
Queue, no Redis, no separate worker process.
- The `AccountTenanted` concern (`app/jobs/concerns/account_tenanted.rb`) is `prepend`ed in
  `ApplicationJob`. It serializes `Current.account` as a GID and restores it via
  `around_perform`, so jobs run in the correct tenant context.
- We write shallow jobs that delegate to domain models, using `_later` / `_now` naming
  (see `STYLE.md`).
- The only job today is `SearchReindexJob`, a manual full-text-index repair run via
  `bin/rails search:reindex`.

### Full-Text Search

`app/models/search/` denormalizes searchable content (cards and notes) into `Search::Record`,
which uses a single SQLite FTS5 virtual table (`search_records_fts`). Search spans every board
in the account. Stemming is handled by the FTS5 `porter` tokenizer; highlighting and query
sanitizing live in `Search::Highlighter` and `Search::Query`.

## Tools

### Chrome MCP (Local Dev)

URL: `http://app.mudda.localhost:3006`
Login: `MUDDA_OWNER_EMAIL` + `MUDDA_OWNER_PASSWORD` (dev: `saksham@nexusai.world` / `mudda-dev-password`).
Enrolling a passkey is optional; to exercise that flow, use a WebAuthn virtual authenticator to drive
the passkey ceremony.

Use Chrome MCP tools to interact with the running dev app for UI testing and debugging.

## Coding style

@STYLE.md
