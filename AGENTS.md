# Mudda

This file provides guidance to AI coding agents working with this repository.

## What is Mudda?

Mudda is a collaborative project management and issue-tracking app: a Kanban-style tool for
teams to create and manage **cards** (tasks/issues) on **boards**, move them through a
**fixed set of columns** (the workflow), and collaborate via comments, mentions, reactions,
and assignments.

Mudda is maintained by **Nexus AI** and is a fork of **Fizzy**, originally created by
**37signals**. It ships as open source and is also run as a hosted product via a private
SaaS engine layered on top (see `CLAUDE.md`).

## Development Commands

### Setup and Server
```bash
bin/setup              # Initial setup (installs gems, creates DB, loads schema)
bin/dev                # Start development server (runs on port 3006)
```

Development URL: http://app.mudda.localhost:3006
Login with: david@example.com (development fixtures); the magic-link/password appears in the
Rails console / browser console.

### Testing
```bash
bin/rails test                         # Run unit tests (fast)
bin/rails test test/path/file_test.rb  # Run a single test file
bin/rails test:system                  # Run system tests (Capybara + Selenium)
bin/ci                                 # Run the full CI suite (boots Rails, runs config/ci.rb)

# For parallel test execution issues, use:
PARALLEL_WORKERS=1 bin/rails test
```

`bin/ci` is **not** a shell script — it boots Rails and runs `config/ci.rb` via
`ActiveSupport::ContinuousIntegration`. That file is the source of truth for the pipeline:
Rubocop → bundler-audit → importmap audit → Brakeman → application tests → system tests.

### Database
```bash
bin/rails db:fixtures:load   # Load fixture data
bin/rails db:migrate          # Run migrations
bin/rails db:reset            # Drop, create, and load schema
```

### Other Utilities
```bash
bin/rails dev:email          # Toggle letter_opener for email preview
bin/jobs                     # Manage Solid Queue jobs
```

## Deploy

Deployment is a **SaaS-engine concern** — the Kamal configs live under `saas/config/`
(`deploy.yml`, `deploy.production.yml`, `deploy.staging.yml`, `deploy.beta.yml`), not in the
OSS app. Deploying requires running in SaaS mode.

- Pre-deploy: `bin/rails saas:enable`
- Deploy: `bin/kamal deploy -d <destination>` (requires 1Password CLI for secrets)
- Destinations: `production`, `staging`, `beta1`–`beta4` (`beta` is a template requiring
  `BETA_NUMBER`).

> The deploy configs still reference upstream hosting (e.g. `*-int.37signals.com` hosts,
> `storage.basecamp.com`, container registries). Replace these with Nexus AI infrastructure
> before deploying your own hosted instance — see `CLAUDE.md`.

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

### Authentication & Authorization

**Passwordless magic-link authentication, plus passkeys:**
- A global `Identity` (email-based) can have `Users` in multiple Accounts.
- `Identity#send_magic_link` creates a `MagicLink` and mails it (`MagicLinkMailer`).
- Passkeys (WebAuthn) via `Identity has_passkeys` + `lib/action_pack/passkey/` and the
  `sessions/passkeys`, `my/passkeys` controllers. (There is no `Credential` model.)
- `Session belongs_to :identity`; `Current` resolves session → identity → user (scoped to
  `Current.account`) → account.
- Users have roles: `owner`, `admin`, `member`, `system`.
- Board-level access control via `Access` records (`involvement`: `access_only` / `watching`).

### Core Domain Models

**Account** → the tenant/organization. Concerns: `Storage`, `Cancellable`,
`Incineratable`, `MultiTenantable`, `Searchable`, `Seedeable`. Has users, boards, cards,
columns, webhooks, exports, imports. `create_with_owner` provisions a `system` user plus an
`owner`.

**Identity** → global, email-based principal. `has_passkeys`, `has_many :magic_links,
:sessions, :users, :accounts (through users), :access_tokens`.

**User** → account membership (`belongs_to :account, :identity`). Carries role, board
accesses, watches, assignments. `deactivate` nulls the identity and destroys accesses.

**Board** → primary organizational unit. Concerns: `Accessible`, `Board::Storage`,
`Broadcastable`, `Cards`, `Filterable`, `Publishable`, `Storage::Tracked`, `Triageable`.
Can be "all access" or selective; can be published publicly with a shareable key
(`Board::Publication`). **Every board has the same five fixed columns** (see below).

**Column** → a fixed workflow lane (`Colored`, `Positioned`); `has_many :cards`. Names are
fixed; only color is editable.

