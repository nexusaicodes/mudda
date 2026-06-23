# GitHub Copilot instructions for Mudda

Mudda is a Kanban issue/idea tracker (Rails, edge/`main`). It is maintained by **Nexus AI**
and is a fork of **Fizzy**, originally created by **37signals**. The full context lives in
[`AGENTS.md`](../AGENTS.md) (architecture), [`STYLE.md`](../STYLE.md) (house style), and
[`CLAUDE.md`](../CLAUDE.md) (OSS/SaaS dual mode + fork-specific gotchas). Read those first;
this file is a short orientation, not a duplicate.

## What to know before suggesting code

- **Vanilla Rails.** Thin controllers calling a rich domain model. No service objects unless
  genuinely justified. Model web actions as CRUD on resources — add a resource rather than a
  custom controller action.
- **House style.** Prefer expanded conditionals over guard clauses; order methods
  class → public → private and vertically by invocation order; use `!` only when a
  non-bang counterpart exists; name job-enqueuing methods `_later` and their sync bodies
  `_now`. Don't add narrative/historical comments — comments describe the present state only.
- **Fixed columns.** Every board has five fixed lanes: **Triage, Backlog, Todo, Doing,
  Done**. A card always lives in exactly one column and `column_id` is the single source of
  truth for its lifecycle (`closed?` = Done, `postponed?` = Backlog, etc.). There are no
  tags and no entropy/auto-postpone system — cards use an explicit `due_on` date.
- **Multi-tenancy** is URL path-based (`/{account_id}/...`) via `AccountSlug::Extractor`;
  `Current.account` is set per request and restored in jobs by the `AccountTenanted` concern.
- **UUIDv7 keys** are base36-encoded, 25-char strings; `external_account_id` and card
  `number` are separate integer sequences.
- **OSS vs SaaS.** Two Gemfiles (`Gemfile`, `Gemfile.saas`) with separate lockfiles. Keep
  them in sync with `bin/bundle-both`; check drift with `bin/bundle-drift`. The `saas/`
  directory is a self-contained `mudda-saas` Rails engine.

## Commands

- Setup/run: `bin/setup`, `bin/dev` (port 3006, http://app.mudda.localhost:3006).
- Tests: `bin/rails test`, `bin/rails test:system`. Full pipeline: `bin/ci` (boots Rails and
  runs `config/ci.rb` — edit that, not a YAML workflow).
- Style: `bin/rubocop` (`rubocop-rails-omakase` + thin overrides).

## Fork hygiene

Some upstream hosting values (37signals/Basecamp deploy hosts, registries, CDNs) are
intentionally left in place and must be replaced for a Nexus AI deployment — see the
"Fork & branding" section of [`CLAUDE.md`](../CLAUDE.md). Do not repoint the `:bc` git_source
(it resolves real forked gems), and don't mistake the `Integration::Basecamp` feature for
branding.
