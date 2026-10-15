# Running Mudda

Mudda runs as a single container: SQLite for the database, uploads on local disk, and background
jobs in-process. There is no Redis, MySQL, or object store. Local development and production
share one multi-stage `Dockerfile`: development builds its `dev` target through
`docker-compose.yml`, and production runs its `production` target.

## Local development

You need Docker Engine with Compose v2 (`docker compose version`). On WSL, Docker Desktop's WSL
integration and a native Docker install both work.

```bash
make setup
```

This builds the image, runs `db:prepare` as an explicit step before the app starts (creating the
SQLite database, loading the schema, and seeding the owner), and brings the container up with
your source bind-mounted for live reload. The container's entrypoint only clears a stale Puma
pidfile; neither development nor production migrates on boot. Then open:

- http://app.mudda.localhost:3006 (preferred; `*.localhost` resolves to `127.0.0.1` in modern
  browsers)
- http://localhost:3006

### The owner and signing in

Each deployment has exactly one owner, provisioned by `db/seeds.rb` from these variables. The
seed runs once, when `db:prepare` creates the database:

| Variable | Purpose | Dev default |
|---|---|---|
| `MUDDA_OWNER_EMAIL` | The owner's email address. Required outside development | `saksham@nexusai.world` |
| `MUDDA_OWNER_NAME` | Display name. Defaults to the email's local part, capitalized | `Saksham Saxena` |
| `MUDDA_OWNER_LOCALE` | The owner's starting language, `en` or `ar`, applied once when the owner is first created; after that it's changed on the profile. Unset: the browser's language | `ar` |
| `MUDDA_OWNER_PASSWORD` | The sign-in password, checked against this variable on every sign-in and never stored | `mudda-dev-password` |

Sign in with `MUDDA_OWNER_EMAIL` and `MUDDA_OWNER_PASSWORD`. The password always works.
Enrolling a passkey (under `my/passkeys`) is an optional convenience for biometric or device
sign-in.

**Before exposing the app, set a strong `MUDDA_OWNER_PASSWORD`.** It takes effect when the
container is recreated (`make start`); there is nothing to reseed. Set `MUDDA_OWNER_EMAIL` before
the first `make setup`: the owner is found by email, so changing it later leaves no owner under
the new address, and reseeding then provisions a second account rather than renaming the first.

Lost or broken passkeys? `make reset-auth` removes them all and ends every session; sign back in
with the password. Driving the app from a script or agent? See [API.md](API.md) and
[MCP.md](MCP.md).

### Hosting platform sync

A hosting platform (Mudda Cloud) keeps the board in step with its own records: it names the
board's plan (`Account::CardLimited::PLANS`: free is 100 cards, premium has no limit), tells it
where to send its webhooks, and renames the owner; the board reports renames back. All of that
travels in signed messages and is kept in the database. The one variable is the trust anchor:

| Variable | Purpose |
|---|---|
| `MUDDA_PLATFORM_KEYS` | Ed25519 public keys the board trusts for messages to `POST /platform/messages`, as `kid:base64,kid:base64` (the current key and the next while rotating). Set: the board is hosted, and on the free plan until told otherwise. Unset (self-hosting): no plan, no card limit, no messages, no webhooks |

The message format and its checks are in `app/models/platform/message.rb`, and the webhook's in
`app/models/webhook_delivery.rb`. Message audiences are matched against `BASE_URL`'s host.

### Commands

A `Makefile` wraps `docker compose`; run `make` to list every target. Targets marked * run
inside the running app (`docker compose exec`), so start it first. The rest run in a throwaway
container.

