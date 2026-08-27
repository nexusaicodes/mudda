# Mudda API

Every resource in Mudda renders a JSON representation alongside its HTML one, on the same
URL. There is no separate API surface to learn: `GET /boards/123` returns a page,
`GET /boards/123.json` returns the board.

Because Mudda serves a single account, **URLs carry no account prefix** and the account
follows whoever the credential belongs to. See [AGENTS.md](AGENTS.md).

## Authenticating

Two credentials work, and both resolve to the same `Session`.

**A token** — for scripts, agents, and anything without a cookie jar. Mudda runs through
Docker Compose, so the task runs in the app's container:

```bash
make token LABEL=claude               # prints the token on the last line
# or: docker compose run --rm web bin/rails auth:token
```

Send it on every request:

```bash
curl -H "Authorization: Bearer $TOKEN" https://your-mudda/boards.json
```

The scheme is matched **case-sensitively**: `Bearer` and `Token` are accepted, `bearer` is
not. A token is valid for **90 days** from the moment it is minted, and an expired one is
refused exactly like a revoked one — a `401`, with nothing to distinguish the two, so treat
a sudden `401` on a long-lived agent as "mint a new token". A browser session does not
expire on a timer.

An `Authorization` header always decides the request: present one and the session cookie is
ignored entirely, so a tool running on a machine that is also signed in gets the user it
asked for — and a token that is rejected is a `401`, never a quiet fallback to whatever
browser session happened to be around.

**Signing in over JSON** returns the same kind of token, if minting one from a shell isn't
convenient. Sessions minted this way are labelled `json-sign-in`:

```bash
curl -X POST https://your-mudda/session/password.json \
  -H 'Content-Type: application/json' \
  -d '{"email_address":"you@example.com","password":"…"}'
# => {"session_token":"…"}
```

Like every other write, the credentials may be sent flat as above or wrapped
(`{"session":{"email_address":"…","password":"…"}}`).

Add `"label"` to name the token, exactly as `make token LABEL=…` does. **Give every client
its own** — a label holds one live token, so two clients sharing the default `json-sign-in`
would revoke each other on every sign-in:

```bash
-d '{"email_address":"you@example.com","password":"…","label":"claude"}'
```

Sign-in is rate limited to 10 attempts every 3 minutes.

### Managing tokens

| Command | What it does |
|---|---|
| `make token LABEL=claude` | Mint a token and print it (unlabelled mints as `api`) |
| `make tokens` | List minted tokens, when they were created, and when they expire |
| `make revoke LABEL=claude` | Revoke every token with that label |
| `make reset-auth` | Revoke everything, tokens and browser sessions alike |

Each wraps `bin/rails auth:*` in the app's container; run
`docker compose run --rm web bin/rails auth:token` directly if you prefer.

Labels exist so an agent's access can be revoked without signing your browser out. Give every
agent its own label — everything sharing one label is revoked together, so
`make revoke LABEL=json-sign-in` ends every session minted through the JSON sign-in.

**A label holds one live token.** Minting under a label revokes whatever token that label
already had, so an agent that signs in on every run replaces its credential rather than
leaving a pile of them behind. `DELETE /session.json` ends the token making the request;
revoking any *other* token needs shell access to the box.

A bearer request is never handed a session cookie, and an unauthenticated JSON request
returns `401` rather than redirecting to the sign-in page.

## Resources

Requests and responses are JSON. Writes accept either flat attributes
(`{"title":"…"}`) or wrapped (`{"card":{"title":"…"}}`).

### Who am I

`GET /my/user.json` reports the signed-in user — `id`, `name`, `email_address` — with the
account nested under `account`. There is one id here, and it is the user's.

### Boards

| Verb | Path | Notes |
|---|---|---|
| `GET` | `/boards.json` | Every board |
| `POST` | `/boards.json` | `name` |
| `GET` | `/boards/:id.json` | Includes the board's five columns, in order |
| `PUT` | `/boards/:id.json` | `name` |
| `DELETE` | `/boards/:id.json` | |

### Columns

Every board has the same five fixed lanes — Triage, Backlog, Todo, Doing, Done. They can't
be created, reordered, or deleted; only their colour is editable.

| Verb | Path | Notes |
|---|---|---|
| `GET` | `/boards/:board_id/columns.json` | Ordered by `position` |
| `GET` | `/boards/:board_id/columns/:id/cards.json` | Published cards in that lane |
| `PUT` | `/boards/:board_id/columns/:id.json` | `color` |

### Cards

Cards are addressed by their **`number`** — the small integer the UI shows — not their id.
**Numbers run per board**, so a number alone does not name a card: every path below carries
the board. Two boards each holding a card numbered `1` is normal, and a card moved to
another board is renumbered on arrival.

