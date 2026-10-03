json.cache! column do
  json.(column, :id, :name, :color, :position)
  json.created_at column.created_at.utc
  # A lane has no endpoint of its own — its cards are the board's, narrowed by the same
  # column_ids filter every card index takes.
  json.cards_url board_cards_url(column.board, column_ids: [ column.id ])
end
