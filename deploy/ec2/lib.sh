#!/usr/bin/env bash
# Shared helpers for the deploy/ec2 scripts. Sourced, never executed directly.
#
# Design contract for every script that sources this:
#   - Idempotent: safe to re-run. Resources are looked up by tag/name and
#     created only when absent, so a half-finished run resumes cleanly.
#   - Ground-truth: a step is "done" only when a verifiable check passes
#     (an instance is running, an endpoint returns 200) — never because a
#     command merely exited 0.
#   - No secrets on disk: secrets flow straight into `gh secret set` or SSH;
#     only non-secret config lands in the state file.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$HERE/.state"          # non-secret discovered facts (gitignored)
CONFIG_FILE="${MUDDA_EC2_CONFIG:-$HERE/config.env}"

# ---- logging -------------------------------------------------------------
c_reset=$'\033[0m'; c_blue=$'\033[34m'; c_green=$'\033[32m'; c_yellow=$'\033[33m'; c_red=$'\033[31m'
log()  { printf '%s==>%s %s\n' "$c_blue"   "$c_reset" "$*" >&2; }
ok()   { printf '%s ok%s %s\n' "$c_green"  "$c_reset" "$*" >&2; }
warn() { printf '%swarn%s %s\n' "$c_yellow" "$c_reset" "$*" >&2; }
die()  { printf '%sfail%s %s\n' "$c_red"   "$c_reset" "$*" >&2; exit 1; }

# ---- preflight -----------------------------------------------------------
require_cmd() {
  for c in "$@"; do command -v "$c" >/dev/null 2>&1 || die "missing required command: $c"; done
}

# ---- config + state ------------------------------------------------------
# config.env holds non-secret parameters (region, instance type, repo, tag).
load_config() {
  [ -f "$CONFIG_FILE" ] || die "no config at $CONFIG_FILE — copy config.example.env and fill it in"
  # shellcheck disable=SC1090
  set -a; . "$CONFIG_FILE"; set +a
  : "${AWS_REGION:?set AWS_REGION in config.env}"
  : "${GH_REPO:?set GH_REPO (owner/repo) in config.env}"
  : "${TAG:=mudda-box}"
  : "${INSTANCE_TYPE:=t3.small}"
  : "${VOLUME_SIZE_GB:=20}"
  : "${SSH_USER:=ubuntu}"
  : "${SSH_KEY:=$HOME/.ssh/mudda_box}"          # admin key -> EC2 key pair
  : "${CI_DEPLOY_KEY:=$HOME/.ssh/mudda_deploy}" # CI's own key -> gh secret
  export AWS_REGION GH_REPO TAG INSTANCE_TYPE VOLUME_SIZE_GB SSH_USER SSH_KEY CI_DEPLOY_KEY
}

# Persist a discovered fact as KEY=value, replacing any prior line for KEY.
state_set() {
  local key="$1" val="$2"
  touch "$STATE_FILE"
  grep -v "^${key}=" "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null || true
  printf '%s=%s\n' "$key" "$val" >> "$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}
state_get() { [ -f "$STATE_FILE" ] && sed -n "s/^${1}=//p" "$STATE_FILE" | tail -1 || true; }

# ---- aws convenience -----------------------------------------------------
aws_() { aws --region "$AWS_REGION" --output text "$@"; }

# ---- ground-truth checks -------------------------------------------------
# Poll an HTTPS health endpoint until it returns 200 (or time out).
wait_for_http_200() {
  local url="$1" tries="${2:-40}" i
  for i in $(seq 1 "$tries"); do
    if curl -fsS -o /dev/null "$url" 2>/dev/null; then ok "200 <- $url"; return 0; fi
    printf '  waiting for %s (%d/%d)\n' "$url" "$i" "$tries" >&2; sleep 15
  done
  return 1
}
