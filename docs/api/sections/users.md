# Users

The user record represents the person who owns this Mudda account. Mudda runs as a
single-person app, so there is one user per account and no role model.

## `GET /:account_slug/users/:user_id`

Returns the specified user.

__Response:__

```json
{
  "id": "03f5v9zjw7pz8717a4no1h8a7",
  "name": "David Heinemeier Hansson",
  "active": true,
  "email_address": "david@example.com",
  "created_at": "2025-12-05T19:36:35.401Z",
  "url": "http://app.mudda.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7",
  "avatar_url": "http://app.mudda.localhost:3006/897362094/users/03f5v9zjw7pz8717a4no1h8a7/avatar"
}
```

## `PUT /:account_slug/users/:user_id`

Updates a user.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | No | The user's display name |
| `avatar` | file | No | The user's avatar image |

__Request:__

```json
{
  "user": {
    "name": "David H. Hansson"
  }
}
```

__Response:__

Returns `200 OK` with the updated user in the same shape as `GET /:account_slug/users/:user_id`.

## `DELETE /:account_slug/users/:user_id/avatar`

Removes the user's avatar image.

__Response:__

Returns `204 No Content` on success.

## `POST /:account_slug/users/:user_id/email_addresses`

Initiates an email address change for the user. A confirmation email is sent to the new address with a token link.

This is a two-step process, similar to magic link authentication:

1. Request the change (this endpoint) — a confirmation email is sent to the new address
2. Confirm the change (`POST .../confirmation`) — the token from the email is submitted to complete the change

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `email_address` | string | Yes | The new email address |

__Response:__

Returns `201 Created` on success. The user must check the new email address for a confirmation link.

__Error responses:__

| Status Code | Description |
|--------|-------------|
| `400 Bad Request` | Missing `email_address` parameter |
| `404 Not Found` | User is not your own |
| `422 Unprocessable Entity` | Invalid email format, same as current email, or already belongs to a user in the same account |
| `429 Too Many Requests` | Rate limit exceeded (5 per hour) |

## `POST /:account_slug/users/:user_id/email_addresses/:token/confirmation`

Confirms an email address change using the token from the confirmation email. This endpoint does not require authentication — the token itself serves as proof of access to the new email.

The token is the full value from the confirmation URL sent in the email. It expires after 30 minutes.

__Response:__

Returns `204 No Content` on success. The user's email address has been changed.

__Error responses:__

| Status Code | Description |
|--------|-------------|
| `422 Unprocessable Entity` | Token is invalid or has expired |
| `429 Too Many Requests` | Rate limit exceeded (5 per hour) |
