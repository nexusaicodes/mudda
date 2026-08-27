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

**Signing in over JSON** returns the same kind of token, if minting one from a shell isn't
convenient. Sessions minted this way are labelled `json-sign-in`:

```bash
curl -X POST https://your-mudda/session/password.json \
  -H 'Content-Type: application/json' \
  -d '{"email_address":"you@example.com","password":"…"}'
# => {"session_token":"…"}
```

Sign-in is rate limited to 10 attempts every 3 minutes.

### Managing tokens

| Command | What it does |
|---|---|
| `make token LABEL=claude` | Mint a token and print it (unlabelled mints as `api`) |
| `make tokens` | List minted tokens and when they were created |
| `make revoke LABEL=claude` | Revoke every token with that label |
| `make reset-auth` | Revoke everything, tokens and browser sessions alike |

Each wraps `bin/rails auth:*` in the app's container; run
`docker compose run --rm web bin/rails auth:token` directly if you prefer.

Labels exist so an agent's access can be revoked without signing your browser out. Give every
agent its own label — everything sharing one label is revoked together, so
`make revoke LABEL=json-sign-in` ends every session minted through the JSON sign-in.
`DELETE /session.json` ends the current session too.

A bearer request is never handed a session cookie, and an unauthenticated JSON request
returns `401` rather than redirecting to the sign-in page.

## Resources

Requests and responses are JSON. Writes accept either flat attributes
(`{"title":"…"}`) or wrapped (`{"card":{"title":"…"}}`).

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

| Verb | Path | Notes |
|---|---|---|
| `GET` | `/cards.json` | Filterable — see below |
| `POST` | `/boards/:board_id/cards.json` | `title`, `description`, `due_on`. **`due_on` is required** |
| `GET` | `/cards/:number.json` | Includes `steps` |
| `PUT` | `/cards/:number.json` | `title`, `description`, `due_on` |
| `DELETE` | `/cards/:number.json` | |
| `PUT` | `/cards/:number/column.json` | `column_id` — moves the card between lanes, returns the moved card |
| `PUT` | `/cards/:number/board.json` | `board_id` — reparents the card, landing it in the destination's Triage |
| `POST` `DELETE` | `/cards/:number/goldness.json` | Pin and unpin |

A card is created published, in Triage, and every lane change from there records an event.
`due_on` is required on any published card, so a create without one is a `422`.

`GET /cards.json` accepts `board_ids[]`, `column_ids[]`, `card_ids[]`, `terms[]` (full-text),
`creation` (a time window), `indexed_by` (`all` or `golden`) and `sorted_by` (`latest`,
`newest` or `oldest`). Anything else is ignored rather than rejected — a misspelled filter
widens the result set instead of erroring, so check what you get back.

Cards report `closed` (in Done), `postponed` (in Backlog), `overdue`, `golden`, `due_on`,
and `color`.

### Notes and steps

| Verb | Path | Notes |
|---|---|---|
| `GET` `POST` | `/cards/:number/notes.json` | `body`. Published cards only |
| `GET` `PUT` `DELETE` | `/cards/:number/notes/:id.json` | Only the creator may edit or delete |
| `GET` `POST` | `/cards/:number/steps.json` | `content`, `completed` |
| `GET` `PUT` `DELETE` | `/cards/:number/steps/:id.json` | |

### Search

`GET /search.json?q=…` runs full-text search across every board and returns cards. A query
that is exactly a card number returns that card.

## Errors

Failures come back in one shape:

```json
{ "errors": { "due_on": ["can't be blank"] } }
```

| Status | When |
|---|---|
| `401` | No credential, or a token that has been revoked |
| `403` | The user is deactivated |
| `404` | No such record — including a `column_id` that isn't on the card's board |
| `422` | Validation failed; the keys name the fields |
| `429` | Sign-in rate limit |

## Pagination

Index endpoints return a bare JSON array and carry the paging in headers:

- `X-Total-Count` — how many records match in total
- `Link: <…?page=2>; rel="next"` — present only when there is a next page

Request later pages with `?page=N`. Both headers are set on JSON requests only.
