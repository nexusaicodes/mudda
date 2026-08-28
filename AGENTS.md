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

### One Account, Resolved From the Signed-in User

Mudda serves a single account per deployment, and **URLs carry no account prefix** —
paths are `/boards/:id`, not `/{account_id}/boards/:id`. (Upstream Fizzy prefixed every
path and rewrote `PATH_INFO`/`SCRIPT_NAME` in a Rack middleware; that middleware and
`Account#slug` are gone.)

- `Current.account` is derived in `app/models/current.rb`: session → user → account.
- `Current.account` is therefore **nil on unauthenticated requests**. Anything reachable
  while signed out must not depend on it (see `Users::AvatarsController`).
- **`account_id` lives on `users` and `boards`, and nowhere else.** Everything below a board
  reaches its account through the board (`Account#cards` joins through `boards`), so there is
  one place a record's tenant is written down. `accounts.id` keys the browser-local "last
  opened board" (`ApplicationHelper#last_board_storage_key`) and names the account in error
  context.
- Background jobs serialize and restore `Current.account` explicitly (see Background Jobs),
  since they run with no session.

**Key insight:** the account follows the credential, not the URL — so there is exactly one
canonical path for every resource, which is what lets a fixed API/MCP endpoint work.

### Authentication

**Owner password (standing) + optional passkeys:**
- The `User` is the principal: it carries the `email_address`, holds the passkeys, and owns
  the sessions. There is no separate `Identity`.
- **Password sign-in:** the owner signs in with their email + a deployment secret held in
  `ENV["MUDDA_OWNER_PASSWORD"]`. `OwnerPassword` (`app/models/owner_password.rb`) verifies the
  secret with `secure_compare` and is `enabled?` whenever the secret is configured.
  `Sessions::PasswordsController` handles `POST /session/password`. There is **no password
  column** — the secret lives only in the env. Password stays available regardless of passkeys.
- **Passkeys are optional:** enrolling a passkey (WebAuthn) is a convenience for biometric/device
  sign-in, never required. The owner can add or remove any/all passkeys under `my/passkeys`; doing
  so never disables password sign-in.
- **Recovery:** `bin/rails auth:reset` (`make reset-auth`) removes all passkeys and signs out every
  session. The seed (`db/seeds.rb`) is the source of truth for the owner user/account, and warns
  only when there is neither a password secret nor a passkey (no way to sign in).
- Passkeys (WebAuthn) via `User has_passkeys` + `lib/action_pack/passkey/` and the
  `sessions/passkeys`, `my/passkeys` controllers. (There is no `Credential` model.)
- `Session belongs_to :user`; `Current` resolves session → user → account (the account is
  derived from the user, not the URL — see above). A deactivated user is still named by
  `Current` but has no account, and `Authorization` refuses the request: a browser is signed
  out and redirected to the login page, while a JSON client keeps its session and gets a 403.
- **`Session#kind` says how the user is present** — `browser` (a cookie) or `token` (a script
  or agent). A token always carries a `label` and a browser session never does; both are
  validated, so the two can't disagree. Tokens are minted by `make token` (`auth:token`) or
  by the JSON sign-in, which labels its sessions `json-sign-in` unless the client names
  itself. A label holds one live token: minting under a label revokes the previous one, so a
  JSON client should send its own `label` rather than sharing the default and revoking its
  neighbours. `Session#token` is the single definition of the credential — tokens expire
  after `Session::API_TOKEN_EXPIRY` (90 days), browser cookies do not.
- **No roles, no per-board access control.** The single user can reach every board and card
  in their account (`User#boards => account.boards`, `User#accessible_cards => account.cards`).

### Core Domain Models

**Account** → the tenant/organization. Concerns: `Searchable`. Has users and boards;
`#cards` reaches them through the boards. `create_with_owner` provisions the single user.

**User** → the principal (`belongs_to :account`). Carries `email_address`, `has_passkeys`,
`has_many :sessions`. Concerns: `Accessor`, `Avatar`, `Configurable`, `Named`, `Searcher`.
Owns filters and notes. `deactivate` sets `active: false` and leaves the sessions alone, so
`Authorization` still has a credential to refuse.

**Board** → primary organizational unit. Concerns: `Cards`, `Filterable`,
`Triageable`. **Every board has the same five
fixed columns** (see below). All of the account's boards are visible to the user.

**Column** → a fixed workflow lane (`Colored`, `Positioned`); `has_many :cards`. Names are
fixed; only color is editable.

**Card** → the main work item. Sequential per-board `number` (via
`board.increment!(:cards_count)`), rich-text description, steps, and **notes**. A card is created complete — there is no draft state and nothing to publish; the
compose screen (`cards#new`) holds its state in the browser until one POST creates the card,
its steps included, and `local-save` keeps that state across a reload. Concerns: `Attachments`,
`Colored`, `Notable`, `Due`, `Eventable`, `Golden`, `Multistep`, `Promptable`,
`Searchable`, `Triageable`.

**Note** → a timestamped, rich-text entry on a card (`Card::Notable`). Created via
`card.notes.create!`; only the creator can edit or delete it.

**Event** → records significant actions (card creation/triage/board-change, note creation).
Polymorphic `eventable`, JSON `particulars`. Kept as an audit trail written via the
`Eventable` concern; there is **no activity/timeline page** that renders it (removed — the
app lands on your last-opened board instead).

