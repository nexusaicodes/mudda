module Mudda::Mcp
  # A tool is one API call. It names the call and its arguments; what the call does, and whether
  # it is allowed, is decided by the endpoint it reaches.
  class Tool < MCP::Tool
    # What each kind of call is, as MCP hints, and the token scope (Session::SCOPES) it needs.
    KINDS = {
      read: { scope: "read", read_only_hint: true, destructive_hint: false, idempotent_hint: true },
      create: { scope: "write", read_only_hint: false, destructive_hint: false, idempotent_hint: false },
      update: { scope: "write", read_only_hint: false, destructive_hint: false, idempotent_hint: true },
      delete: { scope: "delete", read_only_hint: false, destructive_hint: true, idempotent_hint: true }
    }

    class << self
      attr_reader :scope

      # Mudda reaches nothing outside itself, so no tool is open-world. A tool that does more
      # than its kind suggests corrects the hints it gets from it.
      def kind(name, **hints)
        hints = KINDS.fetch(name).merge(hints)

        @scope = hints[:scope]
        annotations hints.except(:scope).merge(open_world_hint: false)
      end

      # An argument the tool doesn't name is refused by name, rather than reaching a call
      # signature that has no place for it.
      def arguments(properties: {}, required: [])
        input_schema({ properties: properties, required: required.presence, additionalProperties: false }.compact)
      end

      private
        def api(server_context)
          server_context[:api]
        end

        # The API's own JSON goes back as the result, so a tool reports what the endpoint said. A
        # failure keeps its envelope and gains its status, which tells "no such card" (404) from
        # "that's not a valid date" (422).
        def respond(response)
          MCP::Tool::Response.new([ { type: "text", text: text_for(response) } ], error: !response.success?)
        end

        def text_for(response)
          if response.success?
            response.body ? JSON.generate(response.body) : "Done."
          else
            JSON.generate({ "status" => response.status }.merge(response.body || {}))
          end
        end

        def page_query(page)
          { page: page }.compact
        end
    end
  end
end
