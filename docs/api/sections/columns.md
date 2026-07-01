# Columns

Columns are the fixed workflow lanes on a board. Every board has the same five lanes, in order: **Triage**, **Backlog**, **Todo**, **Doing**, **Done**. A card always lives in exactly one column. Column names and positions are fixed — only a column's color is editable, so there is no create, reorder, or delete.

## `GET /:account_slug/boards/:board_id/columns`

Returns the board's columns, sorted by position.

__Response:__

```json
[
  {
    "id": "03f5v9zkft4hj9qq0lsn9ohcm",
    "name": "Triage",
    "color": {
      "name": "Periwinkle",
      "value": "var(--color-card-1)"
    },
    "created_at": "2025-12-05T19:36:35.534Z",
    "cards_url": "http://app.mudda.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm/columns/03f5v9zkft4hj9qq0lsn9ohcm/cards"
  },
  {
    "id": "03f5v9zkft4hj9qq0lsn9ohcn",
    "name": "Doing",
    "color": {
      "name": "Amber",
      "value": "var(--color-card-5)"
    },
    "created_at": "2025-12-05T19:36:35.534Z",
    "cards_url": "http://app.mudda.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm/columns/03f5v9zkft4hj9qq0lsn9ohcn/cards"
  }
]
```

## `GET /:account_slug/boards/:board_id/columns/:column_id`

Returns the specified column's metadata.

__Response:__

```json
{
  "id": "03f5v9zkft4hj9qq0lsn9ohcm",
  "name": "Doing",
  "color": {
    "name": "Amber",
    "value": "var(--color-card-5)"
  },
  "created_at": "2025-12-05T19:36:35.534Z",
  "cards_url": "http://app.mudda.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm/columns/03f5v9zkft4hj9qq0lsn9ohcm/cards"
}
```

## `GET /:account_slug/boards/:board_id/columns/:column_id/cards`

Returns a paginated list of the published cards in the specified column, most recently active first, with golden cards listed first.

The response items have the same shape as `GET /:account_slug/cards`.

```json
[
  {
    "id": "03f5vaeq985jlvwv3arl4srq2",
    "number": 1,
    "title": "First!",
    "status": "published",
    "description": "Hello, World!",
    "description_html": "<div class=\"action-text-content\"><p>Hello, World!</p></div>",
    "image_url": null,
    "has_attachments": false,
    "closed": false,
    "postponed": false,
    "golden": false,
    "last_active_at": "2025-12-05T19:38:48.553Z",
    "created_at": "2025-12-05T19:38:48.540Z",
    "url": "http://app.mudda.localhost:3006/897362094/cards/1",
    "board": {
      "id": "03f5v9zkft4hj9qq0lsn9ohcm",
      "name": "Mudda",
      "created_at": "2025-12-05T19:36:35.534Z",
      "url": "http://app.mudda.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm",
      "creator": {
        "id": "03f5v9zjw7pz8717a4no1h8a7",
        "name": "David Heinemeier Hansson",
        "active": true,
        "email_address": "david@example.com",
        "created_at": "2025-12-05T19:36:35.401Z",
        "url": "http://app.mudda.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7",
        "avatar_url": "http://app.mudda.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7/avatar"
      }
    },
    "column": {
      "id": "03f5v9zkft4hj9qq0lsn9ohcn",
      "name": "Doing",
      "color": {
        "name": "Amber",
        "value": "var(--color-card-5)"
      },
      "created_at": "2025-12-05T19:36:35.534Z",
      "cards_url": "http://app.mudda.localhost:3006/897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm/columns/03f5v9zkft4hj9qq0lsn9ohcn/cards"
    },
    "creator": {
      "id": "03f5v9zjw7pz8717a4no1h8a7",
      "name": "David Heinemeier Hansson",
      "active": true,
      "email_address": "david@example.com",
      "created_at": "2025-12-05T19:36:35.401Z",
      "url": "http://app.mudda.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7",
      "avatar_url": "http://app.mudda.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7/avatar"
    },
    "notes_url": "http://app.mudda.localhost:3006/897362094/cards/1/notes"
  }
]
```

## `PUT /:account_slug/boards/:board_id/columns/:column_id`

Updates a column's color. Only `color` is editable — column names and positions are fixed.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `color` | string | Yes | One of: `var(--color-card-default)` (Blue), `var(--color-card-1)` (Gray), `var(--color-card-2)` (Tan), `var(--color-card-3)` (Yellow), `var(--color-card-4)` (Lime), `var(--color-card-5)` (Aqua), `var(--color-card-6)` (Violet), `var(--color-card-7)` (Purple), `var(--color-card-8)` (Pink) |

__Request:__

```json
{
  "column": {
    "color": "var(--color-card-4)"
  }
}
```

__Response:__

Returns `200 OK` with the updated column in the same shape as `GET /:account_slug/boards/:board_id/columns/:column_id`.
