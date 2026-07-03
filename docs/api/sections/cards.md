# Cards

Cards are tasks or items of work on a board. They live in columns, can be marked golden, carry a rich-text description, an optional header image, steps, and notes.

## `GET /:account_slug/cards`

Returns a paginated list of published cards you have access to. Results can be filtered using query parameters.

__Query Parameters:__

| Parameter | Description |
|-----------|-------------|
| `board_ids[]` | Filter by board ID(s) |
| `card_ids[]` | Filter to specific card ID(s) |
| `column_ids[]` | Filter by column ID(s) |
| `indexed_by` | Filter by: `all` (default), `golden` |
| `sorted_by` | Sort order: `latest` (default), `newest`, `oldest` |
| `creation` | Filter by creation date: `today`, `yesterday`, `thisweek`, `lastweek`, `thismonth`, `lastmonth`, `thisyear`, `lastyear` |
| `terms[]` | Search terms to filter cards |

Repeated `column_ids[]` (and `board_ids[]`, `card_ids[]`) values are ORed together. Different filters combine with AND.

Example:
- `column_ids[]=03f...` — cards in a column by ID

__Response:__

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
        "name": "Saksham Saxena",
        "active": true,
        "email_address": "saksham@nexusai.world",
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
      "name": "Saksham Saxena",
      "active": true,
      "email_address": "saksham@nexusai.world",
      "created_at": "2025-12-05T19:36:35.401Z",
      "url": "http://app.mudda.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7",
      "avatar_url": "http://app.mudda.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7/avatar"
    },
    "notes_url": "http://app.mudda.localhost:3006/897362094/cards/1/notes"
  }
]
```

## `GET /:account_slug/cards/:card_number`

Returns a specific card by its number. Same shape as the list items above, plus a `steps` array.

__Response:__

```json
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
      "name": "Saksham Saxena",
      "active": true,
      "email_address": "saksham@nexusai.world",
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
    "name": "Saksham Saxena",
    "active": true,
    "email_address": "saksham@nexusai.world",
    "created_at": "2025-12-05T19:36:35.401Z",
    "url": "http://app.mudda.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7",
    "avatar_url": "http://app.mudda.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7/avatar"
  },
  "notes_url": "http://app.mudda.localhost:3006/897362094/cards/1/notes",
  "steps": [
    {
      "id": "03f8huu0sog76g3s975963b5e",
      "content": "This is the first step",
      "completed": false
    },
    {
      "id": "03f8huu0sog76g3s975969734",
      "content": "This is the second step",
      "completed": false
    }
  ]
}
```

> **Note:** Every card always lives in exactly one column, so `column` is always present. A board has five fixed lanes: Triage, Backlog, Todo, Doing, Done. `closed` is `true` when the card is in **Done**; `postponed` is `true` when it is in **Backlog**.

## `POST /:account_slug/boards/:board_id/cards`

Creates a new, published card in a board.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `title` | string | No | The title of the card (defaults to "Untitled") |
| `description` | string | No | Rich text description of the card |
| `image` | file | No | Header image for the card |
| `due_on` | date | No | Due date (ISO 8601 `YYYY-MM-DD`) |
| `created_at` | datetime | No | Override creation timestamp (ISO 8601 format) |
| `last_active_at` | datetime | No | Override last activity timestamp (ISO 8601 format) |

__Request:__

```json
{
  "card": {
    "title": "Add dark mode support",
    "description": "We need to add dark mode to the app"
  }
}
```

__Response:__

Returns `201 Created` with a `Location` header pointing to the new card.

## `PUT /:account_slug/cards/:card_number`

Updates a card.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `title` | string | No | The title of the card |
| `description` | string | No | Rich text description of the card |
| `image` | file | No | Header image for the card |
| `due_on` | date | No | Due date (ISO 8601 `YYYY-MM-DD`) |
| `created_at` | datetime | No | Override creation timestamp (ISO 8601 format) |
| `last_active_at` | datetime | No | Override last activity timestamp (ISO 8601 format) |

__Request:__

```json
{
  "card": {
    "title": "Add dark mode support (Updated)"
  }
}
```

__Response:__

Returns the updated card.

## `DELETE /:account_slug/cards/:card_number`

Deletes a card.

__Response:__

Returns `204 No Content` on success.

## `DELETE /:account_slug/cards/:card_number/image`

Removes the header image from a card.

__Response:__

Returns `204 No Content` on success.

## `PUT /:account_slug/cards/:card_number/board`

Moves a card to a different board. The card is dropped into the destination board's Triage lane.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `board_id` | string | Yes | The ID of the board to move the card to |

__Request:__

```json
{
  "board_id": "03f5v9zkft4hj9qq0lsn9ohcm"
}
```

__Response:__

Returns `200 OK` with the moved card in the same shape as `GET /:account_slug/cards/:card_number`. The `board` field reflects the new board.

## `POST /:account_slug/cards/:card_number/goldness`

Marks a card as golden.

__Response:__

Returns `204 No Content` on success.

## `DELETE /:account_slug/cards/:card_number/goldness`

Removes golden status from a card.

__Response:__

Returns `204 No Content` on success.
