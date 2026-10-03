module Mudda::Mcp::Tools
  CARD_ADDRESS = {
    board_id: { type: "integer", description: "The board the card is on" },
    number: { type: "integer", description: "The card's number on that board (not its id)" }
  }

  class ListCards < Mudda::Mcp::Tool
    FILTERS = %i[ board_ids column_ids card_ids terms creation indexed_by sorted_by page ]

    tool_name "list_cards"
    title "List cards"
    description <<~TEXT
      Cards across every board, or on one board when `board_id` is given; the filters narrow
      either. To read one lane, pass its column id (from `get_board`) in `column_ids`. Paged:
      follow paging.next or pass `page`.
    TEXT
    arguments(
      properties: {
        board_id: { type: "integer", description: "Only this board's cards" },
        board_ids: { type: "array", items: { type: "integer" } },
        column_ids: { type: "array", items: { type: "integer" } },
        card_ids: { type: "array", items: { type: "integer" } },
        terms: { type: "array", items: { type: "string" }, description: "Full-text terms" },
        creation: { type: "string", enum: TimeWindowParser::VALUES, description: "When the card was created" },
        indexed_by: { type: "string", enum: %w[ all golden ] },
        sorted_by: { type: "string", enum: %w[ latest newest oldest ] },
        page: { type: "integer", minimum: 1 }
      }
    )
    annotations READ

    def self.call(board_id: nil, server_context:, **filters)
      respond api(server_context).get(index_path(board_id), filters.slice(*FILTERS).compact)
    end

    def self.index_path(board_id)
      board_id ? "/boards/#{Integer(board_id)}/cards" : "/cards"
    end
    private_class_method :index_path
  end

  class GetCard < Mudda::Mcp::Tool
    tool_name "get_card"
    title "Get a card"
    description <<~TEXT
      The whole card: its fields, board, column, every step, and its 20 most recent notes. When
      `notes_truncated` is true, `list_notes` pages through the rest.
    TEXT
    arguments(properties: CARD_ADDRESS, required: %w[ board_id number ])
    annotations READ

    def self.call(board_id:, number:, server_context:)
      respond api(server_context).get("/boards/#{Integer(board_id)}/cards/#{Integer(number)}")
    end
  end

  class CreateCard < Mudda::Mcp::Tool
    tool_name "create_card"
    title "Create a card"
    description <<~TEXT
      Creates a card, complete, in the board's Triage column. `due_on` is required. Steps are
      created with it, in order. The result carries the card's `number`, which together with
      the board addresses it from now on.
    TEXT
    arguments(
      properties: {
        board_id: { type: "integer" },
        title: { type: "string" },
        due_on: { type: "string", format: "date", description: "YYYY-MM-DD" },
        description: { type: "string", description: "Rich text; plain text or HTML" },
        golden: { type: "boolean", description: "Starred" },
        steps: { type: "array", items: { type: "string" }, description: "Checklist steps, in order" }
      },
      required: %w[ board_id title due_on ]
    )
    annotations CREATE

    def self.call(board_id:, steps: [], server_context:, **attributes)
      card = attributes.slice(:title, :due_on, :description, :golden)
        .merge(steps_attributes: steps.map { |content| { content: content } })

      respond api(server_context).post("/boards/#{Integer(board_id)}/cards", card)
    end
  end

  class UpdateCard < Mudda::Mcp::Tool
    tool_name "update_card"
    title "Update a card"
    description <<~TEXT
      Changes any of a card's fields in one write — all of it applies or none of it does. Move
      it between lanes with `column_id` (a column of the board it ends up on). Move it to
      another board with `to_board_id`: it is renumbered there, so use the `number` and `url`
      in the result from then on; with no `column_id` it lands in that board's Triage. Steps:
      an entry with no `id` adds one; with an `id` it edits that step, or removes it when
      `remove` is true.
    TEXT
    arguments(
      properties: CARD_ADDRESS.merge(
        title: { type: "string" },
        due_on: { type: "string", format: "date", description: "YYYY-MM-DD" },
        description: { type: "string", description: "Rich text; replaces the whole description" },
        golden: { type: "boolean", description: "Starred" },
        column_id: { type: "integer", description: "The lane to move the card to" },
        to_board_id: { type: "integer", description: "The board to move the card to" },
        steps: {
          type: "array",
          items: {
            type: "object",
            properties: {
              id: { type: "integer" },
              content: { type: "string" },
              completed: { type: "boolean" },
              remove: { type: "boolean" }
            }
          }
        }
      ),
      required: %w[ board_id number ]
    )
    annotations UPDATE

    def self.call(board_id:, number:, to_board_id: nil, steps: nil, server_context:, **attributes)
      card = attributes.slice(:title, :due_on, :description, :golden, :column_id)
      card[:board_id] = to_board_id if to_board_id
      card[:steps_attributes] = steps.map { |step| step_attributes(step) } if steps

      respond api(server_context).put("/boards/#{Integer(board_id)}/cards/#{Integer(number)}", card)
    end

    def self.step_attributes(step)
      step = step.symbolize_keys
      step.slice(:id, :content, :completed).merge(step[:remove] ? { _destroy: true } : {})
    end
    private_class_method :step_attributes
  end
end
