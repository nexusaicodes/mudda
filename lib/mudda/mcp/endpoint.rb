module Mudda::Mcp
  # Serves MCP at /mcp, over Streamable HTTP, and passes every other request through.
  #
  # It sits in front of ActionDispatch::Executor because each tool call is a request of its own
  # through the rest of the stack (see Api): a request made from inside a running executor would
  # reset the outer one's state — Current, the database connection — on its way in.
  #
  # The transport is stateless and answers in plain JSON, so nothing is held between requests
  # and any server process can answer any call. Who is calling is settled per request, by the
  # same Authentication the JSON API uses.
  class Endpoint
    PATH = "/mcp"

    INSTRUCTIONS = <<~TEXT
      Mudda is a single-person kanban app. Boards hold cards; every board has the same five
      fixed columns, in order: Triage, Backlog (postponed), Todo, Doing, Done (closed). A card is
      addressed by its board id and its per-board `number`, never its id alone. Every card needs
      a `due_on` date. Moving a card to another board renumbers it, so use the address the
      result reports. Errors carry the HTTP status and `{ "errors": { field: [messages] } }`.
    TEXT

    def initialize(app)
      @app = app
    end

    def call(env)
      if env["PATH_INFO"] == PATH
        serve env
      else
        @app.call env
      end
    end

    private
      def serve(env)
        api = Api.new(@app, env)
        identity = api.get("/my/user")

        if identity.success?
          transport_for(api).call(env)
        else
          refusal_for identity
        end
      end

      # Bearer tokens are the only credential /mcp accepts (Api never forwards a cookie), so a
      # page a browser was tricked into loading has nothing to present. The transport's Host
      # allow-list would only repeat the app's own host checks, so it is left to them.
      def transport_for(api)
        MCP::Server::Transports::StreamableHTTPTransport.new server_for(api),
          stateless: true, enable_json_response: true, serve_subscriptions_listen: false,
          dns_rebinding_protection: false
      end

      def server_for(api)
        MCP::Server.new name: "mudda", title: "Mudda", version: Mudda::Mcp::VERSION,
          instructions: INSTRUCTIONS, tools: Tools::ALL, server_context: { api: api },
          configuration: MCP::Configuration.new(exception_reporter: method(:report_exception))
      end

      def report_exception(exception, context)
        Rails.error.report exception, handled: true, context: context, source: "mudda.mcp"
      end

      # The API's own refusal, unchanged: a 401 for no credential or a bad one, a 403 for a
      # deactivated user.
      def refusal_for(response)
        [ response.status, { "content-type" => "application/json" }, [ JSON.generate(response.body || {}) ] ]
      end
  end
end
