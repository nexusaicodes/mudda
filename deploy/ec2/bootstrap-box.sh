#!/usr/bin/env bash
# Phase 2 — prepare the freshly provisioned box: install Docker, create the
# /srv/mudda data tree, open the host firewall, and install CI's deploy key.
# Everything here is idempotent (guarded by `command -v` / `mkdir -p` / an
# authorized_keys de-dup), so re-running is a no-op on an already-set-up box.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

main() {
  require_cmd ssh ssh-keygen
  load_config
  local ip; ip="$(state_get PUBLIC_IP)"
  [ -n "$ip" ] || die "no PUBLIC_IP in state — run provision.sh first"

  ensure_ci_deploy_key
  log "bootstrapping $SSH_USER@$ip"
  remote_setup "$ip"
  install_ci_key "$ip"
  ok "box ready"
  log "next: configure-github.sh"
}

# CI's own revocable keypair; the private half later becomes the SSH_DEPLOY_KEY secret.
ensure_ci_deploy_key() {
  if [ ! -f "$CI_DEPLOY_KEY" ]; then
    log "generating CI deploy key $CI_DEPLOY_KEY"
    ssh-keygen -t ed25519 -f "$CI_DEPLOY_KEY" -N "" -C "mudda-ci-deploy" >/dev/null
  fi
}

# accept-new is deliberate: this runs from the operator's laptop against a box
# they just provisioned, so trust-on-first-use is acceptable here. (CI is the
# opposite — it verifies against the pinned SSH_KNOWN_HOSTS set in Phase 3.)
ssh_box() { ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$SSH_USER@$1" "$2"; }

# Runs the one-time box setup from DEPLOY.md as a single idempotent remote script.
remote_setup() {
  ssh_box "$1" 'bash -euo pipefail -s' <<'REMOTE'
    if ! command -v docker >/dev/null 2>&1; then
      echo "==> installing Docker Engine + compose plugin"
      sudo apt-get update -qq
      sudo apt-get install -y -qq ca-certificates curl
      sudo install -m 0755 -d /etc/apt/keyrings
      sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
      sudo chmod a+r /etc/apt/keyrings/docker.asc
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
        https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt-get update -qq
      sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
      sudo usermod -aG docker "$USER"
    fi

    echo "==> data directories (owned by the deploy user, uid $(id -u))"
    sudo mkdir -p /srv/mudda/deploy /srv/mudda/storage /srv/mudda/caddy/data /srv/mudda/caddy/config
    sudo chown -R "$USER":"$USER" /srv/mudda

    echo "==> host firewall (defense in depth behind the AWS security group)"
    sudo ufw allow OpenSSH >/dev/null
    sudo ufw allow 80 >/dev/null
    sudo ufw allow 443 >/dev/null
    sudo ufw --force enable >/dev/null
    echo "==> box setup complete"
REMOTE
}

# Append CI's PUBLIC key to the box's authorized_keys, de-duplicated so re-runs
# don't stack copies. The key is streamed over stdin and read remotely with
# `cat`, so nothing is interpolated into the command string — no injection
# surface regardless of the key's contents.
install_ci_key() {
  ssh_box "$1" 'mkdir -p ~/.ssh && chmod 700 ~/.ssh &&
    touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys &&
    key="$(cat)" &&
    grep -qxF "$key" ~/.ssh/authorized_keys || printf "%s\n" "$key" >> ~/.ssh/authorized_keys' \
    < "${CI_DEPLOY_KEY}.pub"
  ok "CI deploy key installed"
}

main "$@"
