# Mudda

**Mudda** declutters your tasks for the age you live in: boards, cards, notes, and a simple
fixed workflow (Backlog → Todo → Doing → Done) to move work without ceremony. It speaks
English and Arabic (right-to-left).

Mudda is built and maintained by **Nexus AI**, under the [O'Saasy License](LICENSE.md).

> **Heads up:** This is a standalone build — a single-tenant, single-person app on
> SQLite, run via Docker Compose. The SaaS engine, Kamal deploy tooling, MySQL, S3/object
> storage, cross-instance import/export, and all team-collaboration features (notifications,
> mentions, assignments, watching, reactions, board sharing, roles, and invites) have been
> removed.


## Running locally

Everything runs through Docker Compose. With Docker installed:

```bash
make setup    # build the image and start the app
```

Then open http://app.mudda.localhost:3006 and sign in with the owner credentials —
`MUDDA_OWNER_EMAIL` / `MUDDA_OWNER_PASSWORD` (dev defaults `saksham@nexusai.world` /
`mudda-dev-password`). You can optionally enroll a passkey for biometric/device sign-in, but the
password always works. See [DOCKER.md](DOCKER.md) for the full reference, and run `make` for all targets.


## Production image

Mudda is a single-container app (SQLite + local-disk uploads + in-process jobs). Every push to
`main` builds the production image and pushes it to GHCR (`ghcr.io/<owner>/<repo>:latest`, plus
a tag per commit). There is no deploy pipeline: pull the image, run `bin/rails db:prepare` before
each new image boots (it applies that image's migrations), mount `/rails/storage`, and pass the env vars listed in
[DOCKER.md](DOCKER.md) → Production image.


## Development

You are welcome — and encouraged — to modify Mudda to your liking. The Compose setup
([DOCKER.md](DOCKER.md)) bind-mounts your source for live reload.

For architecture and conventions, start with [AGENTS.md](AGENTS.md) (architecture) and
[STYLE.md](STYLE.md) (house style).


## Contributing

We welcome contributions! Please read the [style guide](STYLE.md) and
[CONTRIBUTING.md](CONTRIBUTING.md) before submitting code.


## License

Mudda is released under the [O'Saasy License](LICENSE.md).
