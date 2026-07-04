# syntax=docker/dockerfile:1
# Production image for Mudda. Multi-stage: gems + assets are built in a throwaway
# stage, then only the runtime artifacts are copied into a slim final image that
# runs as a non-root user. Secrets are never baked in — they arrive at runtime via
# the env_file the deploy writes (see deploy/remote-deploy.sh).

ARG RUBY_VERSION=3.4.8
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

# Production runtime defaults. Bundler installs only the default gem group.
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test


# --- Build stage: compile gems and precompile assets ---
FROM base AS build

# build-essential/libyaml-dev/pkg-config/libssl-dev: compile native gems.
# git: install gems sourced from GitHub (rails edge, turbo, web-console).
# libvips: assets:precompile boots the app, which loads the vips initializer.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libssl-dev \
      libvips \
      libyaml-dev \
      pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Install gems first so editing source doesn't invalidate the bundle layer.
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy the app and precompile bootsnap + assets.
COPY . .
RUN bundle exec bootsnap precompile app/ lib/

# assets:precompile needs a secret_key_base but must not bake a real one in; the
# dummy value is used only for this build step (propshaft digests are unaffected).
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


# --- Final stage: slim runtime ---
FROM base

# curl: container healthcheck. libvips: Active Storage image variants.
# sqlite3: CLI for on-box backups of the SQLite database.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libvips \
      sqlite3 && \
    rm -rf /var/lib/apt/lists/*

# Copy the built gems and application from the build stage.
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run as an unprivileged user; own the writable dirs. /rails/storage is a bind
# mount at runtime, so the host directory must also be owned by uid 1000.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3006
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3006"]
