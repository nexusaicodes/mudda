# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

The authoritative architecture and conventions live in two files you should treat as primary:

- **[AGENTS.md](AGENTS.md)** — what Mudda is, dev/test commands, and the big-picture architecture (URL-based multi-tenancy, passwordless auth + passkeys, core domain models, the fixed-column card lifecycle, due dates, UUIDv7 keys, Solid Queue jobs, adapter-dependent full-text search, imports/exports).
- **[STYLE.md](STYLE.md)** — house style (conditional returns over guard clauses, method/invocation ordering, bang conventions, CRUD-only controllers, vanilla Rails, `_later`/`_now` job naming).

## Fork & branding

Mudda is maintained by **Nexus AI** and is a fork of **Fizzy**, originally created by
**37signals**. The product, the module namespace (`Mudda`), and the SaaS gem (`mudda-saas`)
are all branded Mudda. The original O'Saasy License is inherited unchanged and still applies.

A few **upstream hosting values were intentionally left as-is** because they point at
37signals/Basecamp infrastructure that a Nexus AI deployment must supply itself. Change these
before running your own hosted instance:

- **Deploy hosts** in `saas/config/deploy*.yml` and `saas/.kamal/hooks/pre-connect`
  (`*-int.37signals.com` FQDNs), and `bin/notify_dash_of_deployment` (`dash.37signals.com`).
- **Container/proxy images** (`basecamp/kamal-proxy`) in the deploy configs.
- **Storage/CSP** host `storage.basecamp.com` in `saas/config/environments/production.rb`.
- **Dev infra clone** of `basecamp/docker-dev` in `saas/bin/setup`.
- **Onboarding media** in `app/models/account/seeder.rb` (videos/GIFs at
  `videos.37signals.com/...`) — rehost under Nexus AI and update the URLs.
- **Placeholders the fork introduced**: the `https://nexus.ai` link (colophon),
  `support@mudda.do` (welcome letter + gemspec email), the `mudda.do` domain, and the
  `nexus-ai/mudda` GitHub org. Confirm or replace with real values.
- **Kept on purpose:** the `:bc` git_source (`github.com/basecamp/...`) in both Gemfiles
  resolves real forked upstream gems — do **not** repoint it. The `Integration::Basecamp` /
  `for_basecamp?` webhook code is a genuine Basecamp integration **feature**, not branding.

Everything below covers the OSS/SaaS dual-mode split, the single most non-obvious thing about
working in this repo.

## OSS vs SaaS dual mode

Mudda ships as open source, with a private Rails engine layered on top to run the hosted product at mudda.do. The repo carries both at once:

- **Two Gemfiles.** `Gemfile` is the OSS baseline. `Gemfile.saas` does `eval_gemfile "Gemfile"` then adds SaaS-only gems (the `mudda-saas` engine at `saas/`, Stripe via `queenbee`, telemetry via `yabeda`/`sentry`/`rails_structured_logging`, `console1984`/`audits1984`, native push). Both have their own lockfile.
- **Selecting a mode at runtime.** `bin/rails saas:enable` switches the app into SaaS mode; `bin/rails saas:disable` returns to OSS. `saas:enable` is also the required pre-deploy step. Most commands implicitly use the OSS `Gemfile`; to operate in SaaS mode set `BUNDLE_GEMFILE=Gemfile.saas` (e.g. `BUNDLE_GEMFILE=Gemfile.saas bundle ...`).
- **The `saas/` directory is a self-contained gem** (`mudda-saas.gemspec`) with its own `app/`, `config/`, `db/`, `test/`, `lib/`, and `exe/`. It is a Rails engine, not part of the main app tree. After changing it, repoint the main app at the new code with `BUNDLE_GEMFILE=Gemfile.saas bundle update --conservative mudda-saas`. See `saas/README.md`.
- **Touching shared behavior?** Consider whether a change belongs in OSS (`app/`) or SaaS (`saas/app/`), and whether both modes still work. Setup honors a `SAAS` env var (`bin/setup` sources `saas/bin/setup` when set).

### Keeping the two lockfiles in sync

- `bin/bundle-both <args>` runs the same `bundle` command against **both** Gemfiles (e.g. `bin/bundle-both update rails`). Use it for any dependency change so OSS and SaaS lockfiles don't drift.
- `bin/bundle-drift` checks for drift between the two.
- `bin/bundler-audit` / `bin/gitleaks-audit` / `bin/brakeman` are the wrapped security tools that CI runs.

### Stripe (SaaS billing) local dev

The Stripe integration needs a tunnel. After `stripe login`, run in the *same* shell session:

```sh
eval "$(BUNDLE_GEMFILE=Gemfile.saas bundle exec stripe-dev)"
bin/dev
```

## CI

`bin/ci` is not a shell script — it boots Rails and runs `config/ci.rb` via `ActiveSupport::ContinuousIntegration`. That file is the source of truth for the pipeline stages (Rubocop, bundler-audit, importmap audit, Brakeman, app tests, system tests). Edit `config/ci.rb` to change CI, not a YAML workflow.

## Toolchain

- Ruby is pinned in `.ruby-version` (3.4.x); `.mise.toml` enables mise's idiomatic Ruby version file support, so `mise` will pick it up automatically.
- Rails runs off `main` (edge) plus a couple of forked/branch gems (see `Gemfile`) — expect APIs slightly ahead of the latest stable Rails release.
- Style is `rubocop-rails-omakase` with a thin house override in `.rubocop.yml` (negated-if/unless enabled; `db/migrate`, schemas, and the SaaS equivalents excluded). Run via `bin/rubocop`.
