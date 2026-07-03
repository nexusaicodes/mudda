# Boards

Boards are where you organize your work - they contain your cards.

## `GET /:account_slug/boards`

Returns a list of boards in the specified account.

__Response:__

```json
[
  {
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
      "url": "http://app.mudda.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
    }
  }
]
```

## `GET /:account_slug/boards/:board_id`

Returns the specified board.

__Response:__

```json
{
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
    "url": "http://app.mudda.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7"
  }
}
```

## `POST /:account_slug/boards`

Creates a new Board in the account.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | The name of the board |

__Request:__

```json
{
  "board": {
    "name": "My new board"
  }
}
```

__Response:__

Returns `201 Created` with a `Location` header pointing to the new board:

```
HTTP/1.1 201 Created
Location: /897362094/boards/03f5v9zkft4hj9qq0lsn9ohcm.json
```

## `PUT /:account_slug/boards/:board_id`

Updates a Board.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | No | The name of the board |

__Request:__

```json
{
  "board": {
    "name": "Updated board name"
  }
}
```

__Response:__

Returns `200 OK` with the updated board in the same shape as `GET /:account_slug/boards/:board_id`.

## `DELETE /:account_slug/boards/:board_id`

Deletes a Board.

__Response:__

Returns `204 No Content` on success.
