# Mudda

**Mudda** declutters your tasks for the age you live in: boards, cards, notes, and a simple
fixed workflow (Backlog → Todo → Doing → Done) to move work without ceremony. It is a
single-person app, built to be driven as much by AI agents, over its JSON API and MCP, as by you
in the browser. It speaks English and Arabic (right-to-left).

## Running it

With Docker installed:

```bash
make setup
```

Then open http://app.mudda.localhost:3006 and sign in as the owner (see
[DOCKER.md → The owner and signing in](DOCKER.md#the-owner-and-signing-in)).

## Documentation

| Doc | For |
|---|---|
| [DOCKER.md](DOCKER.md) | Running Mudda locally and in production: commands, the owner, env vars |
| [docs.mudda.today](https://docs.mudda.today) | Driving Mudda from a script or agent over JSON, and connecting an AI agent over MCP |
| [AGENTS.md](AGENTS.md) | The architecture, for anyone changing the code |
| [ERD.md](ERD.md) | The database schema |
| [STYLE.md](STYLE.md) | House style |

You are welcome, and encouraged, to modify Mudda to your liking.

## License

Mudda is built and maintained by **Nexus AI**, and released under the
[O'Saasy License](LICENSE.md).
