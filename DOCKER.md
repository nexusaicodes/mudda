# Running Mudda with Docker Compose (local development)

A single-container development setup: SQLite for the database (no Redis, MySQL, or
object store needed). Background jobs run in-process on Rails' `:async` Active Job
adapter. Tuned for a fresh box with no customer data.

> Local dev builds the `dev` target of the `Dockerfile` (one multi-stage file
> shared with production) via `docker-compose.yml`, running `RAILS_ENV=development`
> with your source bind-mounted for live reload.

## Prerequisites

- Docker Engine + Compose v2 (`docker compose version`). On WSL, Docker Desktop's
  WSL integration or a native Docker install both work.

## Quick start

A `Makefile` wraps everything — run `make` to see all targets.

```bash
make setup
```

First boot builds the image, then — as an explicit step *before* the app starts —
runs `db:prepare` (creates the SQLite databases, loads the schema, runs migrations,
and seeds the development account), then brings the container up. Production works
the same way (the host runs `db:prepare` before booting; see Production image below),
so dev and prod share **one** container entrypoint that only clears a stale Puma
pidfile — neither migrates on boot. When it's up, open:

- http://app.mudda.localhost:3006  (preferred)
- http://localhost:3006            (fallback, also allowed)

Both `app.mudda.localhost` and `localhost` are in the dev host allowlist, and the
`*.localhost` TLD resolves to `127.0.0.1` automatically in modern browsers.

## The owner and logging in

Each deployment has exactly one owner, provisioned by `db/seeds.rb` from three env vars
(defaulted in `docker-compose.yml` for local dev):

| Variable               | Purpose                                  | Dev default          |
| ---------------------- | ---------------------------------------- | -------------------- |
| `MUDDA_OWNER_EMAIL`    | The owner's email address                | `saksham@nexusai.world` |
| `MUDDA_OWNER_NAME`     | Display name                             | `Saksham Saxena`     |
| `MUDDA_OWNER_PASSWORD` | Owner sign-in secret (never stored in DB) | `mudda-dev-password` |

**Before exposing the app, change these** — set a strong `MUDDA_OWNER_PASSWORD` (it is the standing
credential guarding access) and reseed with `make seed`.

Sign in with `MUDDA_OWNER_EMAIL` + `MUDDA_OWNER_PASSWORD`. This password is the standing sign-in
method — it stays available whenever the secret is set. Enrolling a passkey (under `my/passkeys`) is
optional: a convenience for biometric or device sign-in that never disables password login. The
password is verified at runtime against the env var with a constant-time compare; there is no
password column in the database.

Two optional variables cap how many cards the account may create, for a deployment that sells
more (a self-hoster leaves both unset):

| Variable            | Purpose                                                                 |
| ------------------- | ----------------------------------------------------------------------- |
| `MUDDA_CARD_LIMIT`  | Cards the account may ever create; deleting one doesn't free its slot. Unset, blank, or not a whole number: no limit |
| `MUDDA_UPGRADE_URL` | Where the upgrade links (near the limit, in Account Settings, and in the Settings menu) and `/account/upgrade` (after sign-in) send the owner |

Lost or broken passkeys? `make reset-auth` removes all passkeys and signs out every session; sign
back in with your password.

Driving the app from a script or agent? `make token LABEL=claude` mints an API token
(`SCOPES="read write delete"` to let it delete), `make tokens` lists them, and
`make revoke LABEL=claude` revokes one — or do all three from **My profile → API tokens**.
See [API.md](API.md), and [MCP.md](MCP.md) for AI agents.

## Everyday commands

```bash
make up           # start in the foreground (Ctrl-C to stop)
make start        # start in the background
make logs         # tail logs
make console      # Rails console
make shell        # bash shell in the container
make test         # run the unit tests
make test-system  # run the system tests (starts, then removes, the selenium service)
make lint         # RuboCop
make down         # stop, keep data
```

These are thin wrappers over `docker compose`; run `docker compose ...` directly
if you prefer.

## Start fresh (wipe all data)

State (SQLite DBs, uploads, logs, caches) lives in named volumes, so a full reset
is one target:

```bash
make fresh        # down -v, rebuild, db:prepare, then up -d
```

The host checkout is never written to for this state — only your source code is
bind-mounted in.

## Configuration

| Variable           | Default   | Purpose                                              |
| ------------------ | --------- | ---------------------------------------------------- |
| `PORT`             | `3006`    | Host port published for the web server.              |
| `RUBY_VERSION`     | `3.4.8`   | Build arg; keep in sync with `.ruby-version`.        |

Override per-invocation, e.g. `PORT=4000 make up`, or drop a `.env` file next to
`docker-compose.yml` (it is gitignored).

## Production image

The `Dockerfile`'s `production` target is the deployable image. `.github/workflows/build.yml`
builds it on every push to `main` and pushes it to `ghcr.io/<owner>/<repo>`, tagged with the
commit SHA and `latest`. A manual dispatch on any other branch pushes only the SHA tag, so
`latest` always tracks `main`. Nothing deploys it; a host pulls the image and runs it.

To run it:

1. **Prepare the database first.** Run `bin/rails db:prepare` in a one-off container before the
   server boots. This creates the SQLite databases, migrates, and seeds the owner. The entrypoint
   never migrates.
2. **Mount `/rails/storage`** on a persistent volume. It holds `production.sqlite3` and every
   upload. Keep it off network filesystems (NFS/EFS), where SQLite's locking is unreliable.
3. **Pass the runtime env.** Nothing secret is baked into the image.

| Variable                   | Purpose                                                              |
| -------------------------- | -------------------------------------------------------------------- |
| `RAILS_ENV`                | `production`                                                         |
| `SECRET_KEY_BASE`          | Rails secret; any long random string, stable across restarts.        |
| `MUDDA_OWNER_EMAIL`        | The owner's sign-in email; seeded by `db:prepare`.                   |
| `MUDDA_OWNER_NAME`         | The owner's display name.                                            |
| `MUDDA_OWNER_PASSWORD`     | The standing owner password.                                         |
| `MUDDA_OWNER_PASSWORD_B64` | Alternative to the above, base64-encoded so any character survives an env file; the entrypoint decodes it. |
| `BASE_URL`                 | Public URL (`https://mudda.example.com`) for links built outside a request. |
| `ASSUME_SSL` / `FORCE_SSL` | Both default to `true`: secure cookies and HSTS behind a TLS-terminating proxy that sends `X-Forwarded-Proto: https`. `DISABLE_SSL=true` turns both off. |
| `MUDDA_CARD_LIMIT`         | Optional ceiling on cards ever created (see AGENTS.md → Account).    |
| `MUDDA_UPGRADE_URL`        | Optional; where "upgrade" links send the owner under a ceiling.      |

Passkeys need the app served over HTTPS at a real hostname. Password sign-in works either way.

## After changing the Gemfile

Gems are baked into the image, so rebuild to pick up dependency changes:

```bash
make build
make start
```

## Troubleshooting

- **`app.mudda.localhost` won't resolve** — use http://localhost:3006, or add
  `127.0.0.1 app.mudda.localhost` to your hosts file.
- **Port already in use** — start with `PORT=4000 make up`.
- **Stuck/odd state** — `make fresh`.
