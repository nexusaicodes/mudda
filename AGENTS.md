# Mudda

Guidance for AI coding agents, and anyone else, working in this repository.

## What is Mudda?

Mudda is a personal project-management and issue-tracking app: a single-person Kanban tool for
**cards** (tasks) on **boards**, moved through a **fixed set of four columns**, with progress
captured in **notes**. Opening the app lands you on the board you last had open. It is built and
maintained by **Nexus AI**.

It is a **single-tenant, single-person, standalone** app on SQLite, run through Docker Compose.
The single user can reach every board and card in their account.

| Doc | Covers |
|---|---|
| [DOCKER.md](DOCKER.md) | Running it: every `make` target, the owner and env vars, the production image |
| [API.md](API.md) | The JSON API a script or agent drives: tokens, scopes, resources, errors, pagination |
| [MCP.md](MCP.md) | The MCP endpoint at `/mcp`, its tools, and the OAuth server |
| [ERD.md](ERD.md) | The database schema: every table, column, index, and enumerated value |
| [STYLE.md](STYLE.md) | House style |

### Not in Mudda

Mudda began as a multi-tenant team product. These are **gone**; don't reintroduce them, and
treat any trace of them in the code as a leftover:

- **Team collaboration**: notifications, mentions, assignments, watching, reactions, board
  access control (`Access`) and roles, membership, invites and join codes, public board sharing
  (`Board::Publication`).
- **Hosted SaaS**: the `saas/` engine and its second Gemfile, the signup toggle, account
  cancellation and incineration, and the per-account storage quota ledger.
- **Infrastructure**: Kamal and every deploy pipeline, MySQL/Trilogy, S3 and object storage,
  Solid Queue and Solid Cache, cross-instance import/export, `bin/ci` and the CI/security
  wrapper scripts.
- **Email**: Action Mailer, Action Mailbox, SMTP, and with them the magic-link sign-in and web
  signup. The app sends no email.
- **Models and states**: `Identity` (folded into `User`), `Comment` (renamed `Note`),
  `Tag`/`Tagging`, `Card::Goldness` (now the `pinned` boolean on `cards`), the `Entropy` auto-postpone
  system (replaced by due dates), the `drafted`/`published` card states, the card background
  image, the Triage lane (folded into Backlog), and stored filters.
- **Pages**: the recent-activity timeline. `Event` rows are still written as an audit trail,
  but nothing renders them.

## Development

Everything runs through Docker Compose; [DOCKER.md](DOCKER.md) is the reference, and `make`
lists every target. `make setup` starts the app at http://app.mudda.localhost:3006 (or
http://localhost:3006). Sign in with `MUDDA_OWNER_EMAIL` and `MUDDA_OWNER_PASSWORD`, whose dev
defaults are in `docker-compose.yml`.

```bash
make test                                                         # unit and integration tests
make test-system                                                  # system tests (test/system/), which make test skips
make lint                                                         # RuboCop and the i18n checks
docker compose run --rm web bin/rails test PATH                   # one test file
docker compose run --rm -e PARALLEL_WORKERS=1 web bin/rails test  # a serial run
```

