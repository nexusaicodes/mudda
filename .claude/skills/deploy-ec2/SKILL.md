---
name: deploy-ec2
description: Plan and execute a zero-to-live deployment of Mudda to the user's own AWS EC2 box, with explicit permission gates. Use when the user asks to "deploy to EC2", "get this running on AWS", "set up my own instance", or stand up a fresh box from a clone.
---

# Deploy Mudda to the user's EC2 (agent-orchestrated)

You drive `deploy/ec2/*.sh` — deterministic, idempotent primitives — and handle
only what an LLM is reliable at: gathering inputs, sequencing, verifying against
ground truth, and choosing a recovery branch when a check fails. **Do not
hand-write `aws`/`gh` commands to replace a script step**; the scripts hold the
exact syntax so re-runs are safe. You fill the gaps between them.

## Operating principles (why this is reliable)

1. **Idempotent primitives.** Every script finds resources by tag/name and
   creates only when absent. A half-finished run resumes — never start over.
2. **Ground truth, not optimism.** A phase is done only when its verifiable
   check passes (instance `status-ok`, workflow success, `200` from `/up`).
   Believe the check, not the fact that a command exited 0.
3. **Permission gates.** Present the plan and get approval before the first
   mutating command; let each mutating call go through its normal prompt.
4. **Inputs up front.** Collect everything in one pass so you never guess
   mid-run.
5. **Cheap rollback.** `teardown.sh` exists; mention it before provisioning so
   the user knows a failed attempt is reversible.

## Step 0 — Preflight (read-only, no gate needed)

Verify the local toolchain and credentials, then report a green/red list:
- `command -v aws gh ssh ssh-keygen curl openssl` — all present.
- `aws sts get-caller-identity` — AWS creds work; note the account id + region.
- `gh auth status` — GitHub logged in.
- Confirm `GH_REPO` is the **user's own fork** (the pipeline builds to
  `ghcr.io/<owner>/<repo>`; it cannot deploy someone else's repo).

If anything is red, stop and tell the user the exact fix (`aws configure`,
`gh auth login`, fork the repo). Do not proceed.

## Step 1 — Intake (one pass, via AskUserQuestion)

Collect and confirm, writing the non-secret answers to `deploy/ec2/config.env`
(copy from `config.example.env`):
- `GH_REPO`, `AWS_REGION`, `INSTANCE_TYPE` (default `t3.small`), `VOLUME_SIZE_GB`.
- Owner **email**, **display name**, **password** — secrets. Pass these to
  `configure-github.sh` as env vars (`MUDDA_OWNER_EMAIL` etc.) in the same
  command; **never** echo the password back, log it, or write it to a file.

## Step 2 — Plan and get approval (the gate)

Present a concise plan the user approves ONCE before anything mutates:
- Resources to create: 1 EC2 `$INSTANCE_TYPE` instance, 1 Elastic IP, 1 security
  group (22/80/443), 2 SSH keypairs (admin + CI), 5 GitHub secrets, 4 variables.
- Rough cost (e.g. t3.small ≈ a few USD/mo + EIP while attached).
- Reversible via `teardown.sh`.
Use plan mode (ExitPlanMode) so approval is explicit. Proceed only on approval.

## Step 3 — Execute the phases (verify after each)

Run in order; after each, restate the ground-truth result before continuing.

| Phase | Script | Done when |
|---|---|---|
| Provision | `bash deploy/ec2/provision.sh` | prints `APP_HOST`, instance is `status-ok` |
| Bootstrap | `bash deploy/ec2/bootstrap-box.sh` | prints `box ready` (Docker + `/srv/mudda` + firewall + CI key) |
| Configure GitHub | `bash deploy/ec2/configure-github.sh` | 5 secrets + 4 variables set |
| Deploy + verify | `bash deploy/ec2/verify.sh` | workflow succeeds AND `https://APP_HOST/up` returns `200` |

State lives in `deploy/ec2/.state` (gitignored). If a phase fails, read its
stderr, apply the matching recovery below, and re-run that same phase — it
resumes.

## Recovery branches (the known gotchas)

- **`verify.sh` workflow fails at the pull step** → GHCR package is still
  private. It only exists after the first build, and there is no first-class CLI
  to flip it. Tell the user the one click (Packages → the package → Change
  visibility → Public), then re-run `verify.sh`. `configure-github.sh` also
  retries this automatically.
- **`/up` never returns 200 but the workflow passed** → usually Caddy still
  issuing the Let's Encrypt cert (wait — `verify.sh` already polls ~10 min), or
  port 443 closed. Confirm the security group opened 443; check
  `docker compose ... logs` on the box.
- **SSH fails in bootstrap/keyscan** → instance still booting, or the admin key
  pair wasn't imported. Re-run `provision.sh` (idempotent) then retry.
- **IP changed / passkeys broke after a stop-start** → the Elastic IP wasn't
  associated. Re-run `provision.sh`; it re-associates and APP_HOST stays stable.

## Success report

State the live URL (`https://APP_HOST`), that sign-in is the owner email +
password, that passkeys can be enrolled under `my/passkeys`, and that
`teardown.sh` removes the AWS resources. Remind them the box's data lives in
`/srv/mudda/storage` and to set up snapshots (see DEPLOY.md → Data & backups).
```
result: deployed — https://<APP_HOST>
```