> **Removed in this fork's refactor (vs. upstream Fizzy):** team collaboration entirely —
> notifications, mentions, assignments, watching, reactions, board access control (`Access`),
> roles, membership/invites/join codes, and public board sharing (`Board::Publication`).
> Also gone: `Tag`/`Tagging` and the `Entropy` auto-postpone system (replaced by due dates;
> see below). `Comment` was renamed to `Note`. `Identity` was folded into `User`, and
> `Card::Goldness` into a boolean on `cards`. The `drafted`/`published` status enum and the
> half-built card record behind it are gone too: a card is composed in the browser and
> created complete, and the card background image is gone with it — pictures live in the
> description, which is rich text and uploads through Active Storage direct upload.
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
- `active?` = not Done/Backlog.

`triage_into(column)` moves a card between lanes. The `card_triaged` event is recorded by an
`after_update` on `column_id`, so **every** lane change is audited whichever door it comes
through — the drop target, the picker, or a `PUT` to the card with a `column_id`.

Reparenting a card is a plain attribute change — `card.update!(board: other)`, or a `PUT` to
the card with a `board_id`. `Card#handle_board_change` does the rest on any such change: it
drops the card into the destination's Triage column, **renumbers it** (numbers run per
board), and re-homes its events and its notes' events. Cards are dropped between columns
through `cards/drops/columns_controller.rb`.

### Due Dates (replaces the old entropy/auto-postpone system)

Cards carry an explicit **`due_on`** date (`Card::Due`):
- `due_on` is required on every card (`validates :due_on, presence: true`), so no save path —
  including the JSON create/update — can persist one without it.
- `overdue?` is true for a card whose `due_on` is in the past.

This replaces the previous "entropy" system (auto-postponing stale cards after inactivity),
which has been removed along with the `entropies` table and the hourly auto-postpone job.

### Web endpoints (REST resources)

Routes (`config/routes.rb`) model behavior as CRUD on resources. **Cards nest under their
board** (`/boards/:board_id/cards/:number`) because `Card#number` is a per-board sequence;
`resolve "Card"` keeps `url_for(card)` and `link_to card` working without the board at every
call site. Nested resources on `cards`: `notes`, and — for the browser alone —
`board` and `column` (the two picker screens), `goldness` (the star), `steps`, and
`drops/column` (the drag-and-drop target, which repaints both lanes).

**A card is one resource, not eleven.** Its board, its lane, its goldness, and its steps are
all attributes of the card, so a client reads them from `GET .../cards/:number` — which
carries the board, the column, every step, and the tail of the note log — and writes them
back with a single `PUT`, via `board_id`, `column_id`, `golden`, and `steps_attributes`
(`accepts_nested_attributes_for :steps`). The browser's one-thing-at-a-time endpoints are the
same associations by another door, and the `BrowserOnly` concern refuses any other format
**before** the action runs, so a JSON request to one is a 406 rather than a write followed by
a 406. Notes are the exception that stays a collection: a card can carry thousands, so it
embeds only the most recent `Card::Notable::EMBEDDED_NOTES_LIMIT` and points at its notes
index for the rest.

The card index answers at both levels: `/cards` spans every board, `/boards/:board_id/cards` narrows to one, and the
same filters apply to either — including `column_ids[]`, which is how a single lane is read
now that columns have no endpoints of their own. `/prompts/cards` (the mention autocomplete)
stays cross-board. A board's five fixed columns travel with the board itself
(`boards/show.json.jbuilder`); what is left under `boards/:id/columns` is the browser's lane
frame and colour picker.

Every declaration carries `only:`/`except:` naming exactly the actions its controller
implements, so `bin/rails routes` lists what is served rather than what `resources` would
imply. A route with no action behind it is a 404 that reads like an endpoint.

Every resource also renders a JSON representation (jbuilder views) that mirrors the web UI,
on the same URL — there is no separate API surface. A browser authenticates with its session
cookie; a script or agent presents the same session as `Authorization: Bearer <token>`
(`make token LABEL=…`). **Every** failure comes back as `{ "errors": { "field": ["message"] } }`
via the `JsonErrors` concern — the 401 and 403 refused by `Authentication`/`Authorization`
as much as the record errors. Indexes answer with `{ "data": [...], "paging": {...} }`
(`PaginationHelper#paging_for`), and an unrecognised query parameter is a 422 rather
than silently ignored — each endpoint declaring what it answers to with
`allows_query_params` (`StrictQueryParams`). See [API.md](API.md).

### Keys and Card Numbers

Primary keys are plain autoincrementing integers — Rails' default, no extensions. What a
`SELECT` prints is the id the app and the API use.

`Card#number` is a **separate** integer, and it is what the API addresses cards by. It is a
**per-board** sequence drawn from `boards.cards_count`, unique only within its board — so
two boards can each hold a card numbered `1`, a card moved between boards is renumbered on
arrival, and a bare number never names a card on its own. Two places that used to treat one
as a unique address now say so: `SearchesController` jumps to a card only while exactly one
board answers to that number, and `Prompts::CardsController` prepends every match.

See [ERD.md](ERD.md) for the full schema — every table, column, index, and relationship,
cross-verified against a live database.

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
