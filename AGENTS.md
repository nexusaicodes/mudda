# Mudda

This file provides guidance to AI coding agents working with this repository.

## What is Mudda?

Mudda is a personal project management and issue-tracking app: a single-person Kanban tool
to create and manage **cards** (tasks/issues) on **boards**, move them through a **fixed set
of columns** (the workflow), capture progress with **notes**, and review everything in a
first-person **activity log**.

Mudda is maintained by **Nexus AI** and is a fork of **Fizzy**, originally created by
**37signals**. This repository is the standalone, single-person build (see `CLAUDE.md`).

## Development Commands

This is a standalone, single-tenant SQLite build run entirely through Docker Compose.
See [DOCKER.md](DOCKER.md) for the full reference; `make` lists every target.

### Setup and Server
```bash
make setup    # Build the image and start the app (first run)
make logs     # Tail the server log (magic login links appear here)
make down     # Stop, keeping data
make fresh    # Wipe all data and rebuild from scratch
```

Development URL: http://app.mudda.localhost:3006 (or http://localhost:3006)
Login with: david@example.com (development fixtures); the magic link appears in `make logs`.

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

This is a standalone build with no deploy tooling: the production `Dockerfile`, Kamal
configs, and the SaaS engine have all been removed. Run it locally — or on any Docker
host — with the Compose setup in [DOCKER.md](DOCKER.md).

## Architecture Overview

### Multi-Tenancy (URL-Based)

Mudda uses **URL path-based multi-tenancy** (`config/initializers/tenanting/account_slug.rb`):
- Each Account (tenant) has a unique integer `external_account_id` (assigned via
  `Account::ExternalIdSequence`).
- URLs are prefixed: `/{account_id}/boards/...`.
- The `AccountSlug::Extractor` Rack middleware matches the leading numeric slug, **moves it
  from `PATH_INFO` to `SCRIPT_NAME`** (so Rails treats the app as "mounted" at that path),
  decodes it to an `external_account_id`, looks up the Account, and wraps the request in
  `Current.with_account(...)`.
- Models carry `account_id` for data isolation.
- Background jobs serialize and restore `Current.account` automatically (see Background Jobs).

**Key insight:** multi-tenancy without subdomains or separate databases, which keeps local
development and testing simple.

### Authentication

**Passwordless magic-link authentication, plus passkeys:**
- A global `Identity` (email-based) owns the single `User` in the account.
- `Identity#send_magic_link` creates a `MagicLink` and mails it (`MagicLinkMailer`).
- Passkeys (WebAuthn) via `Identity has_passkeys` + `lib/action_pack/passkey/` and the
  `sessions/passkeys`, `my/passkeys` controllers. (There is no `Credential` model.)
- `Session belongs_to :identity`; `Current` resolves session → identity → user (scoped to
  `Current.account`) → account.
- **No roles, no per-board access control.** The single user can reach every board and card
  in their account (`User#boards => account.boards`, `User#accessible_cards => account.cards`).

### Core Domain Models

**Account** → the tenant/organization. Concerns: `Account::Storage`, `Cancellable`,
`Incineratable`, `MultiTenantable`, `Searchable`. Has users, boards, cards, columns.
`create_with_owner` provisions the single account user.

**Identity** → global, email-based principal. `has_passkeys`, `has_many :magic_links,
:sessions, :users, :accounts (through users)`.

**User** → the account's person (`belongs_to :account, :identity`). Concerns: `Accessor`,
`Avatar`, `Configurable`, `EmailAddressChangeable`, `Named`, `Searcher`, `Timelined`. Owns
filters, pins, and notes. `deactivate` nulls the identity.

**Board** → primary organizational unit. Concerns: `Board::Storage`,
`Cards`, `Filterable`, `Storage::Tracked`, `Triageable`. **Every board has the same five
fixed columns** (see below). All of the account's boards are visible to the user.

**Column** → a fixed workflow lane (`Colored`, `Positioned`); `has_many :cards`. Names are
fixed; only color is editable.

