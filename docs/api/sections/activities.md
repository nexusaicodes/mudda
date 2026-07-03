# Activities

Activities are the activity stream for an account — a record of significant actions like cards being published, moved between boards, retitled, triaged into a column, and notes being added.

## `GET /:account_slug/activities`

Returns a paginated flat list of activities, sorted newest first.

__Query Parameters:__

| Parameter | Description |
|-----------|-------------|
| `board_ids[]` | Filter to activities on specific board ID(s). Multiple values are ORed. |

__Supported actions:__

| `action` | `eventable_type` | `particulars` shape |
|----------|-----------------|---------------------|
| `card_board_changed` | `Card` | `{ "old_board": STRING, "new_board": STRING }` |
| `card_published` | `Card` | `{}` |
| `card_title_changed` | `Card` | `{ "old_title": STRING, "new_title": STRING }` |
| `card_triaged` | `Card` | `{ "column": STRING }` |
| `note_created` | `Note` | `{}` |

`particulars` is always an object. It contains action-specific metadata in a normalized format intended for API clients. It does not necessarily mirror the internal event JSON stored by Mudda. Unknown keys may appear in the future and should be ignored.

__`particulars` examples:__

```json
{ "action": "card_board_changed", "particulars": { "old_board": "Backlog", "new_board": "Mobile" } }
{ "action": "card_title_changed", "particulars": { "old_title": "Fix login", "new_title": "Fix mobile login" } }
{ "action": "card_triaged", "particulars": { "column": "Done" } }
{ "action": "card_published", "particulars": {} }
{ "action": "note_created", "particulars": {} }
```

The `eventable_type` values are `Card` and `Note`. Clients should handle unknown future values conservatively.

Activities whose underlying `Card` or `Note` has been deleted or is inaccessible to the current user are omitted from the feed. The endpoint never returns `eventable: null`.

The top-level `board` field reflects the activity's current board association. If a card moves boards, all its activities move with it for the purposes of this feed and `board_ids[]` filtering.

This endpoint is a paginated activity feed, not an immutable audit-log. `description`, `eventable`, `board`, and `creator` may reflect current resource state. Re-fetch recent pages to get fresh activity data.

__Response:__

