# Running Mudda with Docker Compose (local development)

A single-container development setup: SQLite for the database and cable (no Redis,
MySQL, or object store needed). Background jobs run on Rails' in-process async
adapter; Solid Queue is configured but not the active dev adapter. Tuned for a
fresh box with no customer data.

> Local dev uses `Dockerfile.dev` plus `docker-compose.yml`, running
> `RAILS_ENV=development` with your source bind-mounted for live reload.

## Prerequisites

- Docker Engine + Compose v2 (`docker compose version`). On WSL, Docker Desktop's
  WSL integration or a native Docker install both work.

## Quick start

A `Makefile` wraps everything — run `make` to see all targets.

```bash
make setup
```

First boot builds the image, installs gems, creates the SQLite databases, loads
the schema, and seeds the development account. When it's up, open:

- http://app.mudda.localhost:3006  (preferred)
- http://localhost:3006            (fallback, also allowed)

Both `app.mudda.localhost` and `localhost` are in the dev host allowlist, and the
`*.localhost` TLD resolves to `127.0.0.1` automatically in modern browsers.

## The owner and logging in

Each deployment has exactly one owner, provisioned by `db/seeds.rb` from three env vars
(defaulted in `docker-compose.yml` for local dev):

| Variable               | Purpose                                  | Dev default          |
| ---------------------- | ---------------------------------------- | -------------------- |
| `MUDDA_OWNER_EMAIL`    | The owner identity's email               | `david@example.com`  |
| `MUDDA_OWNER_NAME`     | Display name                             | `David`              |
| `MUDDA_OWNER_PASSWORD` | Day-0 sign-in secret (never stored in DB) | `mudda-dev-password` |

**Before exposing the app, change these** — set a strong `MUDDA_OWNER_PASSWORD` (it is the only
credential guarding day-0 access) and reseed with `make seed`.

**Day 0** (no passkey yet): sign in with `MUDDA_OWNER_EMAIL` + `MUDDA_OWNER_PASSWORD`. You are then
required to enroll a passkey before you can use the app. **Once a passkey exists, password sign-in
is permanently disabled** (enforced in both the controller and a Rack middleware) and passkey is the
only way in. The password is verified at runtime against the env var with a constant-time compare;
there is no password column in the database.

Lost or broken passkeys? `make reset-auth` deletes all passkeys and sessions, returning the
deployment to day-0 password sign-in so you can enroll a fresh passkey.

## Everyday commands

```bash
make up           # start in the foreground (Ctrl-C to stop)
make start        # start in the background
make logs         # tail logs
make console      # Rails console
make shell        # bash shell in the container
make test         # run the unit tests
make lint         # RuboCop
make down         # stop, keep data
```

These are thin wrappers over `docker compose`; run `docker compose ...` directly
if you prefer.

## Start fresh (wipe all data)

State (SQLite DBs, uploads, logs, caches) lives in named volumes, so a full reset
is one target:

```bash
make fresh        # docker compose down -v && up --build -d
```

The host checkout is never written to for this state — only your source code is
bind-mounted in.

## Configuration

| Variable           | Default   | Purpose                                              |
| ------------------ | --------- | ---------------------------------------------------- |
| `PORT`             | `3006`    | Host port published for the web server.              |
| `RUBY_VERSION`     | `3.4.8`   | Build arg; keep in sync with `.ruby-version`.        |
| `DATABASE_ADAPTER` | `sqlite`  | Set in compose. `mysql` would need a DB service.     |

Override per-invocation, e.g. `PORT=4000 make up`, or drop a `.env` file next to
`docker-compose.yml` (it is gitignored).

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
- **`db/cable_schema.rb` shows as modified after first boot** — harmless. SQLite
  dev re-dumps that committed (MySQL-format) file; `git checkout -- db/cable_schema.rb`
  to discard.
