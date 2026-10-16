module Mudda::Mcp
  # Serves MCP at /mcp, over Streamable HTTP, and passes every other request through.
  #
  # It sits inside ActionDispatch::Executor, right after the request id is settled, so one MCP
  # request is one unit of work with one request id: every tool call is a request of its own
  # through the rest of the stack (see Api), sharing that id, and every log line, error report
  # and error result names it.
  #
  # The transport is stateless and answers in plain JSON, so nothing is held between requests
  # and any server process can answer any call. Who is calling is settled per request, by the
  # same Authentication the JSON API uses.
  class Endpoint
    PATH = "/mcp"

    INSTRUCTIONS = <<~TEXT
      Mudda is a single-person kanban app. Boards hold cards; every board has the same four
      fixed columns, in order: Backlog, Todo, Doing, Done (closed). New cards land in Backlog. A
      card is addressed by its board id and its per-board `number`, never its id alone. A
      `due_on` date is required in Todo and Doing and optional in Backlog and Done, so give a
      card one before (or while) moving it into Todo or Doing. Moving a card to another board
      renumbers it, so use the address the result reports. "Today", "overdue" and "due soon"
      follow the owner's time zone, which whoami reports. Errors carry the HTTP status and
      `{ "errors": { field: [messages] } }`.
    TEXT

    # The JSON-RPC method and tool a request names, and nothing else it carries. The request
    # arrives as its raw JSON text or as a parsed message.
    def self.call_named_by(request)
      message = request.is_a?(String) ? JSON.parse(request) : request
      message = message.first if message.is_a?(Array)
      message = message.is_a?(Hash) ? message.with_indifferent_access : {}
      params = message[:params].is_a?(Hash) ? message[:params] : {}

      { mcp_method: message[:method], mcp_tool: params[:name] }.select { |_, value| value.is_a?(String) }
    rescue JSON::ParserError
      {}
    end

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
          with_request_id env, transport_for(api, scopes: identity.body.dig("token", "scopes").to_a).call(env)
        else
          refusal_for identity, env
        end
      end

      # A JSON-RPC error names the request it answered in error.data.request_id, as a failed
      # tool's result does in the API's envelope.
      def with_request_id(env, response)
        status, headers, body = response
        text = read(body)
        headers = headers.to_h.transform_keys(&:downcase)
        payload = JSON.parse(text) if text.present? && headers["content-type"].to_s.include?("json")

        messages = payload.is_a?(Array) ? payload : [ payload ]

        if messages.any? { it.is_a?(Hash) && it["error"].is_a?(Hash) }
          messages.each { stamp_error(it, env["action_dispatch.request_id"]) }
          text = JSON.generate(payload)
          headers = headers.merge("content-length" => text.bytesize.to_s)
        end

        [ status, headers, [ text ] ]
      rescue JSON::ParserError
        [ status, headers, [ text ] ]
      end

      def read(body)
        String.new.tap { |buffer| body.each { buffer << it } }
      ensure
        body.close if body.respond_to?(:close)
      end

      def stamp_error(message, request_id)
        if message.is_a?(Hash) && (error = message["error"]).is_a?(Hash)
          error["data"] = error["data"].is_a?(Hash) ? error["data"].merge("request_id" => request_id) : { "request_id" => request_id, "detail" => error["data"] }.compact
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
          instructions: INSTRUCTIONS, tools: Tools.granted(scopes), server_context: { api: api }
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
