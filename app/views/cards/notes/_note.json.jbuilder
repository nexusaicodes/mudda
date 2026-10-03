json.cache! note do
  json.(note, :id)

  json.created_at note.created_at.utc
  json.updated_at note.updated_at.utc

  json.body do
    json.plain_text note.body.to_plain_text
    json.html note.body.to_s
  end

  json.creator note.creator, partial: "users/user", as: :user

  json.card do
    json.id note.card_id
    json.url board_card_url(note.card.board, note.card)
  end

  json.url board_card_note_url(note.card.board, note.card, note)
end
