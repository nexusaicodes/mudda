# Mudda over MCP

Mudda serves the [Model Context Protocol](https://modelcontextprotocol.io) at **`/mcp`**, so an
AI agent can read and work your boards with nothing to install. It is the [JSON API](API.md)
with a tool catalogue in front: every tool is one API call, made with the agent's own token,
so what an agent may do and what it gets back are exactly what the API says.

## Connecting

**With OAuth — the one-click way.** Give the client your Mudda's MCP URL and nothing else:

```
https://your-mudda/mcp
```

In claude.ai or ChatGPT, add it as a custom connector; in Claude Code,
`claude mcp add --transport http mudda https://your-mudda/mcp` and then `/mcp` to sign in. The
client discovers that Mudda issues its own tokens, registers itself, and opens Mudda in your
browser: sign in if you aren't, choose what it may do, and allow it. It then holds a token that
refreshes itself, listed under **My profile → API tokens** as a connected client, where you can
revoke it. See [OAuth](#oauth) for what happens underneath.

**With a token you mint.** For a client that can't do OAuth, or a script. Mint a token for the agent under **My profile → API tokens**, or from a shell — give each
agent its own name, so what it does is attributed to it and it can be revoked on its own
(see API.md → Managing tokens):

```bash
make token LABEL=claude                              # reads and writes
make token LABEL=claude SCOPES="read write delete"   # may also delete
```

Then point the client at `/mcp` with the token as a bearer header — for Claude Code:

```bash
claude mcp add --transport http mudda https://your-mudda/mcp \
  --header "Authorization: Bearer $TOKEN"
```

Any client that speaks Streamable HTTP and can send a header works the same way. The token is
the only credential `/mcp` accepts — a browser's session cookie is not — and a refusal is the
API's own: `401` with no token or a revoked or expired one, `403` for a deactivated user, `429`
(with `Retry-After`) for a token over its rate limit.

## Tools

| Tool | API call |
|---|---|
| `whoami` | `GET /my/user` |
| `search_cards` | `GET /search?q=` |
| `list_boards` | `GET /boards` |
| `get_board` | `GET /boards/:id` — includes the five columns and their ids |
| `create_board` | `POST /boards` |
| `rename_board` | `PUT /boards/:id` |
| `list_cards` | `GET /cards` or `GET /boards/:board_id/cards`, with the API's filters |
| `get_card` | `GET /boards/:board_id/cards/:number` |
| `create_card` | `POST /boards/:board_id/cards` — `due_on` required, `steps` as a list of strings |
| `update_card` | `PUT /boards/:board_id/cards/:number` — lane, board (`to_board_id`), golden, steps |
| `list_notes` | `GET /boards/:board_id/cards/:number/notes` |
| `add_note` | `POST /boards/:board_id/cards/:number/notes` |
| `update_note` | `PUT /boards/:board_id/cards/:number/notes/:id` |
| `delete_board` | `DELETE /boards/:id` |
| `delete_card` | `DELETE /boards/:board_id/cards/:number` |
| `delete_note` | `DELETE /boards/:board_id/cards/:number/notes/:id` |

Cards are addressed by board id and per-board `number`, as in the API.

**A client is offered only the tools its token's scopes allow** (API.md → Scopes): reading
tools need `read`, the create and update tools `write`, and the three delete tools `delete` —
which a token holds only when it was asked for. A tool that isn't offered can't be called, and
the API refuses an out-of-scope call regardless. Removing a step with `update_card` is a
deletion, so it too needs `delete`. Each tool carries MCP annotations (`readOnlyHint`,
`destructiveHint`, `idempotentHint`), so a client can ask before running the destructive ones;
`update_card` is marked destructive and not idempotent, since it can remove steps and repeating
it adds its new steps again.

**What an agent does is attributed to it.** The token acts as the account's one user, and the
audit trail records the token's label as the event's `agent_name`.

Every tool call counts against the token's rate limit twice — once to check the credential,
once for the call — so a token's 600 requests a minute are 300 tool calls.

A tool's result is the API's JSON response as text. A failed call is a tool error (`isError`)
whose text is the API's error envelope plus the HTTP status, so an agent can tell a missing
card (`404`) from a bad field (`422`):

```json
{ "status": 422, "errors": { "due_on": ["can't be blank"] } }
{ "status": 422, "errors": { "base": ["This account has used all 100 of its cards"] } }
```

Arguments are checked against each tool's schema first, so an unknown enum value never reaches
the API.

## OAuth

Mudda is its own OAuth 2.1 authorization server (Doorkeeper), following the MCP authorization
spec:

| Step | Endpoint | Standard |
|---|---|---|
| A `401` from `/mcp` carries `WWW-Authenticate: Bearer resource_metadata="…", scope="read write"` | `/mcp` | RFC 9728 |
| The client reads which server issues tokens for `/mcp` — this one | `GET /.well-known/oauth-protected-resource` (also with `/mcp` appended) | RFC 9728 |
| …and that server's endpoints and capabilities | `GET /.well-known/oauth-authorization-server` | RFC 8414 |
| It registers itself, getting a `client_id` | `POST /oauth/registrations` | RFC 7591 |
| It sends the user to consent, with a PKCE challenge | `GET /oauth/authorize` | OAuth 2.1, RFC 7636 |
| It redeems the code with the PKCE verifier | `POST /oauth/token` | OAuth 2.1 |
| It refreshes the hour-long access token as it expires | `POST /oauth/token` | OAuth 2.1 |
| It may revoke its own token | `POST /oauth/revoke` | RFC 7009 |

What is enforced:

- **PKCE with `S256`** on every authorization — confidential clients included, which
  Doorkeeper's `force_pkce` alone would exempt — and only the authorization-code and
  refresh-token grants.
- **Consent needs the signed-in browser.** A signed-out user is sent to sign in and brought
  back; a bearer token can't approve anything, so a read-only token can't grant itself more.
- **The user is always asked.** A client that already holds a token is still shown the consent
  screen, because consent also sets what its session may do.
- **The user chooses the scopes.** Every scope the client asked for is listed with a checkbox;
  only the ticked ones are granted. Clients are pointed at `read write` by default, so deleting
  is asked for only by a client that wants it, and shown as such.
- **The consent screen names where the client will be sent**, since anyone can register a
  client under any name.
- **Redirect URIs** must be `https`, `http` on a loopback host (`localhost`, `127.0.0.1`, `::1`)
  for native clients, or a private-use scheme (`cursor://…`). Out-of-band URIs are refused.
- **A `resource` (RFC 8707) naming any other server is refused** — tokens from here only work
  here.
- Tokens and client secrets are stored hashed. Access tokens last an hour; each refresh rotates
  the refresh token. A refresh token unused for 90 days (`Session::Oauth::IDLE_EXPIRY`) is
  refused, so a client that stopped being used has to ask the user again.
- Registration is open but grants nothing on its own, and is limited to 20 an hour per address.

**A connected client is a token session like any other** (`Session::Oauth`): labelled with
the client's name, carrying the scopes granted, one per client (a unique index holds it). A
client that registers again under the same name — Claude Code does on each `claude mcp add` —
replaces the session its earlier registration held, the way minting replaces a token of the
same label. Its access tokens resolve to
that session, so scopes, the rate limit, and agent attribution (`agent_name` = the client's
name) apply unchanged. Revoking it under API tokens — or `make revoke LABEL=<its name>` —
revokes its access and refresh tokens; consenting again brings it back. `make reset-auth` ends
every OAuth grant along with everything else.

The issuer and every URL here come from the request's host and scheme. Behind a TLS-terminating
proxy, keep `ASSUME_SSL` on — production's default, see [DEPLOY.md](DEPLOY.md) → TLS — so they
read `https://`; clients refuse an issuer that doesn't match the URL they reached.

Browser-only clients that call the token endpoint directly from a page are not supported —
there are no CORS headers. Server-side and native clients (claude.ai, ChatGPT, Claude Code,
Cursor) don't need them.

## How it works

`Mudda::Mcp::Endpoint` (`lib/mudda/mcp/`) is a Rack middleware mounted in front of
`ActionDispatch::Executor` by `config/initializers/mcp.rb`. On a request to `/mcp` it:

1. Checks the credential by calling `GET /my/user.json` as the client — the same
   `Authentication` concern as every API request decides it, minted token or OAuth access
   token alike — which also reports the token's scopes. Any token may make this call, whatever
   its scopes. A `401` gains the `WWW-Authenticate` header that starts OAuth; a `429` keeps its
   `Retry-After`.
2. Builds a stateless MCP server over the official `mcp` gem's Streamable HTTP transport, with
   the tools those scopes allow (`Mudda::Mcp::Tools.granted`). It answers in plain JSON and
   keeps no sessions, so any process can answer any call.
3. Runs each tool call as an in-process request to the JSON API (`Mudda::Mcp::Api`), carrying
   the client's `Authorization` header and host but never its cookie.

It sits ahead of the executor because each tool call is a full request of its own, and a
request started inside a running executor would reset the outer request's state.

`lib/mudda` is required rather than autoloaded, so a change there needs a server restart
(`make restart`). Tests are in `test/integration/mcp_test.rb` and, for OAuth,
`test/integration/oauth_test.rb`.
