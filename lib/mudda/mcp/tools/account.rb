module Mudda::Mcp::Tools
  class Whoami < Mudda::Mcp::Tool
    tool_name "whoami"
    title "Who am I"
    description "The signed-in user (id, name, email) and their account."
    arguments
    kind :read

    def self.call(server_context:)
      respond api(server_context).get("/my/user")
    end
  end

  class SearchCards < Mudda::Mcp::Tool
    tool_name "search_cards"
    title "Search cards"
    description <<~TEXT
      Full-text search over card titles, descriptions, and notes across every board. A query
      that is exactly a card number returns that card while only one board has a card with
      that number. Paged: follow paging.next or pass `page`.
    TEXT
    arguments(
      properties: {
        q: { type: "string", description: "The search text" },
        page: { type: "integer", minimum: 1 }
      },
      required: %w[ q ]
    )
    kind :read

    def self.call(q:, page: nil, server_context:)
      respond api(server_context).get("/search", { q: q }.merge(page_query(page)))
    end
  end
end
