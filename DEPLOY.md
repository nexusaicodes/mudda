# Deploying Mudda to EC2

Mudda deploys to a **single EC2 instance** running Docker. It is a single-box app by
design (SQLite + local-disk uploads + in-process jobs), so there is no load balancer,
no container orchestrator, and no external datastore.

```
  push to main ─► GitHub Actions ─► build image ─► GHCR
                        │
                        └─ OIDC ─► AWS ─► SSM Run Command ─► EC2 box
                                                              ├─ docker compose (web + caddy)
                                                              ├─ Caddy: auto-HTTPS for <ip>.sslip.io
                                                              └─ /srv/mudda/storage on EBS (SQLite + uploads)
```

No DNS is required: the box is reached at **`https://<public-ip-with-dashes>.sslip.io`**
(e.g. `54-1-2-3.sslip.io`), and Caddy provisions a real Let's Encrypt certificate for
that name. That HTTPS name is also what makes **passkeys** work — WebAuthn needs a real
host over TLS, so on a bare IP you'd be password-only.

## Pipeline at a glance

`.github/workflows/deploy.yml` runs two jobs on push to `main` (or manual dispatch):

1. **build** — builds the `Dockerfile`'s `production` target, pushes `ghcr.io/<owner>/<repo>:<sha>` (and `:latest`)
   to GHCR using the automatic `GITHUB_TOKEN`.
2. **deploy** — assumes an AWS role via GitHub OIDC (no static AWS keys), then uses
   **SSM Run Command** to run `deploy/remote-deploy.sh` on the instance. That script
   renders `/srv/mudda/.env`, logs in and pulls the image from GHCR, runs `db:prepare`,
   and `docker compose up -d`. The job waits for the SSM command to report `Success`.

The `deploy` job targets the **`production` GitHub Environment** — add required reviewers
to it if you want a manual approval gate before anything ships.

## One-time box setup

The AWS infrastructure (EC2 instance, IAM instance profile, EBS volume, security group,
OIDC role) is assumed to already exist. On the box, ensure:

- **Docker + Compose plugin** installed and running; the **SSM agent** installed and the
  instance registered as a managed node (`AmazonSSMManagedInstanceCore` on the instance
  role).
- **Data volume**: the dedicated EBS volume formatted (ext4) and mounted at
  `/srv/mudda/storage` via `/etc/fstab` (mount by UUID). This directory holds
  `production.sqlite3` **and** all uploads — it is the entire persistent state.
- **Directories + ownership** (the deploy also does this, but seed it once):
  ```bash
  sudo mkdir -p /srv/mudda/deploy /srv/mudda/storage /srv/mudda/caddy/{data,config}
  sudo chown -R 1000:1000 /srv/mudda/storage   # container runs as uid 1000
  ```
- **Security group**: inbound **80 and 443** open to the internet (Let's Encrypt's
  HTTP-01/TLS-ALPN validation comes from outside). **Port 22 can stay closed** — all
  administration is via SSM, so there is no SSH key to manage.

## GitHub configuration

Create a **`production` Environment** in the repo and set the following. `GITHUB_TOKEN`
is provided automatically — you do not create it.

**Secrets** (Environment scope):

| Secret | What |
|---|---|
| `AWS_ROLE_ARN` | IAM role the deploy job assumes via OIDC |
| `SECRET_KEY_BASE` | Rails secret; generate once with `bin/rails secret` |
| `MUDDA_OWNER_EMAIL` | Owner login email |
| `MUDDA_OWNER_NAME` | Owner display name |
| `MUDDA_OWNER_PASSWORD` | Owner sign-in password (strong; this is the standing credential) |

**Variables** (Environment or repo scope):

| Variable | Example |
|---|---|
| `AWS_REGION` | `ap-south-1` |
| `EC2_INSTANCE_ID` | `i-0abc123...` |
| `APP_HOST` | `54-1-2-3.sslip.io` (your public IP, dashes for dots) |

(For Let's Encrypt expiry notices, add a global `{ email you@example.com }` block to
`deploy/Caddyfile` — optional.)

The IAM role in `AWS_ROLE_ARN` needs a trust policy for this repo's OIDC and permissions
for `ssm:SendCommand` (on the instance + the `AWS-RunShellScript` document) and
`ssm:GetCommandInvocation`.

## Secrets handling

Application secrets live in **GitHub Actions secrets** and are injected at **deploy
time** (never baked into the image). The deploy job base64-encodes them and passes them
through the SSM `send-command`, which writes a root-only `/srv/mudda/.env` on the box.

> **Caveat:** values passed to `send-command` are recorded in **SSM command history and
> CloudTrail**. That is an accepted tradeoff of sourcing secrets from GitHub rather than
> from SSM Parameter Store / Secrets Manager. Rotate by updating the GitHub secret and
> redeploying. To eliminate the CloudTrail exposure later, move the values into SSM
> Parameter Store (SecureString) and have `remote-deploy.sh` fetch them on the box.

## TLS / passkeys

Caddy terminates TLS and forwards `X-Forwarded-Proto: https`, so the app keeps
`ASSUME_SSL=true` + `FORCE_SSL=true` (secure cookies + HSTS, no redirect loop). Because
`APP_HOST` is a real name over HTTPS, WebAuthn passkeys work; password sign-in works too.
The Caddy `/data` volume persists issued certs so redeploys don't re-request them (and
don't hit Let's Encrypt rate limits).

## Data & backups

All state is `/srv/mudda/storage` on EBS. Recommended:

- **EBS snapshots** via Data Lifecycle Manager (daily) — crash-consistent; SQLite (WAL)
  recovers cleanly on restore.
- **Consistent DB copy** via a nightly cron for belt-and-suspenders:
  ```bash
  docker compose -f /srv/mudda/docker-compose.prod.yml --env-file /srv/mudda/.env \
    exec -T web sqlite3 storage/production.sqlite3 ".backup 'storage/backup.sqlite3'"
  ```

Never move the SQLite database to EFS/NFS — its file locking is unreliable there.

## Rollback

Re-run the workflow (or `workflow_dispatch`) pointing at an older commit — the image is
tagged per commit SHA in GHCR, so checking out a previous SHA and deploying pulls that
exact image. On the box you can also roll back by hand by setting `IMAGE` in
`/srv/mudda/.env` to a previous `ghcr.io/<owner>/<repo>:<sha>` and running
`docker compose ... up -d`.