**Card** → the main work item. Sequential per-account `number` (via
`account.increment!(:cards_count)`), rich-text description, image attachment, steps,
comments, reactions. Status enum is `drafted` / `published` (`Card::Statuses`); a card is
published via `publish` (which also requires a due date). Key concerns include `Triageable`,
`Due`, `Statuses`, `Golden`, `Pinnable`, `Multistep`, `Watchable`, `Assignable`,
`Commentable`, `Searchable`.

**Event** → records significant actions. Polymorphic `eventable`, JSON `particulars`
(`Event::Particulars`). Drives the activity timeline, notifications, and webhooks
(`after_create_commit` → `Event::WebhookDispatchJob`).

**Access** → board ↔ user join controlling visibility and watching.

> **Removed in this fork's refactor:** `Tag`/`Tagging` (tagging removed entirely; see
> `db/migrate/*_drop_tags.rb`) and the `Entropy` model / auto-postpone system (replaced by
> due dates; see below).

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

Routes (`config/routes.rb`) model behavior as CRUD on resources. Notable nested resources on
`cards`: `draft`, `board`, `column`, `goldness`, `image`, `pin`, `publish`, `reading`,
`watch`, plus `reactions`, `assignments`, `self_assignment`, `steps`, and `comments`
(with nested `reactions`). Boards expose `accesses`, `subscriptions`, `involvement`,
`publication`, and read-only `columns` (`index`/`show`/`update` only — columns are fixed, so
there is no create/destroy/reorder). A `public/` namespace mirrors read-only board/card
views for published boards. Admin tooling (Mission Control Jobs) mounts at `/admin/jobs`.

### UUID Primary Keys

Primary keys are UUIDs (`lib/rails_ext/active_record_uuid_type.rb`): UUIDv7 generated, then
hex → base36, left-padded to a fixed **25-char** string (`36^25 > 2^128`), stored as MySQL
binary / SQLite blob. Note that `Account#external_account_id` (the URL slug) and
`Card#number` are **separate integer sequences**, not UUIDs.

### Background Jobs (Solid Queue)

Database-backed job queue (no Redis); monitored via Mission Control Jobs at `/admin/jobs`.
- The `AccountTenanted` concern (`app/jobs/concerns/account_tenanted.rb`) is `prepend`ed in
  `ApplicationJob`. It serializes `Current.account` as a GID and restores it via
  `around_perform`, so jobs run in the correct tenant context.
- We write shallow jobs that delegate to domain models, using `_later` / `_now` naming
  (see `STYLE.md`).

Recurring jobs (`config/recurring.yml`, production profile):
- `deliver_bundled_notifications` — every 30 min
- `clear_solid_queue_finished_jobs` — hourly at :12
- `cleanup_webhook_deliveries` — every 15 min
- `cleanup_magic_links` — every 4 hours
- `cleanup_exports` — hourly at :20
- `cleanup_imports` — hourly at :25
- `incineration` (`Account::IncinerateDueJob`) — every 8 hours at :16
- `yabeda_actioncable` — SaaS only, every 60s

`beta`/`staging` run only Solid Queue cleanup; `development` aliases `production`.

### Full-Text Search (adapter-dependent)

`app/models/search/` denormalizes searchable content into `Search::Record`, which picks an
adapter at load time based on the database:
- **SaaS / MySQL (Trilogy):** 16 shards (`search_records_0..15`), shard chosen by
  `Zlib.crc32(account_id.to_s) % 16`, queried with `MATCH ... AGAINST (... IN BOOLEAN MODE)`
  and an account-key term for isolation.
- **OSS / SQLite:** a single FTS5 virtual table (`search_records_fts`).

Stemming, highlighting, and query sanitizing live in `Search::Stemmer`,
`Search::Highlighter`, and `Search::Query`.

### Imports and Exports

Let people move between OSS and SaaS Mudda instances:
- Exports/imports read/write **local or S3** storage depending on instance config (both
  must be supported).
- Must handle very large ZIP files (500+ GB) via streaming (`app/models/zip_file/*`, built
  on `zip_kit`, including `remote_io` for S3-backed reads).
- Models in `app/models/account/data_transfer/` and `app/models/zip_file`.

## Tools

### Chrome MCP (Local Dev)

URL: `http://app.mudda.localhost:3006`
Login: david@example.com (passwordless magic-link auth — check the Rails console for the link)

Use Chrome MCP tools to interact with the running dev app for UI testing and debugging.

## Coding style

@STYLE.md