| Target | What it does |
|---|---|
| `make setup` | Build the image, prepare the database, and start the app (first run) |
| `make up` | Start in the foreground (Ctrl-C to stop) |
| `make start` | Start in the background, recreating the container if its env changed |
| `make restart` | Restart the web service, keeping its env (needed after changing `lib/mudda`) |
| `make down` | Stop, keeping data |
| `make build` | Rebuild the image. Gems are baked in, so run it (then `make start`) after changing the `Gemfile` |
| `make fresh` | Wipe all data, rebuild, prepare the database, and start |
| `make logs` / `make ps` | Tail the server log / show container status |
| `make console`* / `make shell`* | A Rails console / a bash shell in the container |
| `make prepare` | Create, migrate, and seed the database |
| `make migrate`* | Run pending migrations |
| `make seed`* | Run `db/seeds.rb` (idempotent) |
| `make reset-db`* | Drop, recreate, and reseed the database |
| `make reset-auth` | Remove every passkey and end every session, API token, and OAuth grant |
| `make token` / `make tokens` / `make revoke` | Mint, list, and revoke API tokens (see [API.md → Managing tokens](API.md#managing-tokens)) |
| `make test` | The unit and integration tests |
| `make test-system` | The system tests, in a `selenium` Chromium container that it starts and then removes |
| `make lint` | RuboCop and the translation checks |
| `make lint-fix` | RuboCop with autocorrect |
| `make i18n` | The translation checks alone |

State (the SQLite database, uploads, logs, and caches) lives in named volumes, so no runtime
state lands in the host checkout, and `make fresh` (`down -v`, then a rebuild) is a complete reset.

### Configuration

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `3006` | Host port published for the web server |

Override it, `MUDDA_OWNER_EMAIL`, `MUDDA_OWNER_NAME`, `MUDDA_OWNER_LOCALE`, and `MUDDA_OWNER_PASSWORD` per invocation
(`PORT=4000 make up`) or in a `.env` file next to `docker-compose.yml` (it is gitignored). The Ruby version is fixed in
`docker-compose.yml`; see [AGENTS.md → Toolchain](AGENTS.md#toolchain).

### Troubleshooting

- **`app.mudda.localhost` won't resolve**: use http://localhost:3006, or add
  `127.0.0.1 app.mudda.localhost` to your hosts file.
- **"Blocked host"**: development accepts only the hosts listed in `config.hosts` in
  `config/environments/development.rb` (the two above, `mudda.localhost`, `127.0.0.1`, and
  `*.ts.net` and `*.nip.io` names). Add yours there.
- **Port already in use**: start with `PORT=4000 make up`.
- **Stuck or odd state**: `make fresh`.

## Production image

The `Dockerfile`'s `production` target is the deployable image. `.github/workflows/build.yml`
builds it on every push to `main` and pushes it to `ghcr.io/<owner>/<repo>`, tagged with the
commit SHA and `latest`. A manual dispatch on another branch pushes only the SHA tag, so `latest`
always tracks `main`. Nothing deploys it; a host pulls the image and runs it.

The container runs as uid/gid 1000, listens on port 3006, and answers `/up` for health checks.
To run it:

1. **Prepare the database first.** Run `bin/rails db:prepare` in a one-off container, with the
   same env as the server, before each new image boots. It creates the database and seeds the
   owner the first time, and applies the image's migrations every time. The seed aborts without
   `MUDDA_OWNER_EMAIL` and a password.
2. **Mount `/rails/storage`** on a persistent volume, owned by uid 1000 if it is a host
   directory. It holds `production.sqlite3` and every upload. Keep it off network filesystems
   (NFS, EFS), where SQLite's locking is unreliable. The image includes the `sqlite3` CLI for
   backups.
3. **Pass the runtime env.** Nothing secret is baked into the image.

| Variable | Purpose |
|---|---|
| `SECRET_KEY_BASE` | Required. Any long random string, stable across restarts |
| `MUDDA_OWNER_EMAIL`, `MUDDA_OWNER_NAME`, `MUDDA_OWNER_LOCALE` | The owner, as above |
| `MUDDA_OWNER_PASSWORD` | Required. The owner's password |
| `MUDDA_OWNER_PASSWORD_B64` | An alternative to the above, base64-encoded so any character survives an env file. The entrypoint decodes it when `MUDDA_OWNER_PASSWORD` is empty |
| `BASE_URL` | The public URL (`https://mudda.example.com`), for links built outside a request |
| `ASSUME_SSL` / `FORCE_SSL` | Both default to `true`, for a TLS-terminating proxy that sends `X-Forwarded-Proto: https`: secure cookies, HSTS, and HTTP redirected to HTTPS. `DISABLE_SSL=true` turns off both, unless either is set explicitly |
| `MUDDA_PLATFORM_KEYS` | Optional; see [Hosting platform sync](#hosting-platform-sync) |
| `RAILS_LOG_LEVEL` | Defaults to `info` |
| `CSP_*`, `DISABLE_CSP` | Extra Content-Security-Policy sources per directive (`CSP_IMG_SRC`, `CSP_CONNECT_SRC`, …); see `config/initializers/content_security_policy.rb` |

Passkeys need the app served over HTTPS at a real hostname. Password sign-in works either way.
