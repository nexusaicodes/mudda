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
          transport_for(api, scopes: identity.body.dig("token", "scopes").to_a).call(env)
        else
          refusal_for identity, env
        end
      end

      # Bearer tokens are the only credential /mcp accepts (Api never forwards a cookie), so a
      # page a browser was tricked into loading has nothing to present. The transport's Host
      # allow-list would only repeat the app's own host checks, so it is left to them.
      def transport_for(api, scopes:)
        MCP::Server::Transports::StreamableHTTPTransport.new server_for(api, scopes:),
          stateless: true, enable_json_response: true, serve_subscriptions_listen: false,
          dns_rebinding_protection: false
      end

      def server_for(api, scopes:)
        MCP::Server.new name: "mudda", title: "Mudda", version: Mudda::Mcp::VERSION,
          instructions: INSTRUCTIONS, tools: Tools.granted(scopes), server_context: { api: api },
          configuration: MCP::Configuration.new(exception_reporter: method(:report_exception))
      end

      def report_exception(exception, context)
        Rails.error.report exception, handled: true, context: context, source: "mudda.mcp"
      end

      # The API's own refusal: a 401 for no credential or a bad one, a 403 for a deactivated
      # user, a 429 with its Retry-After for a token over its rate limit. A 401 also points the
      # client at the OAuth metadata (RFC 9728), which is how an MCP client finds out it can
      # connect by sending the user to sign in, and asks for the scopes a token gets by default —
      # deleting is something the user has to be asked for separately.
      def refusal_for(response, env)
        headers = { "content-type" => "application/json" }
        headers["retry-after"] = response.headers["retry-after"] if response.headers["retry-after"]
        headers["www-authenticate"] = authenticate_header(env) if response.status == 401

        [ response.status, headers, [ JSON.generate(response.body || {}) ] ]
      end

      def authenticate_header(env)
        metadata_url = "#{Rack::Request.new(env).base_url}/.well-known/oauth-protected-resource#{PATH}"
        %(Bearer resource_metadata="#{metadata_url}", scope="#{Session::DEFAULT_SCOPES.join(" ")}")
      end
  end
end
