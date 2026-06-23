# Mudda

**Mudda** is a Kanban tool for tracking issues and ideas — boards, cards, and a simple
fixed workflow (Triage → Backlog → Todo → Doing → Done) for teams that want to move work
without ceremony.

Mudda is built and maintained by **Nexus AI**. It is a fork of
[Fizzy](https://fizzy.do/), originally created by [37signals](https://37signals.com).
We're grateful to 37signals for releasing Fizzy as open source; Mudda continues that work
under the same [O'Saasy License](LICENSE.md).

> **Heads up:** This is a trimmed standalone build — a single-tenant app on SQLite, run via
> Docker Compose. The SaaS engine, Kamal deploy tooling, MySQL, S3/object storage, push
> notifications, and cross-instance import/export have been removed.


## Running Mudda

Everything runs through Docker Compose. With Docker installed:

```bash
make setup    # build the image and start the app
```

Then open http://app.mudda.localhost:3006 and log in as `david@example.com` (the magic link
is printed by `make logs`). See [DOCKER.md](DOCKER.md) for the full reference, and run `make`
for all targets.


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
