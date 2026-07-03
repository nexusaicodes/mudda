# Vestigial-Feature Audit

Post-fork cleanup audit of **Mudda** (single-person standalone build, fork of 37signals'
*Fizzy*). Scope: leftover code/config from the multi-user/SaaS lineage that no longer has a
place in a one-user-per-account app.

**Date:** 2026-07-03
**Method:** 8-folder subagent scan, then targeted deep-dives on the ambiguous tiers.
**Status of the tree at time of writing:** Action Cable / live-updates fully removed; Tiers 1–2
below already applied. `make test` → 796 tests, 0 failures. `make lint` → clean.

---

## Already done (not in this report's backlog)

- **Live updates / Action Cable** — removed down to the framework layer (`application.rb` no
  longer loads `action_cable`); no `solid_cable`, `cable.yml`, `app/channels`, cable DB, or
  `Broadcastable` concerns. State is now "as if cable was never introduced."
- **Tier 1 (dead code):** deleted `copy_to_clipboard_controller.js`; removed unused
  `avatars_helper#avatar_tags`; removed dead `card_collection_changed` / `new_collection`
  branches (`event/description.rb`, `user/day_timeline.rb`).
- **Tier 2 (Comment→Note wording):** `note/promptable.rb` prompt markers, a `searchable.rb`
  comment, and the `layout_commented`→`layout_noted` fixture label (+ 2 test refs).

The rest below (**Tiers 3–5**) is investigated but **not yet applied** — it needs your calls.

---

## Tier 3 — Orphan/vestige candidates (technical, verdicts vary)

### 3.1 `fetch_on_visible_controller.js` — **DEAD (remove)**
- Stimulus `fetch-on-visible` controller; **no `data-controller="fetch-on-visible"` anywhere**.
- Its only reference is a `fetch_on_visible:` kwarg passed to **`cards_next_page_link` — a helper
  that does not exist** (`app/views/cards/previews/index.turbo_stream.erb:7`). That line would
  raise `NoMethodError` if ever hit; it only escapes in tests because kevin's fixtures fit on one
  page (`unless @page.last?` short-circuits).
- **Remove:** delete the controller (glob-pinned, no importmap edit). **Companion latent bug:**
  fix or delete `cards/previews/index.turbo_stream.erb:7` — it's broken for any multi-page result
  regardless; the real pagination API is `link_to_next_page` / `with_automatic_pagination`
  (`pagination_helper.rb`, wiring `pagination_controller.js`).
- **Risk:** Low.

### 3.2 `config/importmap.rb` pin `@hotwired/turbo/offline` — **DEAD pin (remove, then smoke-test)**
- Nothing does `import … "@hotwired/turbo/offline"`. Offline is reached via the turbo-rails
  bundle: `initializers/offline.js` and `clear_offline_cache_controller.js` both
  `import { Turbo } from "@hotwired/turbo-rails"` then use `Turbo.offline.*`.
- The service worker (`app/views/pwa/service_worker.js.erb:1`) uses a *different* asset —
  `importScripts(javascript_url("turbo-offline-umd.min"))` — outside the importmap graph.
- **Remove:** delete `config/importmap.rb:5`. **Verify after:** load as a signed-in user, confirm
  the service worker registers and `Turbo.offline.start` still runs.
- **Risk:** Low–medium (only residual doubt is runtime bare-specifier re-resolution inside the
  pre-bundled `turbo.min.js`, which is unlikely).

### 3.3 `lib/mudda.rb` `Mudda.configure_bundle` — **DEAD no-op (remove)**
- Empty method retained from the removed SaaS Gemfile; sole caller is `bin/rails:5`.
- **Remove:** delete `lib/mudda.rb`; drop `bin/rails` lines 4 (`require_relative "../lib/mudda"`)
  and 5 (`Mudda.configure_bundle`).
- **Risk:** Low.

### 3.4 `config/initializers/table_definition_column_limits.rb` — **LIVE, do NOT remove**
- **Not dead.** It defaults `:string` columns to `limit: 255` and appends real SQLite
  `CHECK(length(...) <= limit)` constraints (SQLite ignores `VARCHAR` lengths otherwise). Backed
  by `db/schema_sqlite.rb` (41 explicit limits) and asserted by `test/models/column_limits_test.rb`
  (raises `ActiveRecord::CheckViolation`).
