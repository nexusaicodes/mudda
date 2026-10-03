module Mudda::Mcp::Tools
  class ListNotes < Mudda::Mcp::Tool
    tool_name "list_notes"
    title "List a card's notes"
    description <<~TEXT
      A card's whole note log. `get_card` already embeds the 20 most recent, so this is only
      needed when its `notes_truncated` is true. Paged: follow paging.next or pass `page`.
    TEXT
    arguments(properties: CARD_ADDRESS.merge(page: { type: "integer", minimum: 1 }), required: %w[ board_id number ])
    kind :read

    def self.call(board_id:, number:, page: nil, server_context:)
      respond api(server_context).get("/boards/#{Integer(board_id)}/cards/#{Integer(number)}/notes", page_query(page))
    end
  end

  class AddNote < Mudda::Mcp::Tool
    tool_name "add_note"
    title "Add a note"
    description "Adds a timestamped note to a card's log."
    arguments(
      properties: CARD_ADDRESS.merge(body: { type: "string", description: "Rich text; plain text or HTML" }),
      required: %w[ board_id number body ]
    )
    kind :create

    def self.call(board_id:, number:, body:, server_context:)
      respond api(server_context).post("/boards/#{Integer(board_id)}/cards/#{Integer(number)}/notes", { body: body })
    end
  end

  class UpdateNote < Mudda::Mcp::Tool
    tool_name "update_note"
    title "Edit a note"
    description "Replaces a note's body. Only the note's creator may edit it."
    arguments(
      properties: CARD_ADDRESS.merge(
        note_id: { type: "integer" },
        body: { type: "string", description: "Rich text; plain text or HTML" }
      ),
      required: %w[ board_id number note_id body ]
    )
    kind :update

    def self.call(board_id:, number:, note_id:, body:, server_context:)
      respond api(server_context).put(
        "/boards/#{Integer(board_id)}/cards/#{Integer(number)}/notes/#{Integer(note_id)}", { body: body })
    end
  end

  class DeleteNote < Mudda::Mcp::Tool
    tool_name "delete_note"
    title "Delete a note"
    description "Permanently deletes a note from a card's log. Only the note's creator may delete it."
    arguments(properties: CARD_ADDRESS.merge(note_id: { type: "integer" }), required: %w[ board_id number note_id ])
    kind :delete

    def self.call(board_id:, number:, note_id:, server_context:)
      respond api(server_context).delete("/boards/#{Integer(board_id)}/cards/#{Integer(number)}/notes/#{Integer(note_id)}")
    end
  end
end
