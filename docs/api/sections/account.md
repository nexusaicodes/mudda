# Account

## `GET /:account_slug/account/settings`

Returns the current account.

__Response:__

```json
{
  "id": "03f5v9zjvypwh0t0e2rfh0h7k",
  "name": "Mudda",
  "cards_count": 5,
  "created_at": "2025-12-05T19:36:35.401Z"
}
```

`cards_count` is the running total of cards created in the account; it also seeds each card's sequential `number`.
