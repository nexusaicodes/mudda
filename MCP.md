# Mudda over MCP

Mudda serves the Model Context Protocol at `/mcp`. Its documentation lives at
**<https://docs.mudda.today/mcp/>**:

- [Connect a client](https://docs.mudda.today/mcp/connect/): OAuth, or a minted token
- [Tools](https://docs.mudda.today/mcp/): the catalogue, scopes, results and errors
- [OAuth](https://docs.mudda.today/mcp/oauth/): discovery, registration, PKCE, consent

The tool pages are generated from [docs/mcp-tools.json](docs/mcp-tools.json), written by
`bin/rails mcp:schema`. How the endpoint works inside the app is in
[AGENTS.md → MCP](AGENTS.md#mcp).