| Verb | Path | Notes |
|---|---|---|
| `GET` | `/cards.json` | Every board — filterable, see below |
| `GET` | `/boards/:board_id/cards.json` | That board only — same filters |
| `POST` | `/boards/:board_id/cards.json` | `title`, `description`, `due_on`. **`due_on` is required** |
| `GET` | `/boards/:board_id/cards/:number.json` | Includes `steps` |
| `PUT` | `/boards/:board_id/cards/:number.json` | `title`, `description`, `due_on`, `board_id` |
| `DELETE` | `/boards/:board_id/cards/:number.json` | |
| `PUT` | `/boards/:board_id/cards/:number/column.json` | `column_id` — moves the card between lanes, returns the moved card |
| `POST` `DELETE` | `/boards/:board_id/cards/:number/goldness.json` | Pin and unpin |
| `DELETE` | `/boards/:board_id/cards/:number/image.json` | Remove the background image |
| `POST` | `/boards/:board_id/cards/:number/publish.json` | Publish a draft; `422` without a `due_on` |

A card is created published, in Triage, and every lane change from there records an event.
`due_on` is required on any published card, so a create without one is a `422`. Every card
in an index carries its own `url`, which is the reliable way to reach it again.

**Moving a card to another board is an update**, since a card's board is one of its
attributes: `PUT /boards/1/cards/7.json` with `{"board_id": 2}`. The card lands in the
destination's Triage column, is **renumbered** there, and takes its events with it — so the
number and the URL you used to reach it are both stale afterwards. Read the new ones from the
response. A `board_id` the caller can't reach is a `404`, not a move.

Both card indexes take the same filters; nesting one under a board narrows it to that board
rather than replacing the filter. `GET /boards/:board_id/cards.json` is the cheap way to walk
one board — `/boards/:board_id/columns/:id/cards.json` narrows further, to a single lane.

`GET /cards.json` accepts `board_ids[]`, `column_ids[]`, `card_ids[]`, `terms[]` (full-text),
`creation` (a time window), `indexed_by` (`all` or `golden`) and `sorted_by` (`latest`,
`newest` or `oldest`), alongside `page`. **Anything else is a `422` naming the offending
parameter**, so a misspelled filter fails loudly rather than quietly widening the result set:

```json
{ "errors": { "column_id": [ "is not a recognised parameter" ] } }
```

**Every** JSON index is held to this, each against its own contract: `q` is a search
parameter and a `422` on `/cards.json`, `column_ids[]` is a card filter and a `422` on
`/search.json`, and the indexes that take no filters at all (a card's notes and steps, a
board's columns) accept only `page`.

Cards report `closed` (in Done), `postponed` (in Backlog), `overdue`, `golden`, `due_on`,
and `color`.

### Notes and steps

| Verb | Path | Notes |
|---|---|---|
| `GET` `POST` | `/boards/:board_id/cards/:number/notes.json` | `body`. Published cards only |
| `GET` `PUT` `DELETE` | `/boards/:board_id/cards/:number/notes/:id.json` | Only the creator may edit or delete |
| `GET` `POST` | `/boards/:board_id/cards/:number/steps.json` | `content`, `completed` |
| `GET` `PUT` `DELETE` | `/boards/:board_id/cards/:number/steps/:id.json` | |

### Search

`GET /search.json?q=…` runs full-text search across every board and returns cards. A query
that is exactly a card number jumps straight to that card — but only while one board answers
to that number; once two do, the search results are returned instead.

## What isn't here

There is no separate API: JSON and HTML come from the same routes, so `bin/rails routes`
lists both audiences at once. Anything that only renders a form or a Turbo fragment answers
`406` to a `.json` request — every `new` and `edit` path, plus `/`, `/landing`, `/my/menu`,
`/my/passkeys`, `/prompts/cards` (the `#`-mention autocomplete), the draft screen, the
drag-and-drop drop target, and the filter and search-history endpoints the filter chrome
posts to. Build a client from the tables above, not from the route list.

Two asymmetries worth knowing: `image` has only `DELETE` — attaching one is a multipart card
update — and `publish` has no inverse, so a published card cannot be returned to a draft.

## Errors

Every failure comes back in one shape — including the ones that carry no record, so a client
never has to branch on the response to find out what went wrong:

```json
{ "errors": { "due_on": ["can't be blank"] } }
```

| Status | When |
|---|---|
| `401` | No credential, or a token that has been revoked or expired |
| `403` | The user is deactivated |
| `404` | No such record — including a `column_id` that isn't on the card's board |
| `422` | Validation failed, or an unrecognised query parameter; the keys name the fields |
| `429` | Sign-in rate limit |

## Pagination

Every index answers with the same envelope — the records under `data`, the paging under
`paging`:

```json
{
  "data": [ … ],
  "paging": { "total": 42, "page": 1, "pages": 3, "next": "https://your-mudda/cards.json?page=2" }
}
```

`next` is the URL of the following page, or `null` on the last one — follow it rather than
building page numbers yourself. It is built from the request's own host, and is `null` for
any page at or past the end, so following it always terminates. Indexes that return everything they have (a board's columns,
a card's steps) carry the same block, reporting a single page, so nothing has to special-case
them.

There is no `per_page`, because the page size is not fixed: pages ramp **15, 30, 50, then 100
records** and stay at 100 (`geared_pagination`). Read `total` and `pages`, not a page size.

The `X-Total-Count` and `Link: <…?page=2>; rel="next"` headers carry the same information and
are still set on JSON requests.
