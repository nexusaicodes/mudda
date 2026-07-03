# Mudda

**Mudda** is a personal Kanban tool for tracking your own issues and ideas — boards, cards,
notes, and a simple fixed workflow (Triage → Backlog → Todo → Doing → Done) to move work
without ceremony.

Mudda is built and maintained by **Nexus AI**. It is a fork of
[Fizzy](https://fizzy.do/), originally created by [37signals](https://37signals.com).
We're grateful to 37signals for releasing Fizzy as open source; Mudda continues that work
under the same [O'Saasy License](LICENSE.md).

> **Heads up:** This is a trimmed standalone build — a single-tenant, single-person app on
> SQLite, run via Docker Compose. The SaaS engine, Kamal deploy tooling, MySQL, S3/object
> storage, cross-instance import/export, and all team-collaboration features (notifications,
> mentions, assignments, watching, reactions, board sharing, roles, and invites) have been
> removed.


## Running Mudda

Everything runs through Docker Compose. With Docker installed:

```bash
make setup    # build the image and start the app
```

Then open http://app.mudda.localhost:3006 and sign in with the owner credentials —
`MUDDA_OWNER_EMAIL` / `MUDDA_OWNER_PASSWORD` (dev defaults `saksham@nexusai.world` /
`mudda-dev-password`). You'll be asked to enroll a passkey; after that, passkey is the only
way in. See [DOCKER.md](DOCKER.md) for the full reference, and run `make` for all targets.


## Development

You are welcome — and encouraged — to modify Mudda to your liking. The Compose setup
([DOCKER.md](DOCKER.md)) bind-mounts your source for live reload.

For architecture and conventions, start with [AGENTS.md](AGENTS.md) (architecture) and
[STYLE.md](STYLE.md) (house style).


## Contributing

We welcome contributions! Please read the [style guide](STYLE.md) and
[CONTRIBUTING.md](CONTRIBUTING.md) before submitting code.


## License

Mudda is released under the [O'Saasy License](LICENSE.md). The license terms are inherited
from upstream Fizzy and apply to Mudda unchanged.
