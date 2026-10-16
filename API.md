# Mudda API

Every resource a client needs has a JSON representation on the same URL as its page:
`GET /boards/123` returns a page, `GET /boards/123.json` (or `?format=json`) returns the board.
URLs carry no account prefix; the account is whoever the credential belongs to.

An AI agent can drive the same API as MCP tools at `/mcp`; see [MCP.md](MCP.md).

## Authenticating

A browser authenticates with its session cookie. Everything else presents a **token**:

```bash
curl -H "Authorization: Bearer $TOKEN" https://your-mudda/boards.json
```

The scheme is matched **case-sensitively**: `Bearer` and `Token` are accepted, `bearer` is not.
An `Authorization` header always decides the request: send one and the cookie is ignored, so a
rejected token is a `401`, never a quiet fallback to a browser session on the same machine. A
browser's session is never accepted as a bearer token, and neither a bearer request nor a JSON
sign-in is ever handed a cookie.

There are four ways to get a token:

- **The browser**: profile (the avatar) → **API tokens**. The token is shown once.
- **A shell** on the box: `make token LABEL=claude`, which prints the token on its last line (see
  [Managing tokens](#managing-tokens)).
- **Signing in over JSON**, as below.
- **OAuth**, which is how MCP clients connect. It produces a token session that behaves like the
  others, except where noted; see [MCP.md → OAuth](MCP.md#oauth).

A minted token is valid for **90 days**. An expired token is refused exactly like a revoked
one, with a `401` and nothing to tell the two apart, so treat a sudden `401` on a long-lived
agent as "mint a new token". A browser session never expires on a timer.

### Signing in over JSON

```bash
curl -X POST https://your-mudda/session/password.json \
  -H 'Content-Type: application/json' \
  -d '{"email_address":"you@example.com","password":"…","label":"claude"}'
# => {"session_token":"…","scopes":["read","write"]}
```

- `label` names the token, as `make token LABEL=…` does. Without one it is `json-sign-in`.
  **Give every client its own label**: a [label holds one live token](#managing-tokens), so
  two clients sharing the default would revoke each other on every sign-in.
- `scopes` (a string or a list) chooses what the token may do; without it the token reads and
  writes. An unknown scope is a `422`.

The credentials may also be wrapped: `{"session":{"email_address":"…","password":"…"}}`.
Sign-in is rate limited to 10 attempts every 3 minutes per IP address.

`POST /session/passkey.json` completes a passkey sign-in and answers `{"session_token":"…"}`. It
always mints a `json-sign-in` token with the default scopes.

### Scopes

A token does what its scopes grant, and the request's verb decides which scope it needs:

| Scope | Allows |
|---|---|
| `read` | `GET` |
| `write` | `POST`, `PUT`, `PATCH`: creating and changing |
| `delete` | `DELETE`, or a write that removes nested records (`"_destroy": true`) |

A token gets `read write` unless asked otherwise, so **`delete` is only ever granted on
request**: tick it on the API tokens page, pass `SCOPES="read write delete"` to `make token`, or
send it in `scopes` at sign-in. A request outside a token's scopes is a `403` before the action
runs, so nothing is written:

```json
{ "errors": { "base": ["This token is not granted the write scope"] } }
```

Two requests are open to every token, whatever its scopes: `DELETE /session.json`, which ends
the token's own session, and `GET /my/user.json`, which reports the token making the request.
Browser sessions are never limited by scope. Tokens minted before scopes existed hold all three.

### Rate limit

Each token may make **600 requests a minute**, across the app's endpoints (Active Storage and
the OAuth endpoints aren't counted). Past that it gets a `429` with `Retry-After: 60`. Requests
refused for their credential, scope, or format (a `401`, the scope or deactivation `403`, a
`406`) don't count, and browsers aren't limited.

### Managing tokens

The API tokens page lists every token with its scopes and expiry, mints new ones, and revokes
them. Only a signed-in browser can use it, so a token can't manage tokens (or passkeys). The same
is available from a shell, each target wrapping a `bin/rails auth:*` task in the app's container:

| Command | What it does |
|---|---|
| `make token LABEL=claude` | Mint a token and print it. Unlabelled, it is `api`. `SCOPES="read write delete"` grants more than `read write` |
| `make tokens` | List tokens (OAuth clients included) with their scopes, when they were minted, and when they expire |
| `make revoke LABEL=claude` | Revoke the tokens carrying that label |
| `make reset-auth` | Revoke every token, browser session, and OAuth grant, and remove every passkey |

**A label holds one live token.** Minting under a label revokes the minted token that label
already had, so an agent that signs in on every run replaces its credential instead of piling
them up. (OAuth clients are counted apart; see [MCP.md → OAuth](MCP.md#oauth).) Labels exist so
one agent's access can be revoked without signing your browser out.
`DELETE /session.json` ends the token making the request; any other token is revoked from the
API tokens page or a shell.

**What a token does is attributed to it.** Every token acts as the account's one user, so the
user is still the creator of what it makes, but the audit trail (`events.agent_name`) records the
token's label. Name tokens after the agent holding them.

A deactivated user's token is refused with a `403` but not revoked; it works again once the user
is reactivated.

## Requests

Requests and responses are JSON. A write accepts its attributes flat (`{"title":"…"}`) or
wrapped in the resource's name (`{"card":{"title":"…"}}`). Attributes an endpoint doesn't take
are ignored.

A create answers `201` with the record and a `Location`; a delete answers `204`.

**Query parameters are checked** on every board, card, note, and search endpoint. Each declares
the ones it answers to, and anything else is a `422` naming the parameter, as is a value outside
a filter's list. A mistaken filter
fails loudly instead of quietly widening the results:

```json
{ "errors": { "column_id": [ "is not a recognised parameter" ] } }
{ "errors": { "due": [ "is not included in the list" ] } }
```

`page`, `previous`, and `format` are accepted everywhere. Each endpoint is checked against its
own list: `q` is a `422` on `/cards.json`, `column_ids[]` is a `422` on `/search.json`, and
boards and notes take nothing but those three.

### Time zone

Timestamps in a response are UTC. "Today", though (what `overdue`, `due=soon`, and `creation`
compare against), is the owner's day: a token has no browser zone of its own, so it gets the
zone saved from the owner's browser, which `GET /my/user.json` reports as `timezone`. Until a
browser has saved one, it is UTC. Any page a browser loads saves the browser's zone if it isn't
the one already saved, so a zone set with `PATCH /my/timezone.json` lasts only until the owner
next loads a page in a browser set to another zone, the same browser included.

## Resources

### You and your account

| Verb | Path | Notes |
|---|---|---|
| `GET` | `/my/user.json` | The signed-in user, with the `account` (`id`, `created_at`) nested in it, the `timezone` the request was reckoned in, and, for a token, `"token": { "label": "claude", "scopes": ["read", "write"] }` |
| `GET` `PATCH` | `/users/:id.json` | `PATCH` takes `name` and `avatar`. Always the signed-in user, whatever the `:id` |
| `DELETE` | `/users/:id/avatar.json` | Removes the avatar |
| `PATCH` | `/my/timezone.json` | `timezone`: an IANA name (`Asia/Kolkata`), the same key `/my/user.json` reports. Saves the owner's zone (see [Time zone](#time-zone)) and answers `204`. A missing or blank zone is a `400`, and a name that isn't a zone a `422` |
| `GET` `PATCH` | `/my/preferences.json` | The owner's `locale` (`en`, `ar`, or `null` to follow the browser) and `theme` (`auto`, `light`, `dark`). `PATCH` changes only the keys sent and answers `204`; an unknown value is a `422` |

A user is `id`, `name`, `email_address`, `active`, `created_at`, `url`, and `avatar_url`.

### Boards

| Verb | Path | Notes |
|---|---|---|
| `GET` | `/boards.json` | Every board, most recently updated first |
| `POST` | `/boards.json` | `name` |
| `GET` | `/boards/:id.json` | Includes the board's four `columns`, in lane order |
| `PUT` | `/boards/:id.json` | `name` |
| `DELETE` | `/boards/:id.json` | |

Every board has the same four fixed lanes: Backlog, Todo, Doing, Done. They can't be created,
reordered, or deleted, so **columns have no endpoints of their own**. Each one in the board's
`columns` carries `id`, `name`, `color`, `position`, `created_at`, and a `cards_url`: the board's card index
narrowed to that lane with `column_ids[]`. Lane colour is set from the board page only.

### Cards

Cards are addressed by their **`number`**, the small integer the UI shows, not their `id`.
**Numbers run per board**, so every card path carries its board, and two boards each holding a
card `1` is normal. Every card carries its own `url`, which is the reliable way to reach it
again.

| Verb | Path | Notes |
|---|---|---|
| `GET` | `/cards.json` | Every board, filterable (below) |
| `GET` | `/boards/:board_id/cards.json` | That board only, with the same filters |
| `POST` | `/boards/:board_id/cards.json` | The whole card in one payload (below) |
| `GET` | `/boards/:board_id/cards/:number.json` | The whole card (below) |
| `PUT` | `/boards/:board_id/cards/:number.json` | Any of the writable fields, plus `board_id` and `column_id` to move it |
| `DELETE` | `/boards/:board_id/cards/:number.json` | |

**What a card reports:** `id`, `number`, `title`, `description` (plain text),
`description_html`, `has_attachments`, `due_on`, `pinned`, `closed` (in Done), `backlogged`
(in Backlog), `overdue`, `color` (its lane's), `last_active_at`, `created_at`, `url`, `board`,
`column`, `creator`, and `notes_url`. In an index that is all. A single card adds all of its
`steps` (`id`, `content`, `completed`), its most recent 20 `notes`, and `notes_truncated`. When
that is `true`, `notes_url` pages through the whole log ([Notes](#notes)).

**What a card takes:** `title`, `description` (rich text, as plain text or HTML), `due_on`
(`YYYY-MM-DD`), `pinned`, `created_at`, `last_active_at`, and `steps_attributes`. Write the
description back from `description_html`, never `description`, or its formatting and
attachments are lost. Images belong in the description: upload them through Active Storage
direct upload (`POST /rails/active_storage/direct_uploads`, which needs `write`) and embed them
in the HTML.

**A card is created complete,** in Backlog, steps included. There is no draft and nothing to
publish, and a `board_id` or `column_id` in the body is ignored:

```
POST /boards/1/cards.json
{ "title": "Ship it", "due_on": "2026-12-01",
  "steps_attributes": [ { "content": "First" }, { "content": "Second" } ] }
```

On a hosted deployment whose plan has a card limit (see
[DOCKER.md → Hosting platform sync](DOCKER.md#hosting-platform-sync)), a create past it is a `422`:
`{ "errors": { "base": ["This account has used all 100 of its cards"] } }`.

**And edited in one request.** A card's board, lane, pinned flag, and steps are attributes of the
card, so a single `PUT` sets any of them:

```json
{ "title": "Ship it", "column_id": 4, "pinned": true,
  "steps_attributes": [ { "id": 12, "completed": true }, { "content": "A new step" } ] }
```

A `PUT` is applied in one write or refused with nothing written. Each change it makes is
recorded as its own event (`card_title_changed`, `card_triaged`, `card_board_changed`).

- **Steps.** `steps_attributes` adds a step (no `id`), edits one (`id` plus the fields to
  change), or removes one (`id` plus `"_destroy": true`, which needs the `delete` scope). A step
  `id` from another card is a `404`. A row with nothing in it is dropped, but blanking the
  `content` of an existing step is a `422`.
- **Due dates.** A card in Todo or Doing needs a `due_on`, so moving an undated card there is a
  `422` (`{ "errors": { "due_on": ["can't be blank in Todo or Doing"] } }`) unless the same
  `PUT` sets one. In Backlog and Done it is optional, and `""` or `null` clears it. A `due_on`
  that isn't a real date (`"2026-02-30"`) is a `422` (`["is invalid"]`) in every lane.
- **Lanes.** `column_id` moves the card to another lane on its board. A `column_id` that isn't
  on the board the card ends on is a `404`.
- **Boards.** `board_id` moves the card to another board, where it lands in Backlog unless a
  `column_id` names one of the destination's lanes. The card is **renumbered** there, so its old
  number and URL are stale: the response's `Location` header carries the new URL, as does the
  body's `url`. An update that leaves the card on its board sends no `Location`. A `board_id`
  that isn't yours is a `404`.

**Filters.** Both card indexes take the same filters; under a board they narrow that board.

| Parameter | Values |
|---|---|
| `board_ids[]` | Board ids |
| `column_ids[]` | Column ids, from a board's `columns` |
| `card_ids[]` | Card `id`s (not numbers) |
| `terms[]` | Full-text terms |
| `creation` | When the card was created: `today`, `yesterday`, `thisweek`, `thismonth`, `thisyear`, `lastweek`, `lastmonth`, `lastyear` |
| `due` | `soon`: open cards due by tomorrow, the most overdue first |
| `lane` | `backlog`, `todo`, `doing`, or `done`, in any case: that lane on every board |
| `indexed_by` | `all` (the default) or `pinned` |
| `sorted_by` | `latest` (most recently active first, the default), `newest`, or `oldest` (by creation). With `due=soon`, only `newest` and `oldest` override its order |

### Notes

Notes stay a collection of their own, because a card can carry thousands of them. For most
cards the 20 embedded in the card are all there is, and the index is only needed when
`notes_truncated` is `true`.

| Verb | Path | Notes |
|---|---|---|
| `GET` `POST` | `/boards/:board_id/cards/:number/notes.json` | Oldest first. `POST` takes `body` (rich text) and optionally `created_at` |
| `GET` `PUT` `DELETE` | `/boards/:board_id/cards/:number/notes/:id.json` | Only the note's creator may change or delete it |

A note reports `id`, `body` (`{ "plain_text": …, "html": … }`), `created_at`, `updated_at`,
`creator`, `url`, and `card` (its database `id` and `url`).

### Search

`GET /search.json?q=…` searches card titles, descriptions, and notes across every board, and
returns the matching cards, most recently active first. A blank `q` returns nothing. A card
number is searched as plain text, so fetch a card by its number from its board. Every word
must match, and `OR`, `AND`, `NOT` and `NEAR` are searched for as words, not operators; wrap
words in double quotes to match them as a phrase.

## What isn't here

JSON is opt-in: each controller names the actions it answers in JSON, and a JSON request to
anything else is a `406` **before the action runs**, so a `406` never leaves a half-done write
behind. `bin/rails routes` lists browser and API routes together, so build a client from the
tables above, not from the route list.

The browser has endpoints for things the API reads and writes as fields. A card's lane
(`…/cards/:number/column`), board picker (`…/board/edit`), pin (`…/pin`), steps (`…/steps`), and
drop target (`…/drops/column`), the compose screen (`…/cards/new`), and a lane's colour
(`/boards/:board_id/columns/:id`) all answer `406`. `PUT` or `POST` the card, or read the
board, instead. Every `new` and `edit` page, `/`, `/landing`, `/my/menu`, `/my/tokens`,
`/my/passkeys`, `/account/upgrade`, and `/prompts/cards` are the browser's
too.

## Errors

Every failure comes back in one shape, in English whatever language the user picked. That
includes failures with no record behind them and ones that never reach a controller, such as an
unknown route or a crash:

```json
{ "errors": { "due_on": ["can't be blank in Todo or Doing"] }, "request_id": "5f0c1e9a-…" }
```

`request_id` is the request's reference, the same value as the `X-Request-Id` response header.
Quote it when reporting a problem: it finds the request in the server's logs. Send your own
`X-Request-Id` and it is used instead, so your logs and the board's share the id.

| Status | When |
|---|---|
| `400` | The body is missing the object a write needs (the key names it), or isn't valid JSON |
| `401` | No credential, or a revoked or expired token |
| `403` | The user is deactivated, the note isn't yours to change, or the token lacks the scope (see [Scopes](#scopes)) |
| `404` | No such record or route, including a `column_id` that isn't on the board the card ends on |
| `406` | The endpoint doesn't answer JSON (see [What isn't here](#what-isnt-here)) |
| `409` | A concurrent change took the same unique value; retry |
| `422` | Validation of what you sent failed, a required field was sent as `null`, a query parameter isn't recognised, or a search can't be parsed; the keys name the fields |
| `429` | The sign-in rate limit, or the token's request allowance (see [Rate limit](#rate-limit)) |
| `500` | A bug (including a record the board writes on its own failing validation), still in the envelope, under `base`; it is reported, and `request_id` identifies it |

## Pagination

Every index answers with the same envelope: the records under `data`, the paging under `paging`.

```json
{
  "data": [ … ],
  "paging": { "total": 42, "page": 1, "pages": 3, "next": "https://your-mudda/cards.json?page=2" }
}
```

`next` is the URL of the following page, built from the request's own host, or `null` on the
last page or past it. Follow it rather than building page numbers yourself, and the walk always
ends.

There is no `per_page`, because the page size isn't fixed: pages ramp **15, 30, 50, then 100
records** and stay at 100. Read `total` and `pages`, not a page size. The `X-Total-Count` and
`Link: <…?page=2>; rel="next"` headers carry the same information.