```json
[
  {
    "id": "03faevt004",
    "action": "card_triaged",
    "created_at": "2026-03-25T15:11:04.000Z",
    "description": "Saksham Saxena moved \"Fix mobile login\" to \"Done\"",
    "particulars": { "column": "Done" },
    "url": "http://app.mudda.localhost:3006/897362094/cards/42",
    "eventable_type": "Card",
    "eventable": {
      "id": "03f6card042",
      "number": 42,
      "title": "Fix mobile login",
      "status": "published",
      "description": "Users cannot complete login on iOS.",
      "description_html": "<div>Users cannot complete login on iOS.</div>",
      "image_url": null,
      "has_attachments": false,
      "closed": true,
      "postponed": false,
      "golden": false,
      "last_active_at": "2026-03-25T15:11:04.000Z",
      "created_at": "2026-03-25T09:00:00.000Z",
      "url": "http://app.mudda.localhost:3006/897362094/cards/42",
      "board": {
        "id": "03f6abc123",
        "name": "Mobile",
        "created_at": "2026-03-01T10:00:00.000Z",
        "url": "http://app.mudda.localhost:3006/897362094/boards/03f6abc123",
        "creator": {
          "id": "03f5user123",
          "name": "Saksham Saxena",
          "active": true,
          "email_address": "saksham@nexusai.world",
          "created_at": "2026-03-01T09:00:00.000Z",
          "url": "http://app.mudda.localhost:3006/897362094/users/03f5user123",
          "avatar_url": "http://app.mudda.localhost:3006/897362094/users/03f5user123/avatar"
        }
      },
      "column": {
        "id": "03f6done999",
        "name": "Done",
        "color": {
          "name": "Emerald",
          "value": "var(--color-card-4)"
        },
        "created_at": "2026-03-01T10:00:00.000Z",
        "cards_url": "http://app.mudda.localhost:3006/897362094/boards/03f6abc123/columns/03f6done999/cards"
      },
      "creator": {
        "id": "03f5user123",
        "name": "Saksham Saxena",
        "active": true,
        "email_address": "saksham@nexusai.world",
        "created_at": "2026-03-01T09:00:00.000Z",
        "url": "http://app.mudda.localhost:3006/897362094/users/03f5user123",
        "avatar_url": "http://app.mudda.localhost:3006/897362094/users/03f5user123/avatar"
      },
      "notes_url": "http://app.mudda.localhost:3006/897362094/cards/42/notes"
    },
    "board": {
      "id": "03f6abc123",
      "name": "Mobile",
      "created_at": "2026-03-01T10:00:00.000Z",
      "url": "http://app.mudda.localhost:3006/897362094/boards/03f6abc123",
      "creator": {
        "id": "03f5user123",
        "name": "Saksham Saxena",
        "active": true,
        "email_address": "saksham@nexusai.world",
        "created_at": "2026-03-01T09:00:00.000Z",
        "url": "http://app.mudda.localhost:3006/897362094/users/03f5user123",
        "avatar_url": "http://app.mudda.localhost:3006/897362094/users/03f5user123/avatar"
      }
    },
    "creator": {
      "id": "03f5user123",
      "name": "Saksham Saxena",
      "active": true,
      "email_address": "saksham@nexusai.world",
      "created_at": "2026-03-01T09:00:00.000Z",
      "url": "http://app.mudda.localhost:3006/897362094/users/03f5user123",
      "avatar_url": "http://app.mudda.localhost:3006/897362094/users/03f5user123/avatar"
    }
  },
  {
    "id": "03faevt003",
    "action": "note_created",
    "created_at": "2026-03-25T14:17:22.000Z",
    "description": "Saksham Saxena added a note to \"Fix mobile login\"",
    "particulars": {},
    "url": "http://app.mudda.localhost:3006/897362094/cards/42#note_03fanote9",
    "eventable_type": "Note",
    "eventable": {
      "id": "03fanote9",
      "created_at": "2026-03-25T14:17:22.000Z",
      "updated_at": "2026-03-25T14:17:22.000Z",
      "body": {
        "plain_text": "I found the regression in the callback flow.",
        "html": "<div>I found the regression in the callback flow.</div>"
      },
      "creator": {
        "id": "03f5user123",
        "name": "Saksham Saxena",
        "active": true,
        "email_address": "saksham@nexusai.world",
        "created_at": "2026-03-01T09:00:00.000Z",
        "url": "http://app.mudda.localhost:3006/897362094/users/03f5user123",
        "avatar_url": "http://app.mudda.localhost:3006/897362094/users/03f5user123/avatar"
      },
      "card": {
        "id": "03f6card042",
        "url": "http://app.mudda.localhost:3006/897362094/cards/42"
      },
      "url": "http://app.mudda.localhost:3006/897362094/cards/42/notes/03fanote9"
    },
    "board": {
      "id": "03f6abc123",
      "name": "Mobile",
      "created_at": "2026-03-01T10:00:00.000Z",
      "url": "http://app.mudda.localhost:3006/897362094/boards/03f6abc123",
      "creator": {
        "id": "03f5user123",
        "name": "Saksham Saxena",
        "active": true,
        "email_address": "saksham@nexusai.world",
        "created_at": "2026-03-01T09:00:00.000Z",
        "url": "http://app.mudda.localhost:3006/897362094/users/03f5user123",
        "avatar_url": "http://app.mudda.localhost:3006/897362094/users/03f5user123/avatar"
      }
    },
    "creator": {
      "id": "03f5user123",
      "name": "Saksham Saxena",
      "active": true,
      "email_address": "saksham@nexusai.world",
      "created_at": "2026-03-01T09:00:00.000Z",
      "url": "http://app.mudda.localhost:3006/897362094/users/03f5user123",
      "avatar_url": "http://app.mudda.localhost:3006/897362094/users/03f5user123/avatar"
    }
  }
]
```

All `url` fields are opaque absolute URLs for the current Mudda instance. Clients should not construct them.
