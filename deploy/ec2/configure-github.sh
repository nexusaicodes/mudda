#!/usr/bin/env bash
# Phase 3 — wire up the GitHub side of the pipeline: the `production`
# environment, the deploy secrets/variables it reads, and (best-effort) GHCR
# package visibility. Every gh secret/variable set is an upsert, so re-running
# just overwrites with the same values.
#
# Secrets are read from the environment when present (the agent passes them from
# its own prompt) and fall back to an interactive prompt. They are pushed
# straight to GitHub — nothing secret is written to disk here.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

main() {
  require_cmd gh ssh-keygen openssl base64
  load_config
  gh auth status >/dev/null 2>&1 || die "not logged in — run 'gh auth login'"

  local ip app_host; ip="$(state_get PUBLIC_IP)"; app_host="$(state_get APP_HOST)"
  [ -n "$ip" ] && [ -n "$app_host" ] || die "no state — run provision.sh first"

  ensure_environment
  set_variables "$ip" "$app_host"
  set_secrets
  make_package_public
  ok "GitHub configured for $GH_REPO"
  log "next: verify.sh  (triggers + watches the deploy)"
}

# Idempotent: PUT is create-or-update for an environment.
ensure_environment() {
  log "ensuring 'production' environment"
  gh api --method PUT "repos/$GH_REPO/environments/production" >/dev/null
}

set_variables() {
  local ip="$1" app_host="$2" known_hosts
  log "pinning box host key via ssh-keyscan"
  known_hosts="$(ssh-keyscan -t ed25519 "$ip" 2>/dev/null)" || die "ssh-keyscan failed for $ip"
  gh variable set SSH_HOST        --repo "$GH_REPO" --body "$ip"
  gh variable set SSH_USER        --repo "$GH_REPO" --body "$SSH_USER"
  gh variable set APP_HOST        --repo "$GH_REPO" --body "$app_host"
  gh variable set SSH_KNOWN_HOSTS --repo "$GH_REPO" --body "$known_hosts"
  ok "variables set (SSH_HOST, SSH_USER, APP_HOST, SSH_KNOWN_HOSTS)"
}

set_secrets() {
  local email name password ci_key
  email="${MUDDA_OWNER_EMAIL:-$(prompt 'Owner email')}"
  name="${MUDDA_OWNER_NAME:-$(prompt 'Owner display name')}"
  password="${MUDDA_OWNER_PASSWORD:-$(prompt_secret 'Owner password')}"
  ci_key="$(cat "$CI_DEPLOY_KEY")"

  log "setting deploy secrets (production environment)"
  # SECRET_KEY_BASE is generated once and left alone on re-runs: rotating it
  # would invalidate every signed cookie/session on the live app. Values can't
  # be read back, so a name-presence check is the most we can verify.
  if secret_exists SECRET_KEY_BASE; then
    log "SECRET_KEY_BASE already set — leaving it unchanged"
  else
    gh secret set SECRET_KEY_BASE --repo "$GH_REPO" --env production --body "$(openssl rand -hex 64)"
  fi
  gh secret set MUDDA_OWNER_EMAIL    --repo "$GH_REPO" --env production --body "$email"
  gh secret set MUDDA_OWNER_NAME     --repo "$GH_REPO" --env production --body "$name"
  gh secret set MUDDA_OWNER_PASSWORD --repo "$GH_REPO" --env production --body "$password"
  gh secret set SSH_DEPLOY_KEY       --repo "$GH_REPO" --env production --body "$ci_key"
  ok "secrets set"
}

secret_exists() {
  gh secret list --repo "$GH_REPO" --env production --json name --jq '.[].name' 2>/dev/null \
    | grep -qx "$1"
}

# The box pulls the image anonymously, so the GHCR package must be public. The
# package only exists after the first build, and GitHub has no first-class CLI
# for this, so it is best-effort: on failure we tell the user the one click.
make_package_public() {
  local pkg="${GH_REPO##*/}"
  if gh api --method PATCH "user/packages/container/$pkg/visibility" \
       -f visibility=public >/dev/null 2>&1; then
    ok "GHCR package '$pkg' is public"
  else
    warn "could not set GHCR visibility automatically (package may not exist until the first build)."
    warn "after the first deploy, flip it once: GitHub -> Packages -> $pkg -> Package settings -> Change visibility -> Public"
  fi
}

# ---- input helpers -------------------------------------------------------
prompt()        { local v; read -r -p "$1: " v </dev/tty; printf '%s' "$v"; }
prompt_secret() { local v; read -rs -p "$1: " v </dev/tty; echo >&2; printf '%s' "$v"; }

main "$@"
