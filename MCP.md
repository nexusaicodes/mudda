# Mudda over MCP

Mudda serves the [Model Context Protocol](https://modelcontextprotocol.io) at **`/mcp`**, so an
AI agent can read and work your boards with nothing to install. It is the [JSON API](API.md)
with a tool catalogue in front: every tool is one API call, made with the agent's own token,
so what an agent may do and what it gets back are exactly what the API says.

## Connecting

Mint a token for the agent under **My profile → API tokens**, or from a shell — give each
agent its own name, so what it does is attributed to it and it can be revoked on its own
(see API.md → Managing tokens):

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
the only credential `/mcp` accepts — a browser's session cookie is not — and a refusal is the
API's own: `401` with no token or a revoked or expired one, `403` for a deactivated user.

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
the API refuses an out-of-scope call regardless. Each tool carries MCP annotations
(`readOnlyHint`, `destructiveHint`, `idempotentHint`), so a client can ask before running the
destructive ones.

**What an agent does is attributed to it.** The token acts as the account's one user, and the
audit trail records the token's label as the event's `agent_name`.

Every tool call counts against the token's rate limit twice — once to check the credential,
once for the call — so a token's 600 requests a minute are 300 tool calls.

A tool's result is the API's JSON response as text. A failed call is a tool error (`isError`)
whose text is the API's error envelope plus the HTTP status, so an agent can tell a missing
card (`404`) from a bad field (`422`):

```json
{ "status": 422, "errors": { "due_on": ["can't be blank"] } }
```

Arguments are checked against each tool's schema first, so an unknown enum value never reaches
the API.

## How it works

`Mudda::Mcp::Endpoint` (`lib/mudda/mcp/`) is a Rack middleware mounted in front of
`ActionDispatch::Executor` by `config/initializers/mcp.rb`. On a request to `/mcp` it:

1. Checks the credential by calling `GET /my/user.json` as the client — the same
   `Authentication` concern as every API request decides it — which also reports the token's
   scopes.
2. Builds a stateless MCP server over the official `mcp` gem's Streamable HTTP transport, with
   the tools those scopes allow (`Mudda::Mcp::Tools.granted`). It answers in plain JSON and
   keeps no sessions, so any process can answer any call.
3. Runs each tool call as an in-process request to the JSON API (`Mudda::Mcp::Api`), carrying
   the client's `Authorization` header and host but never its cookie.

It sits ahead of the executor because each tool call is a full request of its own, and a
request started inside a running executor would reset the outer request's state.

`lib/mudda` is required rather than autoloaded, so a change there needs a server restart
(`make restart`). Tests are in `test/integration/mcp_test.rb`.
