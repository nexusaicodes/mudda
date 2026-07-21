# Deploying Mudda

Mudda deploys to a **single VPS box** running Docker. It is a single-box app by design
(SQLite + local-disk uploads + in-process jobs), so there is no load balancer, no container
orchestrator, and no external datastore.

```
  push to main ─► GitHub Actions ─► build image ─► GHCR (public)
                        │
                        └─ SSH ─► the box
                                    ├─ copy over SSH: compose file, Caddyfile, rendered .env
                                    ├─ remote-deploy.sh: docker compose up -d (web + caddy)
                                    ├─ Caddy: auto-HTTPS for <ip>.sslip.io
                                    └─ /srv/mudda/storage on the host disk (SQLite + uploads)
```

No DNS is required: the box is reached at **`https://<public-ip-with-dashes>.sslip.io`**
(e.g. `54-1-2-3.sslip.io`), and Caddy provisions a real Let's Encrypt certificate for that
name. That HTTPS name is also what makes **passkeys** work — WebAuthn needs a real host over
TLS, so on a bare IP you'd be password-only.

## Pipeline at a glance

`.github/workflows/deploy.yml` runs two jobs on push to `main` (or manual dispatch):

1. **build** — builds the `Dockerfile`'s `production` target, pushes `ghcr.io/<owner>/<repo>:<sha>`
   (and `:latest`) to GHCR using the automatic `GITHUB_TOKEN`.
2. **deploy** — renders the runtime `.env` in the runner, then over **SSH** copies
   `docker-compose.prod.yml`, `deploy/Caddyfile`, `deploy/remote-deploy.sh`, and the `.env`
   to `/srv/mudda` and runs `remote-deploy.sh`. That script pulls the image, runs `db:prepare`,
   and `docker compose up -d`. The job fails if any SSH step returns non-zero.

   Files are streamed over the SSH **exec channel** (`ssh host 'cat > dest'`), not `scp`,
   because this box has the SFTP subsystem disabled — `scp`/`sftp` would fail with
   "Connection closed" while plain `ssh <command>` works.

The `deploy` job targets the **`production` GitHub Environment** — add required reviewers to it
if you want a manual approval gate before anything ships.

## Automated zero-to-live on AWS EC2 (`deploy/ec2/`)

The manual box setup below is scripted end-to-end for AWS in `deploy/ec2/`, meant to be driven
by an agentic CLI (Claude Code) via the **`deploy-ec2` skill**, or run by hand. The scripts are
idempotent (resources are found by the `mudda-box` tag and created only when absent), so any
phase is safe to re-run:

| Script | Does |
|---|---|
| `provision.sh` | Launches the EC2 instance, security group (22/80/443), and a **stable Elastic IP**, then derives `APP_HOST` (`<ip-dashed>.sslip.io`). Needs the AWS CLI + credentials. |
| `bootstrap-box.sh` | Over SSH: installs Docker, creates `/srv/mudda`, opens `ufw`, and installs CI's deploy key. |
| `configure-github.sh` | Via `gh`: creates the `production` environment and sets all deploy secrets + variables (and best-effort GHCR-public). |
| `verify.sh` | Triggers the deploy workflow, watches it, and gates on a real `200` from `https://APP_HOST/up`. |
| `teardown.sh` | Reverses every AWS resource (tag-guarded, requires confirmation). |

Setup: `cp deploy/ec2/config.example.env deploy/ec2/config.env`, fill it in (your fork, region,
instance type), then run the scripts in the order above — or just tell Claude Code to "deploy to
EC2" and let the skill plan, gate on your approval, and run them. Owner email/name/password are
gathered at run time and pushed straight to GitHub secrets; nothing secret is written to disk.
The EC2 Ubuntu default user is `ubuntu` (uid 1000), which matches the container, so the storage
ownership just works — no `saksham` user needed for this path. `config.env` and the discovered
`.state` are gitignored.

## One-time box setup

Ubuntu 24.04, a non-root **`saksham`** user with `sudo`, key-only SSH (see the box-hardening
notes). Run these once on the box.

### 1. Docker Engine + Compose plugin

```bash
# Docker's official repo (Ubuntu 24.04).
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Let the deploy user run docker without sudo. Log out and back in for it to take effect.
sudo usermod -aG docker saksham
```

### 2. Data directory owned by the deploy user

```bash
sudo mkdir -p /srv/mudda/deploy /srv/mudda/storage /srv/mudda/caddy/data /srv/mudda/caddy/config
sudo chown -R saksham:saksham /srv/mudda
```

`saksham` owning `/srv/mudda` is what lets the deploy run **without sudo** — CI just `scp`s and
`docker compose`s as `saksham`. The container runs as uid **1000**, and the first user on the box
(`saksham`) is also uid 1000, so it can read/write `/srv/mudda/storage` directly with no `chown`
dance. Confirm with `id -u saksham` (expect `1000`); if it prints something else, run
`sudo chown -R 1000:1000 /srv/mudda/storage` so the container can write its data.

### 3. Firewall

```bash
sudo ufw allow OpenSSH     # 22 — SSH deploy + your admin access
sudo ufw allow 80          # Let's Encrypt HTTP-01 challenge + redirect to HTTPS
sudo ufw allow 443         # the app
sudo ufw enable
```