- **Vestigial part only:** the MySQL-flavored comments and the unused `size:`-conversion branch.
- **Recommendation:** keep the initializer; at most trim the MySQL wording in comments. Removing it
  would silently drop DB-level length enforcement on new databases and break a test.

---

## Tier 4 — Multi-user UI vestiges (product judgment)

> **Structural fact underpinning all of Tier 4:** a second user is *unconstructable* — no
> `users#new`/`#create` route (`routes.rb:9` is `only: %i[show edit update]`), users exist only via
> `Account.create_with_owner`, and `UsersController#set_user` scopes to `.active`. So every
> "other person" branch is dead **by construction**, not just convention.

### 4.A "Only visible to you/others" note visibility — **REMOVE**
- Pure-CSS per-viewer scheme (`_user_css.html.erb`, rendered at `_head.html.erb:21`) keyed to
  `Current.user.id`, driving `data-only-visible-to-you/others` attributes produced in
  `event/description.rb:29-34` (the "You" vs `creator.name` spans) and `cards/notes/_note.html.erb`
  (`data-creator-id` :3, `only_visible_to_you` on the edit link :22).
- With one user, `creator_id` always equals `Current.user.id`: rule 2 (`_user_css.html.erb:6-8`) is
  **dead**, and the activity feed always renders "You". Server-side `ensure_creatorship`
  (`notes_controller.rb:51`) already enforces the only real guarantee.
- **Remove:** delete `_user_css.html.erb` + its render; collapse `creator_tag` to `tag.span("You")`
  (keep `creator_name`, still used by `to_plain_text`/JSON); drop `data-creator-id` and
  `only_visible_to_you` from `_note.html.erb`.
- **Recommendation:** REMOVE (dead branch + meaningless mechanism).

### 4.B Author attribution (avatars + "By <name>") — **KEEP avatars / SIMPLIFY text**
- Renders creator avatar/name on cards, notes, events, search:
  `cards/display/common/_meta.html.erb:3,11`, `cards/display/preview/_meta.html.erb:3,11`,
  `events/event/_layout.html.erb:27-29`, `searches/_result.html.erb:10`,
  `cards/notes/_note.html.erb:4-6,12`, and the tooltip string in `cards_helper.rb:21-27`
  ("added by #{card.creator.name}"). (`_card.json.jbuilder:18` is API, not UI.)
- Not dead, but redundant — every avatar/name is the same single user everywhere.
- **Recommendation:** KEEP avatars (visual rhythm, cheap), optionally drop the literal
  "By <name>" text spans and the "added by …" tooltip clause. Low-value cosmetic; safe to defer to
  a meta-row redesign.

### 4.C Other-user / deactivated-user branches — **KEEP pages, SIMPLIFY dead branches**
- `users/events/show.html.erb:2` — third-person `"has #{@user.first_name}"` branch is **dead** →
  hardcode "What have you been up to?".
- `users/show.html.erb` — `Current.user == @user` false-branches (edit link :6-11, panels :31-52)
  never fire; the `!@user.active?` "no longer on this account" block (:20-24) is unreachable
  (`set_user` filters `.active`); `!@user.verified?` is effectively unreachable post-login.
- `notes_helper.rb:2-8` — `card.creator == Current.user` is always true; the `else` placeholder is
  dead.
