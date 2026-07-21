#!/usr/bin/env bash
# Phase 4 — trigger the deploy workflow, watch it to completion, then confirm
# the app is actually serving over HTTPS. The run "succeeding" is not enough:
# the gate is a real 200 from https://APP_HOST/up with a valid certificate.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

main() {
  require_cmd gh curl
  load_config
  local app_host; app_host="$(state_get APP_HOST)"
  [ -n "$app_host" ] || die "no APP_HOST in state — run provision.sh first"

  trigger_and_watch
  verify_live "$app_host"
}

trigger_and_watch() {
  # Record the newest run id before dispatch, then wait for a *different* id to
  # appear — so we never watch (and trust) a stale, already-finished run.
  local before run_id i
  before="$(latest_run_id)"
  log "dispatching deploy.yml on $GH_REPO"
  gh workflow run deploy.yml --repo "$GH_REPO" >/dev/null
  log "waiting for the new run to register"
  for i in $(seq 1 20); do
    run_id="$(latest_run_id)"
    [ -n "$run_id" ] && [ "$run_id" != "$before" ] && break
    sleep 3
  done
  [ -n "$run_id" ] && [ "$run_id" != "$before" ] \
    || die "new deploy run did not appear — check: gh run list --repo $GH_REPO --workflow deploy.yml"
  log "watching run $run_id"
  gh run watch "$run_id" --repo "$GH_REPO" --exit-status \
    || die "deploy workflow failed — inspect: gh run view $run_id --repo $GH_REPO --log-failed"
  ok "workflow succeeded"
}

latest_run_id() {
  gh run list --repo "$GH_REPO" --workflow deploy.yml --limit 1 \
    --json databaseId --jq '.[0].databaseId // ""' 2>/dev/null || true
}

# Ground truth: the health endpoint returns 200 over a valid TLS cert. Caddy can
# take a minute to obtain the Let's Encrypt cert on first boot, so we poll.
verify_live() {
  local app_host="$1"
  log "verifying https://$app_host/up (Caddy may still be issuing the cert)"
  if wait_for_http_200 "https://$app_host/up" 40; then
    ok "LIVE — https://$app_host"
    log "sign in with the owner email + password you configured."
  else
    die "app did not answer 200 at https://$app_host/up — check: \
ssh into the box and run 'docker compose -f /srv/mudda/docker-compose.prod.yml --env-file /srv/mudda/.env logs'"
  fi
}

main "$@"