System tests drive headless Chromium through Capybara in the `selenium` Compose service (profile
`system`), reached over `SELENIUM_REMOTE_URL`, since the dev image has no browser. There is no CI
test workflow: quality is RuboCop plus the test suite, run locally. The one GitHub Actions
workflow, `.github/workflows/build.yml`, builds the production image (see
[DOCKER.md → Production image](DOCKER.md#production-image)).

To drive the running app from a browser tool (such as Chrome MCP), use the dev URL and owner
credentials above. Passkeys are optional; to exercise them, use a WebAuthn virtual
authenticator.

### Toolchain

- Ruby 3.4.8 is pinned in three places that must agree: `.ruby-version`, the `RUBY_VERSION`
  build arg in `docker-compose.yml`, and the default `ARG` in the `Dockerfile`.
- Rails runs off `main` (edge), plus a couple of gems pinned to git branches (see `Gemfile`), so
  expect APIs slightly ahead of the latest stable release.
- The `:bc` git_source (`github.com/basecamp/...`) in the `Gemfile` resolves real upstream gems.
  Do **not** repoint it.
- Style is `rubocop-rails-omakase` with a thin house override in `.rubocop.yml`.

## Architecture

### One account, resolved from the signed-in user

Mudda serves a single account per deployment, and **URLs carry no account prefix**: paths are
`/boards/:id`, not `/{account_id}/boards/:id`. The account follows the credential, not the URL,
so every resource has exactly one canonical path, which is what lets a fixed API and MCP
endpoint work.

- `Current.account` is derived in `app/models/current.rb`: session → user → account. It is
  therefore **nil on unauthenticated requests**, and anything reachable while signed out must not
  depend on it (see `Users::AvatarsController`).
- **`account_id` lives on `users` and `boards`, and nowhere else.** Everything below a board
  reaches its account through the board (`Account#cards` joins through `boards`), so a record's
  tenant is written down in one place. `accounts.id` keys the browser-local "last opened board"
  (`ApplicationHelper#last_board_storage_key`) and names the account in error context.
- Background jobs carry `Current.account` explicitly (see [Background jobs](#background-jobs)).

### Authentication

The `User` is the principal: it carries the `email_address`, holds the passkeys, and owns the
sessions. The API-facing rules (token lifetime, scopes, labels, rate limits) are specified in
[API.md](API.md#authenticating), and OAuth in [MCP.md](MCP.md#oauth). This section maps them to
the code.

- **Owner password.** The owner signs in with their email and the deployment secret in
  `ENV["MUDDA_OWNER_PASSWORD"]`. `OwnerPassword` (`app/models/owner_password.rb`) verifies it
  with `secure_compare` and is `enabled?` whenever the secret is set.
  `Sessions::PasswordsController` handles `POST /session/password`. Nothing stores the
  password, and it stays available whether or not passkeys exist.
- **Passkeys are optional**: WebAuthn via `User has_passkeys`, `lib/action_pack/passkey/`, and
  the `sessions/passkeys` and `my/passkeys` controllers. There is no `Credential` model. Adding or
  removing passkeys never disables the password.
- **Provisioning and recovery.** `db/seeds.rb` provisions the owner user and account from the
  `MUDDA_OWNER_*` env vars. With neither a password secret nor a passkey there is no way to sign
  in, so the seed warns locally and aborts elsewhere. `bin/rails auth:reset` (`make reset-auth`)
  is the recovery path.
- **`Session#kind`** says how the user is present: `browser` (a cookie) or `token` (a script or
  agent). A token always carries a `label` and a browser session never does; both are validated.
  `Session#token` is the single definition of the credential, and minted tokens expire after
  `Session::API_TOKEN_EXPIRY`. **Each channel accepts only its own kind:** the cookie resolves
  `Session.browser` and a bearer header `Session.token`, so a browser session's never-expiring
  id can't be replayed as a token. Minting under a label revokes that label's previous token
  (`Session#revoke_others_sharing_its_label`).
- **Where tokens come from**: `make token` (`auth:token`), the JSON sign-in (password or
  passkey), `my/tokens` (`My::TokensController`), and OAuth consent. `my/tokens` and
  `my/passkeys` refuse token sessions (`require_browser_session`), so a token can't make itself
  a browser.
- **Scopes.** `Session#scopes` (`read`, `write`, `delete`, stored space-separated, absent on
  browser sessions) bound a token. `Authorization#ensure_token_permits_request` reads the scope
  off the HTTP verb and refuses before the action runs. `allow_any_token_scope` opts an action
  out (`SessionsController#destroy`, `My::UsersController#show`). New tokens default to
  `Session::DEFAULT_SCOPES`.
- **Deactivation.** `Current` still names a deactivated user but gives them no account, and
  `Authorization` refuses the request by the session's kind, not the format asked for: a token
  keeps its session and gets a 403, while a browser is signed out (sent to the login page, or a
  403 if it asked for JSON).
- **Agent attribution.** Every token is the same single user, so `creator` stays that user;
  `Current.agent_name` (the token's label, `nil` for a browser) is written to
  `events.agent_name` by `Eventable#track_event`. There is no per-agent actor model.
- **OAuth 2.1.** Mudda is its own authorization server (Doorkeeper,
  `config/initializers/doorkeeper.rb`). The controllers are `Oauth::ProtectedResourcesController`
  and `Oauth::AuthorizationServersController` (discovery, under `/.well-known/`),
  `Oauth::RegistrationsController` (dynamic client registration), and
  `Oauth::AuthorizationsController` (consent: a subclass of Doorkeeper's whose base is
  `ApplicationController`, so a signed-out browser is sent to sign in). PKCE S256 is forced on
  confidential clients too, by a `PreAuthorization` override in the initializer. Consent
  creates or updates one token `Session` per client (`Session::Oauth`,
  `sessions.oauth_application_id`). A bearer that isn't a minted token's signed id is looked up
  as a Doorkeeper access token and resolves to that session, and destroying the session revokes
  the client's tokens. A minted token is `Session.token.minted`; an OAuth session's own signed
  id is never a credential.
- **Rate limits.** `TokenRateLimit` gives each token its allowance, in its own `MemoryStore`
  (cleared in `test_helper.rb`). Password and passkey sign-in have their own limits.

### Core domain models

**Account**: the tenant. Concerns: `CardLimited`, `Searchable`. Has users and boards; `#cards`
reaches cards through the boards. `create_with_owner` provisions the single user.
`CardLimited` applies the ceiling of the plan a hosting platform names (`PLANS`: free 100,
premium none; a hosted board is free until told otherwise, a self-hosted one has no plan and no
ceiling). `accounts.cards_created_count`
only goes up. A `Card` `before_create` claims a slot in one conditional `UPDATE`, so two creates
can't both take the last one, and raises `RecordInvalid` past the ceiling, which is a `422` for
JSON and MCP. Under a ceiling:
- The compose screen warns within `Account::CardLimited::NEAR_LIMIT` cards of it.
- The board's "Add a card" becomes an upgrade link to the platform's `upgrade_url` once it is reached.
- The profile shows a Plan section (cards used of the limit).

While the platform has given an `upgrade_url`, the profile's Plan section links to `/account/upgrade` at any time.
`GET /account/upgrade` (`Account::UpgradesController`) hands the signed-in owner to that URL,
signing them in first if needed and passing on `billing`
(`monthly`/`yearly`), or sends them back to the board when there is no URL. The platform's "Go
Premium" sends returning customers there.

**User**: the principal (`belongs_to :account`). Carries `email_address`, `has_passkeys`, and
`has_many :sessions`. Concerns: `Accessor`, `Avatar`, `Configurable`, `Named`, `Searcher`. Owns
notes. `deactivate` sets `active: false` and leaves the sessions alone, so `Authorization` still
has a credential to refuse.

**Board**: the primary organizational unit, named (never blank). Concerns: `Cards`,
`Triageable`. Every board has the same four fixed columns (below).

**Column**: a fixed workflow lane (`Colored`, `Positioned`) with `has_many :cards`. Names are
fixed (`attr_readonly :name`, since lane predicates key off them); only color is editable.

**Card**: the main work item, with a per-board `number`, a rich-text description, steps, and
notes. Concerns: `Attachments`, `Colored`, `Notable`, `Due`, `Eventable`, `Pinnable`,
`Multistep`, `Searchable`, `Triageable`. A card is created complete; there is no
draft state. The compose screen (`cards#new`) holds its state in the browser, `local-save` keeps
it across a reload, and one POST creates the card with its steps. Pictures live in the
description, which uploads through Active Storage direct upload.

**Note**: a timestamped, rich-text entry on a card (`Card::Notable`), created with
`card.notes.create!`. Concerns: `Attachments`, `Eventable`, `Searchable`. Only its creator can
edit or delete it.

**Event**: an audit record of a card's creation, title change, lane change, or board change,
or a note's creation. It has a polymorphic `eventable` and JSON `particulars`, and is written
through the `Eventable` concern (see [ERD.md](ERD.md#enumerated-values) for the actions).

### Card lifecycle: fixed columns

A card **always lives in exactly one column**, and `column_id` is the **single source of truth**
for its lifecycle. Every board is created by `Board::Triageable` with four lanes, in order:

| Column | Meaning | `due_on` |
|---|---|---|
| Backlog | Unscheduled work; every new card lands here | Optional |
| Todo | Queued | Required |
| Doing | In progress | Required |
| Done | Closed | Optional |

`Card::Triageable` derives predicates and scopes from the column name: `closed?` is in Done,
`open?` is not in Done, `backlogged?` is in Backlog, and `active?` is in neither Done nor
Backlog. People and agents move cards the same way, and there is no review lane.

- **Lane changes** are a plain attribute write, `card.update(column: other)`. An `after_update`
  on `column_id` records `card_triaged`, so **every** lane change is audited, whichever door it
  comes through: the drop target (`cards/drops/columns_controller.rb`), the picker, or a `PUT`
  with a `column_id`. A move the card can't make (an undated card into Todo or Doing) is refused:
  a `422` for JSON, and from the drop target or the picker the card stays where it was with the
  reason in the flash.
- **Board changes** are a plain attribute write too, `card.update!(board: other)`, and may name
  a lane in the same write. With no lane named, `Card#land_in_destination_backlog` puts the
  card in the destination's Backlog before validation, and `Card::Triageable` validates that a
  card's column is on its board, so no door can leave it in another board's lane. The card is
  renumbered in the same UPDATE. Its events and search rows reach their board through the card,
  so nothing needs re-homing.
- **Every change in a save is recorded.** `Card::Eventable` snapshots the tracked changes
  (title, column, board) in `before_update`, records one event per change from that snapshot,
  and sets `last_active_at` in the same UPDATE. Nothing writes the card again from inside its
  own save: a nested write replaces `saved_changes`, which is how a request that changed two
  things used to record only one.

### Due dates

`Card::Due` gives a card an explicit `due_on`:

- It is required in Todo and Doing and optional in Backlog and Done, so no save path, the JSON
  ones included, can put an undated card in an active lane, while an unscheduled idea can still
  be closed as-is. The error reads "can't be blank in Todo or Doing"
  (`activerecord.errors.models.card.attributes.due_on.blank_while_active`, in
  `config/locales/en/models.yml`).
- A `due_on` that isn't a date, whether a string that doesn't parse (`"2026-02-30"`,
  `"next friday"`) or a non-string such as `20261201` or `true`, is refused as `invalid` in every
  lane, and only as `invalid` (never also "can't be blank"), rather than saved undated.
- `overdue?` is true for a card whose `due_on` is in the past.

### Keys and card numbers

Primary keys are plain autoincrementing integers ([ERD.md](ERD.md)). `Card#number` is a
**separate**, **per-board** sequence drawn from
`boards.cards_count` (`board.increment!(:cards_count)`), and it is what the API addresses cards
by. Two boards can each hold a card `1`, and a card moved between boards is renumbered on
arrival. A bare number never names a card on its own: search treats a number as plain text, and
`Prompts::CardsController` prepends every match.

### Web endpoints

Routes (`config/routes.rb`) model behavior as CRUD on resources. **Cards nest under their
board** (`/boards/:board_id/cards/:number`), because the number is a per-board sequence;
`resolve "Card"` keeps `url_for(card)` and `link_to card` working without the board at every
call site. Every declaration that serves fewer than all seven actions names them with
`only:`/`except:`, so `bin/rails routes` lists what is served rather than what `resources` would
imply.

Nested under a card are `notes`, and, for the browser alone, `board` and `column` (the two
picker screens), `pin` (the pin button), `steps`, and `drops/column` (the drag-and-drop target,
which repaints both lanes).

**A card is one resource.** Its board, lane, pinned flag, and steps are attributes of the card, so
a client reads them from `GET …/cards/:number` and writes them back with a single `PUT`
(`steps_attributes` via `accepts_nested_attributes_for :steps`). The browser's
one-thing-at-a-time endpoints are the same associations by another door. Notes stay a
collection, since a card can carry thousands; it embeds only the most recent
`Card::Notable::EMBEDDED_NOTES_LIMIT`.

The card index answers at both levels: `/cards` spans every board and `/boards/:board_id/cards`
narrows to one, with the same filters. A board's four columns travel with the board
(`boards/show.json.jbuilder`); what is left under `boards/:id/columns` is the browser's lane
frame and colour picker. `/prompts/cards` is the `#` card-reference autocomplete, and stays
cross-board.

**JSON** lives on the same URLs, rendered by jbuilder views; there is no separate API surface.
The contract is [API.md](API.md). The mechanics:

- **JSON is opt-in.** Each controller names the actions it answers in JSON with `serves_json`
  (`ServesJson`, in `ApplicationController`), and a JSON request to any other action is a 406
  **before** the action runs, so an endpoint that never thought about JSON can't write and then
  fail to render.
- **Every failure** comes back as `{ "errors": { "field": ["message"] } }` through `JsonErrors`,
  the 401 and 403 from `Authentication` and `Authorization` included. Failures outside a
  controller go through `lib/json_public_exceptions.rb`.
- **Indexes** answer with `{ "data": [...], "paging": {...} }` (`PaginationHelper#paging_for`).
- **Unrecognised query parameters** are a 422 on controllers that include `StrictQueryParams`
  (boards, cards, notes, steps, columns, search). Each declares what it answers to with
  `allows_query_params`.

### Web UI

The browser is for an occasional look, since agents do most of the work through the API. The
chrome is small and there are **no keyboard shortcuts**: keys only act inside the field being
typed in (Enter or Ctrl/Cmd+Enter submits, Esc cancels).

- **Landing.** `/` (`LandingsController`) sends you to the board you last had open, remembered
  in `localStorage`, or else the most recently active one. The `last-board` Stimulus controller writes it, and the landing page reads
  it (an inline script on a full load, the `landing` controller on a Turbo visit).
- **One-row header** (`layouts/application`): the logo on the left of every signed-in page,
  then the page's back link if it has one (`content_for :header_start`), the page title in the
  centre, and the avatar on the right (`my/_account_link`), a plain link to the profile. The
  profile (`users/show`) holds appearance, language, the plan, passkeys, API tokens, and sign
  out; there is no account settings page and no account name.
- **Board title** (`boards/_title`): clicking the name renames the board in place
  (`inline-edit` controller) with just Save and Cancel; the input takes the title's own type, so
  the header doesn't jump. There is no board settings page.
- **Switcher**: the ▾ beside a board or view title (`my/_switcher`), loading `my/menus#show` on
  first open. It lists every board (the current one ticked and shaded) with "New board" after
  them, then the cross-board views in `Filter::VIEWS` with their counts (the current one ticked,
  an empty one dimmed), and, on a board, "Delete this board…" last, behind a confirmation
  (`boards/_delete`).
- **Cross-board views** are the card index with a view's filter (`/cards?due=soon`,
  `?lane=doing`, `?indexed_by=pinned`), drawn as cards grouped under their board. The board page
  itself takes no filters. A `Filter` is read from the query for each request and never stored;
  a value outside its list is refused (`400`, or `422` for JSON).
- **Search** is a pill floating at the bottom centre (`bar/_bar`). Results open above it,
  grouped by board with the board you searched from first: one row per card, the five latest per
  board, and a link to the rest (`User::Searcher#search_counts_by_board`, `#search_boards`).

### Background jobs

Jobs run on Rails' in-process `:async` Active Job adapter (the `:test` adapter in tests), with
no Solid Queue, Redis, or separate worker process. Likewise the cache is a memory store (the null
store in tests, and in development unless caching is toggled on), which is why the rate limiters
keep `MemoryStore`s of their own.

- The `AccountTenanted` concern (`app/jobs/concerns/account_tenanted.rb`) is `prepend`ed in
  `ApplicationJob`. It serializes `Current.account` as a GID and restores it in `around_perform`,
  so jobs run in the right tenant.
- Jobs should be shallow and delegate to domain models, with `_later`/`_now` naming (see
  [STYLE.md](STYLE.md#run-async-operations-in-jobs)).
- `SearchReindexJob` is a manual full-text-index repair run by `bin/rails search:reindex`, and
  `WebhookDeliveryJob` sends one event to the hosting platform (see
  [Hosting platform sync](#hosting-platform-sync)).

### Full-text search

`app/models/search/` denormalizes cards and notes into `Search::Record`, backed by one SQLite
FTS5 virtual table (`search_records_fts`) with the `porter` tokenizer. Search spans every board
in the account, scoped through the card (`Search::Record.for_query` reads
`user.accessible_cards`).

The FTS table holds text folded by `Search::Normalizer`, and `Search::Query` (a plain model of
what was typed, not a table) folds the query the same way. The folding is Arabic only: harakat and tatweel are stripped, alef, yeh, and teh
marbuta are folded, and the article ال is removed. So a search matches with or without vowel
marks or the article. `search_records` keeps the text as written, and `Search::Highlighter`
marks it in Ruby. A change to the normalizer needs `bin/rails search:reindex`, or a data
migration that runs it, as `20261014000001` does.

### Time zones

Timestamps are rendered by the browser (the `local-time` Stimulus controller), so they always
read in the viewer's zone. Dates are the server's: due-date labels and colours, overdue
ordering, `due=soon`, and `creation=today` compare against `Date.current`, so each request runs
in one zone (`CurrentTimezone`, `app/controllers/concerns/current_timezone.rb`):

1. the browser's, from the `timezone` cookie the `timezone-cookie` controller sets;
2. else the owner's saved zone, `user_settings.timezone_name`. This is what a token (a script
   or an MCP agent) gets, so an agent's "today" is the owner's, and what a browser gets on its
   first request, before the cookie exists;
3. else UTC.

`layouts/shared/_time_zone` saves the browser's zone through `My::TimezonesController` whenever
it differs from the saved one, so the saved zone follows the browser the owner used last. Zone
names are saved as the browser reports them, aliases included (Chromium says `Asia/Calcutta` for
India): canonicalising would turn zones tzdata merged into links into another city's
(`Europe/Amsterdam` into `Europe/Brussels`). The aliases resolve because the `tzinfo-data` gem
bundles the whole zone database; don't rely on the OS's, which leaves them out. The saved zone
needs the signed-in user, so `allow_unauthenticated_access` resumes the session ahead of every
other callback. HTML caches that hold a date are keyed on `Date.current`, and the resolved zone
is part of every ETag, so neither is served across a change of day or zone.

### Internationalization

The browser UI speaks English and Arabic (right-to-left). `CurrentLocale`
(`app/controllers/concerns/current_locale.rb`) picks each request's locale: the user's
`user_settings.locale` (chosen on the profile page through `My::PreferencesController`, which also saves the theme,
and seeded once from `MUDDA_OWNER_LOCALE` when `db/seeds.rb` creates the owner, so a hosted board
opens in the language its owner signed up in), else the
browser's `Accept-Language`, else English. URLs carry no locale.

- **JSON, and so every MCP tool call, always answers in English**: errors, enum values, lane
  names, and the 401/403 refused before the action runs.
- **Lanes stay English keys** (`columns.name`, the API, `lane=`); only the display goes through
  `lane_name(column)` → `lanes.*`. Never compare against a translated name.
- **Every HTML cache key carries `I18n.locale`** (card and note fragments, the column
  collection), and `etag { I18n.locale }` keeps a conditional GET from serving the other
  language.
- Strings live in `config/locales/{en,ar}/*.yml`, one file per area, looked up lazily in views
  (`t(".key")`). Missing translations raise in dev and test. `make i18n` (also part of
  `make lint`) checks for missing, unused, and unnormalized keys, and `test/i18n_test.rb` runs
  the same checks.
- `<html lang dir>` comes from the locale. CSS uses logical properties; where it can't, a
  `[dir=rtl]` rule mirrors it. Arabic renders in IBM Plex Sans Arabic (`app/assets/fonts`, OFL),
  loaded only for Arabic code points. Dates show Western digits (`-u-nu-latn`).
- The `public/*.html` error pages are static, so each carries both languages.

### Hosting platform sync

A hosting platform (Mudda Cloud) keeps the board in step with its tenant record. It is optional:
without `MUDDA_PLATFORM_KEYS` ([DOCKER.md](DOCKER.md#hosting-platform-sync)), the only setting it
needs, as when self-hosting, the board behaves as if it didn't exist. Everything else it sends is
kept in the database.

- **Platform → board** (`Platform::Message`, `Platform::MessagesController` at
  `POST /platform/messages`): messages signed with the platform's Ed25519 key. The signature is
  the only credential, so no session or token the owner holds can send one, and the owner can't
  lift their own card limit. A message must name a trusted `kid`, be addressed to `BASE_URL`'s
  host, be at most five minutes old, and carry a `seq` above `accounts.platform_seq`, which is
  claimed in the same `UPDATE` that applies it. Kinds: `plan.updated` (`accounts.plan` and
  `upgrade_url`; an unknown plan is refused so the platform retries until the board knows it),
  `sync.configured` (`webhook_url` and `webhook_secret`), `name.updated`, and `state.requested`
  (the reconcile's read of the owner's name and email, the plan, whether webhooks are configured,
  and `platform_seq`).
- **Board → platform** (`WebhookDelivery`): a rename (`user.updated`) and the card that takes the
  last slot (`cards.limit_reached`) are written to `webhook_deliveries` in their own transaction
  and POSTed after commit to the configured URL, HMAC-signed with its secret, retried with backoff for a week. Pending rows are sent
  again at boot and whenever the platform asks for the state, since the in-process job queue
  doesn't survive a restart.
- **The name** may change on either side; `users.name_changed_at` decides, the newer winning and
  a tie keeping the local name (`User::Syncable`). A rename applied from the platform isn't sent
  back.
- **The email never changes**, anywhere: the board has no way to edit it, a message whose payload
  names an email is refused, and `db/seeds.rb` aborts rather than create a second owner when
  `MUDDA_OWNER_EMAIL` doesn't match.

### MCP

`/mcp` serves the JSON API to AI agents as MCP tools. `Mudda::Mcp::Endpoint` (`lib/mudda/mcp/`)
is a middleware ahead of `ActionDispatch::Executor`, and each tool is one in-process JSON API
request made with the client's token, so tools carry no business logic. `lib/mudda` is required,
not autoloaded, so restart after changing it. See [MCP.md](MCP.md#how-it-works).

## Coding style

See [STYLE.md](STYLE.md).