**Card** → the main work item. Sequential per-account `number` (via
`account.increment!(:cards_count)`), rich-text description, image attachment, steps, and
**notes**. Status enum is `drafted` / `published` (`Card::Statuses`); a card is published via
`publish` (which also requires a due date). Concerns: `Attachments`,
`Colored`, `Notable`, `Due`, `Eventable`, `Golden`, `Multistep`, `Promptable`,
`Searchable`, `Statuses`, `Storage::Tracked`, `Triageable`.

**Note** → a timestamped, rich-text entry on a published card (`Card::Notable`). Created via
`card.notes.create!`; only the creator can edit or delete it.

**Event** → records significant actions. Polymorphic `eventable`, JSON `particulars`
(`Event::Particulars`). Drives the first-person activity timeline (`Event::Description`
renders sentences as "You added …").

> **Removed in this fork's refactor (vs. upstream Fizzy):** team collaboration entirely —
> notifications, mentions, assignments, watching, reactions, board access control (`Access`),
> roles, membership/invites/join codes, and public board sharing (`Board::Publication`).
> Also gone: `Tag`/`Tagging` (see `db/migrate/*_drop_tags.rb`) and the `Entropy`
> auto-postpone system (replaced by due dates; see below). `Comment` was renamed to `Note`.

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
- `due_on` is required when a card is published (`validates :due_on, presence: true, on: :publish`).
- `overdue?` is true for a published card whose `due_on` is in the past.

This replaces the previous "entropy" system (auto-postponing stale cards after inactivity),
which has been removed along with the `entropies` table and the hourly auto-postpone job.

### Web endpoints (REST resources)

Routes (`config/routes.rb`) model behavior as CRUD on resources. Nested resources on `cards`:
`draft`, `board`, `column`, `goldness`, `image`, `publish`, `steps`, and `notes`.
Boards expose read-only `columns` (`index`/`show`/`update` only — columns are fixed, so there
is no create/destroy/reorder) and a nested read-only `columns/:id/cards` index. Admin tooling
(Mission Control Jobs) mounts at `/admin/jobs`.

### UUID Primary Keys

Primary keys are UUIDs (`lib/rails_ext/active_record_uuid_type.rb`): UUIDv7 generated, then
hex → base36, left-padded to a fixed **25-char** string (`36^25 > 2^128`), stored as MySQL
binary / SQLite blob. Note that `Account#external_account_id` (the URL slug) and
`Card#number` are **separate integer sequences**, not UUIDs.

### Background Jobs (Solid Queue)

Database-backed job queue (no Redis). In development jobs run on the in-process async
adapter (Solid Queue itself is configured but not the active dev adapter).
- The `AccountTenanted` concern (`app/jobs/concerns/account_tenanted.rb`) is `prepend`ed in
  `ApplicationJob`. It serializes `Current.account` as a GID and restores it via
  `around_perform`, so jobs run in the correct tenant context.
- We write shallow jobs that delegate to domain models, using `_later` / `_now` naming
  (see `STYLE.md`).

Recurring jobs (`config/recurring.yml`):
- `clear_solid_queue_finished_jobs` — hourly at :12
- `cleanup_magic_links` — every 4 hours
- `incineration` (`Account::IncinerateDueJob`) — every 8 hours at :16

### Full-Text Search

`app/models/search/` denormalizes searchable content (cards and notes) into `Search::Record`,
which uses a single SQLite FTS5 virtual table (`search_records_fts`). Search spans every board
in the account. Stemming, highlighting, and query sanitizing live in `Search::Stemmer`,
`Search::Highlighter`, and `Search::Query`.

## Tools

### Chrome MCP (Local Dev)

URL: `http://app.mudda.localhost:3006`
Login: david@example.com (passwordless magic-link auth — check the Rails console for the link)

Use Chrome MCP tools to interact with the running dev app for UI testing and debugging.

## Coding style

@STYLE.md
