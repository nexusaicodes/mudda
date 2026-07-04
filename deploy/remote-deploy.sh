#!/usr/bin/env bash
# Runs on the EC2 box (invoked by the deploy workflow via SSM Run Command). Renders
# the runtime env file from base64-encoded values, pulls the freshly built image
# from GHCR, prepares the database, and brings the stack up.
#
# Expected environment (exported by the SSM command before this runs):
#   IMAGE                    ghcr.io/<owner>/<repo>:<sha>   (not secret)
#   APP_HOST                 <ip-dashes>.sslip.io           (not secret)
#   GHCR_USER                GitHub actor for docker login  (not secret)
#   GHCR_TOKEN_B64           base64 of a GHCR pull token
#   SECRET_KEY_BASE_B64      base64 of the Rails secret_key_base
#   MUDDA_OWNER_EMAIL_B64    base64 of the owner email
#   MUDDA_OWNER_NAME_B64     base64 of the owner display name
#   MUDDA_OWNER_PASSWORD_B64 base64 of the owner password
#
# Values are base64-encoded only to survive shell transport intact — not for
# secrecy. They pass through SSM command history; treat that as sensitive.
set -euo pipefail

ROOT=/srv/mudda
COMPOSE_FILE="$ROOT/docker-compose.prod.yml"

decode() { printf %s "$1" | base64 -d; }

# Render the runtime env file, readable only by its owner.
umask 077
cat > "$ROOT/.env" <<EOF
RAILS_ENV=production
IMAGE=${IMAGE}
APP_HOST=${APP_HOST}
BASE_URL=https://${APP_HOST}
ASSUME_SSL=true
FORCE_SSL=true
SECRET_KEY_BASE=$(decode "$SECRET_KEY_BASE_B64")
MUDDA_OWNER_EMAIL=$(decode "$MUDDA_OWNER_EMAIL_B64")
MUDDA_OWNER_NAME=$(decode "$MUDDA_OWNER_NAME_B64")
MUDDA_OWNER_PASSWORD=$(decode "$MUDDA_OWNER_PASSWORD_B64")
EOF

dc() { docker compose -f "$COMPOSE_FILE" --env-file "$ROOT/.env" "$@"; }

# Authenticate to GHCR, pull the image, migrate, and roll the stack.
decode "$GHCR_TOKEN_B64" | docker login ghcr.io -u "$GHCR_USER" --password-stdin

dc pull
dc run --rm web ./bin/rails db:prepare
dc up -d

# Don't leave credentials or dangling images on the box.
docker logout ghcr.io || true
docker image prune -f || true

echo "Deployed ${IMAGE} — https://${APP_HOST}"
