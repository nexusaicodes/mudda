json.cache! [ card, card.overdue? ] do
  json.(card, :id, :number, :title)
  json.description card.description.to_plain_text
  json.description_html card.description.to_s
  json.has_attachments card.has_attachments?

  json.closed card.closed?
  json.postponed card.postponed?
  json.golden card.golden?
  json.overdue card.overdue?
  json.color card.color
  json.due_on card.due_on
  json.last_active_at card.last_active_at.utc
  json.created_at card.created_at.utc

  json.url board_card_url(card.board, card)

  json.board card.board, partial: "boards/board", as: :board
  json.column card.column, partial: "columns/column", as: :column if card.column
  json.creator card.creator, partial: "users/user", as: :user

  json.notes_url board_card_notes_url(card.board, card)
end
