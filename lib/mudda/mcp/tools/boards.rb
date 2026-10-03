module Mudda::Mcp::Tools
  class ListBoards < Mudda::Mcp::Tool
    tool_name "list_boards"
    title "List boards"
    description "Every board in the account. Paged: follow paging.next or pass `page`."
    arguments(properties: { page: { type: "integer", minimum: 1 } })
    annotations READ

    def self.call(page: nil, server_context:)
      respond api(server_context).get("/boards", page_query(page))
    end
  end

  class GetBoard < Mudda::Mcp::Tool
    tool_name "get_board"
    title "Get a board"
    description <<~TEXT
      One board with its five fixed columns, in order: Triage, Backlog, Todo, Doing, Done.
      Column ids from here are what `update_card` takes as `column_id` and `list_cards` as
      `column_ids`.
    TEXT
    arguments(properties: { board_id: { type: "integer" } }, required: %w[ board_id ])
    annotations READ

    def self.call(board_id:, server_context:)
      respond api(server_context).get("/boards/#{Integer(board_id)}")
    end
  end

  class CreateBoard < Mudda::Mcp::Tool
    tool_name "create_board"
    title "Create a board"
    description "Creates a board. It comes with the five fixed columns; they can't be added, removed, or renamed."
    arguments(properties: { name: { type: "string" } }, required: %w[ name ])
    annotations CREATE

    def self.call(name:, server_context:)
      respond api(server_context).post("/boards", { name: name })
    end
  end

  class RenameBoard < Mudda::Mcp::Tool
    tool_name "rename_board"
    title "Rename a board"
    description "Renames a board."
    arguments(
      properties: { board_id: { type: "integer" }, name: { type: "string" } },
      required: %w[ board_id name ]
    )
    annotations UPDATE

    def self.call(board_id:, name:, server_context:)
      respond api(server_context).put("/boards/#{Integer(board_id)}", { name: name })
    end
  end
end