### 4. A dedicated deploy key

Give CI its own key (revocable independently of your personal login key):

```bash
# On your laptop:
ssh-keygen -t ed25519 -f mudda_deploy -N "" -C "mudda-ci-deploy"

# Append the PUBLIC key to the deploy user on the box:
ssh-copy-id -i mudda_deploy.pub saksham@<box-ip>
#   ...or paste mudda_deploy.pub into /home/saksham/.ssh/authorized_keys by hand.
```

The **private** key (`mudda_deploy`) goes into the GitHub secret `SSH_DEPLOY_KEY` (below). Delete
your local copies once it's stored.

### 5. Pin the box's host key

So CI verifies the box instead of trusting it blind on first connect:

```bash
ssh-keyscan -t ed25519 <box-ip>
```

Put that output into the GitHub variable `SSH_KNOWN_HOSTS`.

## GitHub configuration

Create a **`production` Environment** in the repo and set the following. `GITHUB_TOKEN` is
provided automatically — you do not create it.

**Secrets** (Environment scope):

| Secret | What |
|---|---|
| `SSH_DEPLOY_KEY` | Private half of the dedicated deploy keypair (PEM/OpenSSH format) |
| `SECRET_KEY_BASE` | Rails secret; generate once with `bin/rails secret` |
| `MUDDA_OWNER_EMAIL` | Owner login email |
| `MUDDA_OWNER_NAME` | Owner display name |
| `MUDDA_OWNER_PASSWORD` | Owner sign-in password (strong; this is the standing credential) |

**Variables** (Environment or repo scope):

| Variable | Example |
|---|---|
| `SSH_HOST` | `203.0.113.5` (the box's IP or hostname for SSH) |
| `SSH_USER` | `saksham` |
| `SSH_KNOWN_HOSTS` | output of `ssh-keyscan -t ed25519 <box-ip>` |
| `APP_HOST` | `203-0-113-5.sslip.io` (your public IP, dashes for dots) |

(For Let's Encrypt expiry notices, add a global `{ email you@example.com }` block to
`deploy/Caddyfile` — optional.)

## Public image

The GHCR package is **public**, so the box pulls it anonymously — no registry login on the box,
no pull token to manage. Make it public once, under the repo's **Packages → mudda → Package
settings → Change visibility → Public**. The image contains only your application source and
gems — no secrets, no database, no `.env` (all of those arrive at runtime; see below). If you'd
rather keep the image private, re-add a `docker login ghcr.io` step to `remote-deploy.sh` with a
read-only PAT stored on the box.

## Secrets handling

Application secrets live in **GitHub Actions secrets** and are injected at **deploy time** (never
baked into the image). The deploy job renders them into an `env.production` file in the runner,
streams it over the encrypted SSH channel into a `0600` `/srv/mudda/.env` on the box, and
`docker compose` reads it via `env_file`. Values never appear on a command line or in the image.

The owner password is stored base64-encoded (`MUDDA_OWNER_PASSWORD_B64`) so arbitrary characters
(`$`, `#`, quotes) survive `docker compose`'s env-file parsing intact; the container entrypoint
(`bin/docker-entrypoint`) decodes it back into `MUDDA_OWNER_PASSWORD` at boot. Set the
`MUDDA_OWNER_PASSWORD` GitHub secret to the raw password — the pipeline handles the encoding.

Rotate by updating the GitHub secret and redeploying. The rendered `.env` on the box is owned by
`saksham` and mode `0600`.

## TLS / passkeys

Caddy terminates TLS and forwards `X-Forwarded-Proto: https`, so the app keeps `ASSUME_SSL=true` +
`FORCE_SSL=true` (secure cookies + HSTS, no redirect loop). Because `APP_HOST` is a real name over
HTTPS, WebAuthn passkeys work; password sign-in works too. The Caddy `/data` volume persists issued
certs so redeploys don't re-request them (and don't hit Let's Encrypt rate limits).

## Data & backups

All state is `/srv/mudda/storage` on the host disk — `production.sqlite3` **and** all uploads.
Recommended:

- **Provider volume snapshots** (daily) if your host offers them — crash-consistent; SQLite (WAL)
  recovers cleanly on restore.
- **Consistent DB copy** via a nightly cron for belt-and-suspenders:
  ```bash
  docker compose -f /srv/mudda/docker-compose.prod.yml --env-file /srv/mudda/.env \
    exec -T web sqlite3 storage/production.sqlite3 ".backup 'storage/backup.sqlite3'"
  ```

Never move the SQLite database to a network filesystem (NFS/EFS) — its file locking is unreliable
there.

## Rollback

Re-run the workflow (or `workflow_dispatch`) pointing at an older commit — the image is tagged per
commit SHA in GHCR, so checking out a previous SHA and deploying pulls that exact image. On the box
you can also roll back by hand: set `IMAGE` in `/srv/mudda/.env` to a previous
`ghcr.io/<owner>/<repo>:<sha>` and run
`docker compose -f /srv/mudda/docker-compose.prod.yml --env-file /srv/mudda/.env up -d`.
