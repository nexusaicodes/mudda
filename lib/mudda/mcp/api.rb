module Mudda::Mcp
  # The JSON API, driven from inside the process. Each call is a request through the rest of the
  # middleware stack carrying the MCP client's own credential, so a tool is held to exactly what
  # the same call over HTTP would be: authentication, strict params, validation, events, and the
  # error envelope all come from the controllers, not from here.
  class Api
    Response = Data.define(:status, :headers, :body) do
      def success?
        status.between?(200, 299)
      end

      def location
        headers["location"]
      end
    end

    # What a call inherits from the request that carried it: who is asking, from where, and the
    # host and scheme the API builds its URLs from. Never the cookie — /mcp answers to the
    # Authorization header alone.
    INHERITED_ENV = %w[
      HTTP_AUTHORIZATION HTTP_HOST HTTP_USER_AGENT
      HTTP_X_FORWARDED_FOR HTTP_X_FORWARDED_HOST HTTP_X_FORWARDED_PORT HTTP_X_FORWARDED_PROTO
      REMOTE_ADDR SERVER_NAME SERVER_PORT HTTPS rack.url_scheme
    ]

    def initialize(app, env)
      @app = app
      @inherited_env = env.slice(*INHERITED_ENV)
    end

    def get(path, query = {})
      request "GET", path, query: query
    end

    def post(path, body)
      request "POST", path, body: body
    end

    def put(path, body)
      request "PUT", path, body: body
    end

    def delete(path)
      request "DELETE", path
    end

    private
      def request(method, path, query: {}, body: nil)
        status, headers, rack_body = @app.call(env_for(method, path, query, body))
        Response.new(status: status, headers: headers, body: parse(read(rack_body)))
      end

      # The app's env_config — key generator, cookie and parameter settings — is merged into a
      # request by Rails.application#call, which these calls enter below.
      def env_for(method, path, query, body)
        Rack::MockRequest.env_for(uri_for(path, query), method: method, input: body&.to_json)
          .merge(Rails.application.env_config)
          .merge("HTTP_ACCEPT" => "application/json", "CONTENT_TYPE" => "application/json")
          .merge(@inherited_env)
      end

      def uri_for(path, query)
        if query.present?
          "#{path}.json?#{Rack::Utils.build_nested_query(query)}"
        else
          "#{path}.json"
        end
      end

      # Closing the body is what completes the request's executor run, so it is closed even
      # when reading it fails.
      def read(rack_body)
        String.new.tap do |buffer|
          rack_body.each { |chunk| buffer << chunk }
        end
      ensure
        rack_body.close if rack_body.respond_to?(:close)
      end

      # Every API failure renders the JSON envelope; anything else is reported as the body it was.
      def parse(text)
        JSON.parse(text) if text.present?
      rescue JSON::ParserError
        { "errors" => { "base" => [ text.truncate(500) ] } }
      end
  end
end
