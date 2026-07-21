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


## Running locally

Everything runs through Docker Compose. With Docker installed:

```bash
make setup    # build the image and start the app
```

Then open http://app.mudda.localhost:3006 and sign in with the owner credentials —
`MUDDA_OWNER_EMAIL` / `MUDDA_OWNER_PASSWORD` (dev defaults `saksham@nexusai.world` /
`mudda-dev-password`). You can optionally enroll a passkey for biometric/device sign-in, but the
password always works. See [DOCKER.md](DOCKER.md) for the full reference, and run `make` for all targets.


## Deploying to your own server

Mudda is a single-box app (SQLite + local-disk uploads + in-process jobs): one small VPS,
the app behind Caddy for automatic HTTPS, and a GitHub Actions pipeline that builds the image
and deploys over SSH on every push to `main`. No DNS is needed — the box is reached at
`https://<public-ip-with-dashes>.sslip.io`, and Caddy provisions a real Let's Encrypt cert for
that name (which is also what makes passkeys work). [DEPLOY.md](DEPLOY.md) is the full reference.

### The easy path: let Claude Code do it (AWS EC2)

If you use [Claude Code](https://claude.com/claude-code), this repo ships a **`deploy-ec2`
skill** that plans and executes a zero-to-live deployment to your own EC2 box, pausing for your
approval before anything is created. Prerequisites: your **own fork** of this repo, the
[`gh`](https://cli.github.com) and [`aws`](https://aws.amazon.com/cli/) CLIs installed and
authenticated (`gh auth login`, `aws configure`).

```
cp deploy/ec2/config.example.env deploy/ec2/config.env   # then fill in your fork + region
```

Then run the skill from Claude Code:

```
/deploy-ec2
```

The `/deploy-ec2` slash command invokes the skill directly, so it's the reliable trigger. Saying
something like *"deploy to EC2"* in plain language usually works too, but that depends on Claude
choosing the skill — use the slash command when you want to be sure.

It runs a read-only preflight, collects your owner email/name/password (pushed straight to
GitHub secrets — never written to disk), shows you a plan to approve, then provisions the
instance + Elastic IP + firewall, bootstraps Docker on the box, configures the GitHub pipeline,
and verifies the app is live at `https://<ip>.sslip.io`. Every step is idempotent, so if
anything fails you can re-run it. `deploy/ec2/teardown.sh` reverses all AWS resources.

### The manual path

Run the same scripts yourself, in order (each is safe to re-run):

```bash
cp deploy/ec2/config.example.env deploy/ec2/config.env   # fork, region, instance type
bash deploy/ec2/provision.sh          # EC2 instance + security group + stable Elastic IP
bash deploy/ec2/bootstrap-box.sh      # Docker + /srv/mudda + firewall + CI deploy key (over SSH)
bash deploy/ec2/configure-github.sh   # production env + secrets + variables (via gh)
bash deploy/ec2/verify.sh             # trigger the deploy, watch it, confirm https://.../up is 200
```

Deploying to a non-AWS box, or wiring the GitHub Environment by hand, is covered step by step in
[DEPLOY.md](DEPLOY.md).


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