- **Recommendation:** KEEP the profile/activity pages (they're your *own* settings), but strip the
  provably-dead other-person/deactivated branches so the code stops implying collaborators.

### 4.D `Account::MultiTenantable` `multi_tenant` flag — **SIMPLIFY**
- `accepting_signups?` = `multi_tenant || Account.none?`. `multi_tenant` (`multi_tenantable.rb:5`,
  set by `config/initializers/multi_tenant.rb` from `ENV`/test config) is effectively always false
  in the real build, so it reduces to `Account.none?`.
- `accepting_signups?` is **load-bearing** — `Account.none?` bootstraps the first-ever signup then
  flips false. Callers: `signups_controller.rb:31`, `sessions_controller.rb:17,39`,
  `cancellable.rb:38`, `sessions/new.html.erb:13`.
- **Simplify:** collapse `accepting_signups?` to `Account.none?`; delete the `cattr_accessor
  :multi_tenant`, `config/initializers/multi_tenant.rb`, the `config.x.multi_tenant.enabled` line in
  `test.rb:72`, and the `with_multi_tenant_mode` test helper; rewrite/drop the 4 tests that exercise
  the dead flag.
- **Recommendation:** KEEP `accepting_signups?`, remove the dead multi-tenant flag machinery.

---

## Tier 5 — Branding placeholders (need owner values)

### Genuinely needs input
| Item | Where | Notes |
|------|-------|-------|
| `https://nexus.ai` | `_colophon.html.erb:4` (user-visible footer) | real Nexus AI URL |
| `support@mudda.do` | `application_mailer.rb:2` default + 7 user-visible views/emails + assert in `account_mailer_test.rb:30` | real support address (overridable via `MAILER_FROM_ADDRESS`) |
| `mudda.do` / `www.` / `app.` | `_colophon.html.erb:1`, `public.html.erb:10`, `docs/api/sections/authentication.md` (9×) + `rich_text.md:34` | real marketing + API host |
| `nexus-ai/mudda` | `CONTRIBUTING.md:4,6` (discussions/issues links) | real GitHub org/repo |

### Legitimate — leave alone
`https://fizzy.do`, "fork of Fizzy", 37signals colophon/license/attribution, the `:bc`
`git_source`, resolved `basecamp/*` lockfile entries, upstream-reference comments, and
`example.com` in Rails boilerplate / API-doc examples / dev seeds are all intentional.

### CLAUDE.md is itself stale (fix the doc)
- CLAUDE.md warns the `Makefile` and `docker-compose.yml` still say `fizzy` / `app.fizzy.localhost`
  — **no longer true.** `Makefile:19` already prints `http://app.mudda.localhost:3006`;
  `docker-compose.yml` has no `fizzy`. The only `app.fizzy.localhost` in the repo is *inside
  CLAUDE.md's own warning* (`CLAUDE.md:55`).
- Test fixtures are already clean of `fizzy`/`nexus`/`37signals` (per commit `208c324ab`).
- **Action:** update/remove the stale branding notes in `CLAUDE.md` (§ "Branding placeholders").

---

## Recommended next actions (prioritized)

| # | Action | Risk | Effort | Status |
|---|--------|------|--------|--------|
| 1 | Remove `fetch_on_visible_controller.js` + fix the broken `cards/previews` line (3.1) | Low | S | **Done** |
| 2 | Remove `lib/mudda.rb` + `bin/rails` shim (3.3) | Low | S | **Done** |
| 3 | Remove `@hotwired/turbo/offline` pin (3.2), then offline smoke-test | Low–Med | S | **Done** |
| 4 | Remove the "only-visible-to-you/others" mechanism (4.A) | Low | M | **Done** |
| 5 | Strip dead other-user branches (4.C) | Low | M | **Partial** — `notes_helper` simplified; the `users/show` + `users/events` third-person branches are **deferred**: they are still exercised by passing tests (`show other`, `update other`, `show as JSON`) because the fixtures seed multiple users per account. Stripping them means a separate single-user-fixtures refactor. |
| 6 | Collapse `multi_tenant` flag → `Account.none?` (4.D) | Low | M | **Deferred** — the flag is **not** dead: `config/environments/test.rb` sets `multi_tenant.enabled = true` to keep signups open so signup/session/cancellation flows can be tested against fixtures that already contain accounts. Collapsing it fails ~22 tests. Not the low-risk simplify the audit assumed. |
| 7 | Fix stale branding notes in CLAUDE.md (Tier 5) | Low | S | **Done** |
| — | Keep `table_definition_column_limits.rb` (3.4) — LIVE | — | — | Kept |
| — | Author attribution (4.B) — product call, defer | — | — | Deferred (avatars kept) |
| — | Real branding values (Tier 5) — needs you | — | — | Placeholders kept |

> **Not in the original audit but done alongside:** all email/mailer infrastructure was
> purged (Action Mailer + Action Mailbox, SMTP, magic-link/cancellation/email-change mail).
> Magic-link *login* stays as an email-free code mechanism until auth is redesigned.
