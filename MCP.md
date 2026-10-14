# Mudda over MCP

Mudda serves the [Model Context Protocol](https://modelcontextprotocol.io) at **`/mcp`**, so an
AI agent can read and work your boards with nothing to install. It is the [JSON API](API.md)
with a tool catalogue in front: every tool is one API call made with the agent's own token, so
what an agent may do and what it gets back are exactly what the API says. That includes the
token's [scopes](API.md#scopes), its [rate limit](API.md#rate-limit), attribution of its work
by label, and English answers.

## Connecting

**With OAuth, the one-click way.** Give the client your Mudda's MCP URL and nothing else:

```
https://your-mudda/mcp
```

In claude.ai or ChatGPT, add it as a custom connector. In Claude Code, run
`claude mcp add --transport http mudda https://your-mudda/mcp`, then `/mcp` to sign in. The
client discovers that Mudda issues its own tokens, registers itself, and opens Mudda in your
browser: sign in if you aren't, choose what it may do, and allow it. It then holds a token that
refreshes itself, and appears under the account menu → **API tokens** as a connected client,
where you can revoke it. See [OAuth](#oauth) for what happens underneath.

**With a token you mint.** For a client that can't do OAuth, or a script. Mint a token for the
agent (see [API.md → Managing tokens](API.md#managing-tokens)), giving each agent its own label:

```bash
make token LABEL=claude                              # reads and writes
make token LABEL=claude SCOPES="read write delete"   # may also delete
```

Then point the client at `/mcp` with the token as a bearer header. For Claude Code:

```bash
claude mcp add --transport http mudda https://your-mudda/mcp \
  --header "Authorization: Bearer $TOKEN"
```

Any client that speaks Streamable HTTP and can send a header works the same way. The token is
the only credential `/mcp` accepts; a browser's session cookie is not. A refusal is the API's
own: `401` for no token or a revoked or expired one, `403` for a deactivated user, and `429`
(with `Retry-After`) for a token over its rate limit.

## Tools

| Tool | API call |
|---|---|
| `whoami` | `GET /my/user` |
| `search_cards` | `GET /search?q=` |
| `list_boards` | `GET /boards` |
| `get_board` | `GET /boards/:id`, which includes the four columns and their ids |
| `create_board` | `POST /boards` |
| `rename_board` | `PUT /boards/:id` |
| `list_cards` | `GET /cards` or `GET /boards/:board_id/cards`, with the API's filters |
| `get_card` | `GET /boards/:board_id/cards/:number` |
| `create_card` | `POST /boards/:board_id/cards`. Lands in Backlog; `steps` is a list of strings |
| `update_card` | `PUT /boards/:board_id/cards/:number`: `title`, `description`, `due_on`, `golden`, `column_id`, `to_board_id` (sent as `board_id`), and `steps` (each `{ id?, content?, completed?, remove? }`) |
| `list_notes` | `GET /boards/:board_id/cards/:number/notes` |
| `add_note` | `POST /boards/:board_id/cards/:number/notes` |
| `update_note` | `PUT /boards/:board_id/cards/:number/notes/:id` |
| `delete_board` | `DELETE /boards/:id` |
| `delete_card` | `DELETE /boards/:board_id/cards/:number` |
| `delete_note` | `DELETE /boards/:board_id/cards/:number/notes/:id` |

**A client is offered only the tools its token's scopes allow.** Reading tools need `read`, the
create and update tools need `write`, and the three delete tools need `delete`. Calling a tool
that wasn't offered is a JSON-RPC error (unknown tool), and the API would refuse the call
anyway. Removing a step with `update_card` (`remove: true`) is a deletion, so it needs `delete`
too.

Each tool carries MCP annotations (`readOnlyHint`, `destructiveHint`, `idempotentHint`, and
`openWorldHint: false`), so a client can ask before running the destructive ones.
`update_card` is marked destructive and not idempotent, since it can remove steps and repeating
it adds its new steps again.

**Results.** A tool's result is the API's JSON response as text, or `Done.` when the API answers
with no body (a delete). A call the API refuses is a tool error (`isError`) whose text is the
API's error envelope plus the HTTP status, so an agent can tell a missing card (`404`) from a
bad field (`422`):

```json
{ "status": 422, "errors": { "due_on": ["can't be blank in Todo or Doing"] } }
```

Arguments are checked against the tool's schema before anything reaches the API. A call that
fails that check is also a tool error, but its text is the MCP library's plain message naming
the argument, with no envelope.

**Rate limit.** Every request to `/mcp` checks the credential, and that check is an API request
of its own. A tool call therefore spends two of the token's 600 requests a minute, and so does
every other MCP message (`initialize`, `tools/list`, `ping`). That allows at most 300 tool calls
a minute.

## OAuth

Mudda is its own OAuth 2.1 authorization server (Doorkeeper), following the MCP authorization
spec:

| Step | Endpoint | Standard |
|---|---|---|
| A `401` from `/mcp` carries `WWW-Authenticate: Bearer resource_metadata="…", scope="read write"` | `/mcp` | RFC 9728 |
| The client reads which server issues tokens for `/mcp`: this one | `GET /.well-known/oauth-protected-resource` (also with `/mcp` appended) | RFC 9728 |
| …and that server's endpoints and capabilities | `GET /.well-known/oauth-authorization-server` (also with a path appended) | RFC 8414 |
| It registers itself, getting a `client_id` | `POST /oauth/registrations` | RFC 7591 |
| It sends the user to consent, with a PKCE challenge | `GET /oauth/authorize` | OAuth 2.1, RFC 7636 |
| It redeems the code (valid 10 minutes) with the PKCE verifier | `POST /oauth/token` | OAuth 2.1 |
| It refreshes the hour-long access token as it expires | `POST /oauth/token` | OAuth 2.1 |
| It may revoke its own token | `POST /oauth/revoke` | RFC 7009 |

What is enforced:

- **PKCE with `S256`** on every authorization, confidential clients included (Doorkeeper's
  `force_pkce` alone would exempt them), and only the authorization-code and refresh-token
  grants.
- **Consent needs the signed-in browser.** A signed-out user is sent to sign in and brought
  back. A bearer token can't approve anything, so a read-only token can't grant itself more.
- **The user is always asked.** A client that already holds a token is still shown the consent
  screen, because consent also sets what its session may do.
- **The user chooses the scopes.** Every scope the client asked for is listed, ticked, with a
  checkbox, and only those left ticked are granted. Unticking all of them doesn't approve
  anything. Clients are pointed at `read write` by default, so only a client that wants to
  delete asks for `delete`, and the screen shows it as such. An unknown scope is refused.
- **The consent screen names where the client will be sent**, since anyone can register a
  client under any name.
- **Redirect URIs** must be `https`, `http` on a loopback host (`localhost`, `127.0.0.1`, `::1`)
  for native clients, or a private-use scheme in the `scheme://` form (`cursor://…`).
  Out-of-band URIs are refused.
- **A `resource` (RFC 8707) naming any other server is refused** at `/oauth/authorize`, so
  tokens from here only work here.
- Tokens and client secrets are stored hashed. Access tokens last an hour, and each refresh
  rotates the refresh token. A refresh token unused for 90 days (`Session::Oauth::IDLE_EXPIRY`)
  is refused, so a client that stopped being used has to ask the user again.
- Registration is open but grants nothing on its own, and is limited to 20 an hour per address.

**A connected client is a token session like any other** (`Session::Oauth`), labelled with the
client's name and carrying the scopes granted. There is one per client, held by a unique index.
Consenting under a name that another client's session already holds replaces that session, the
way minting replaces a token of the same label. Claude Code re-registers on each
`claude mcp add`, so that is how its old connection is dropped. A client's access tokens
resolve to its session.

Revoking it under API tokens, or with `make revoke LABEL=<its name>`, revokes its access and
refresh tokens, and consenting again brings it back. `make revoke` also revokes a minted token
that happens to share the name. `make reset-auth` ends every OAuth grant along with everything
else, but leaves client registrations in place, so a client only has to ask for consent again.

The issuer and every URL here come from the request's host and scheme. Behind a TLS-terminating
proxy, keep `ASSUME_SSL` on (production's default; see
[DOCKER.md → Production image](DOCKER.md#production-image)) so they read `https://`. Clients
refuse an issuer that doesn't match the URL they reached.

Browser-only clients that call the token endpoint directly from a page are not supported,
because there are no CORS headers. Server-side and native clients (claude.ai, ChatGPT, Claude
Code, Cursor) don't need them.

## How it works

`Mudda::Mcp::Endpoint` (`lib/mudda/mcp/`) is a Rack middleware mounted in front of
`ActionDispatch::Executor` by `config/initializers/mcp.rb`. It intercepts only the exact path
`/mcp`. On each request it:

1. Checks the credential by calling `GET /my/user.json` as the client, which runs the same
   `Authentication` as any API request (minted token or OAuth access token alike) and also
   reports the token's scopes. A `401` gains the `WWW-Authenticate` header that starts OAuth,
   and a `429` keeps its `Retry-After`.
2. Builds a stateless MCP server (name `mudda`, with instructions describing the lanes and card
   addressing) over the official `mcp` gem's Streamable HTTP transport, offering the tools those
   scopes allow (`Mudda::Mcp::Tools.granted`). It answers in plain JSON and keeps no sessions, so
   any process can answer any call. A `GET` for a server-sent event stream is refused.
3. Runs each tool call as an in-process request to the JSON API (`Mudda::Mcp::Api`). The request
   carries the client's `Authorization` header, host, and forwarding headers, but never its
   cookie.

It sits ahead of the executor because each tool call is a full request of its own, and a
request started inside a running executor would reset the outer request's state.

`lib/mudda` is required rather than autoloaded, so a change there needs a server restart
(`make restart`). Tests are in `test/integration/mcp_test.rb`, and for OAuth in
`test/integration/oauth_test.rb` and `test/models/session/oauth_test.rb`.
