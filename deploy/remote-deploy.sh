#!/usr/bin/env bash
# Runs on the box, invoked by the deploy workflow over SSH once it has shipped the
# compose file, Caddyfile, and rendered .env into /srv/mudda. Pulls the freshly
# built (public) image from GHCR, prepares the database, and rolls the stack.
#
# Holds no secrets: every value lives in /srv/mudda/.env, which the workflow wrote
# over the encrypted SSH channel. The image is public, so no `docker login` is
# needed to pull it.
set -euo pipefail

ROOT=/srv/mudda
COMPOSE_FILE="$ROOT/docker-compose.prod.yml"

dc() { docker compose -f "$COMPOSE_FILE" --env-file "$ROOT/.env" "$@"; }

# compose reads the exact ${IMAGE} tag to run from the shipped .env.
dc pull
dc run --rm web ./bin/rails db:prepare
dc up -d

# Drop the images this release superseded.
docker image prune -f || true

# APP_HOST is not secret, so read just that line back for the summary.
echo "Deployed — https://$(sed -n 's/^APP_HOST=//p' "$ROOT/.env")"
