require "test_helper"

# Connecting an MCP client over OAuth 2.1, end to end: discovery, registration, consent, the
# PKCE code exchange, using the token, refreshing it, and revoking it. See MCP.md → OAuth.
class OauthTest < ActionDispatch::IntegrationTest
  REDIRECT_URI = "https://claude.ai/api/mcp/auth_callback"

  setup do
    @verifier = SecureRandom.urlsafe_base64(48)
  end

  # Discovery

  test "a 401 from /mcp points at the protected resource metadata" do
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream" }

    assert_response :unauthorized
    assert_equal 'Bearer resource_metadata="http://www.example.com/.well-known/oauth-protected-resource/mcp", scope="read write"',
      @response.headers["WWW-Authenticate"]
  end

  test "the protected resource metadata names /mcp and this server, at the root and with the path appended" do
    [ "/.well-known/oauth-protected-resource", "/.well-known/oauth-protected-resource/mcp" ].each do |path|
      get path

      assert_response :success
      assert_equal "http://www.example.com/mcp", @response.parsed_body["resource"]
      assert_equal [ "http://www.example.com" ], @response.parsed_body["authorization_servers"]
      assert_equal Session::SCOPES, @response.parsed_body["scopes_supported"]
    end
  end

  test "the authorization server metadata advertises what is served" do
    get "/.well-known/oauth-authorization-server"

    metadata = @response.parsed_body
    assert_equal "http://www.example.com", metadata["issuer"]
    assert_equal "http://www.example.com/oauth/authorize", metadata["authorization_endpoint"]
    assert_equal "http://www.example.com/oauth/token", metadata["token_endpoint"]
    assert_equal "http://www.example.com/oauth/registrations", metadata["registration_endpoint"]
    assert_equal [ "S256" ], metadata["code_challenge_methods_supported"]
    assert_equal %w[ authorization_code refresh_token ], metadata["grant_types_supported"]
  end

  # Registration

  test "a public client registers and gets no secret" do
    registration = register

    assert registration["client_id"].present?
    assert_nil registration["client_secret"]
    assert_equal "none", registration["token_endpoint_auth_method"]
    assert_not Doorkeeper::Application.find_by!(uid: registration["client_id"]).confidential?
  end

  test "a confidential client registers and gets its secret once" do
    registration = register(token_endpoint_auth_method: "client_secret_post")

    assert registration["client_secret"].present?
    assert_not_equal registration["client_secret"], Doorkeeper::Application.find_by!(uid: registration["client_id"]).secret
  end

  test "a loopback redirect may be plain http, any other may not" do
    assert_response :created, register(redirect_uris: [ "http://localhost:33418/callback" ]).inspect

    register(redirect_uris: [ "http://evil.example/callback" ], expect: :bad_request)
    assert_equal "invalid_redirect_uri", @response.parsed_body["error"]
  end

  test "a private-use scheme redirect is accepted" do
    register(redirect_uris: [ "cursor://anysphere.cursor-retrieval/oauth/callback" ])

    assert_response :created
  end

  test "registration refuses bad metadata in RFC 7591's shape" do
    [ { redirect_uris: [] }, { redirect_uris: [ "urn:ietf:wg:oauth:2.0:oob" ] },
      { grant_types: [ "client_credentials" ] }, { token_endpoint_auth_method: "private_key_jwt" } ].each do |metadata|
      register(**metadata, expect: :bad_request)

      assert_equal "invalid_client_metadata", @response.parsed_body["error"], metadata.inspect
      assert @response.parsed_body["error_description"].present?
    end
  end

  # Consent

  test "a signed-out user is sent to sign in, and comes back to the consent screen" do
    client_id = register["client_id"]

    get authorize_path(client_id)

    assert_redirected_to new_session_path
    post session_password_path, params: { email_address: users(:david).email_address, password: owner_password }
    assert_redirected_to authorize_path(client_id).then { "http://www.example.com#{it}" }
  end

  test "the consent screen names the client, where it will be sent, and the scopes asked for" do
    sign_in_as :david

    get authorize_path(register(client_name: "Claude")["client_id"], scope: "read write delete")

    assert_response :success
    assert_select "h1", text: /Claude/
    assert_select "strong", text: "claude.ai"
    assert_select "input[name='granted_scopes[]']", 3
    assert_match "form-action 'self' https://claude.ai", @response.headers["Content-Security-Policy"]
  end

  test "approving creates the client's session with the scopes the user ticked, and redirects with the code" do
    sign_in_as :david
    client_id = register(client_name: "Claude")["client_id"]

    code = approve(client_id, scope: "read write delete", granted: %w[ read write ])

    assert code.present?
    session = users(:david).sessions.token.find_by!(label: "Claude")
    assert session.oauth?
    assert_equal %w[ read write ], session.scopes
  end

  test "approving with nothing ticked comes back to the screen" do
    sign_in_as :david
    client_id = register["client_id"]

    post oauth_authorization_path, params: authorize_params(client_id).merge(granted_scopes: [])

    assert_response :unprocessable_entity
    assert_not users(:david).sessions.token.exists?(oauth_application: Doorkeeper::Application.find_by(uid: client_id))
  end

  test "denying redirects with access_denied and grants nothing" do
    sign_in_as :david
    client_id = register["client_id"]

    delete oauth_authorization_path, params: authorize_params(client_id)

    assert_match "error=access_denied", @response.location
    assert_equal 0, Session.token.where.not(oauth_application_id: nil).count
  end

  test "PKCE is required" do
    sign_in_as :david

    get authorize_path(register["client_id"]).sub(/&code_challenge=[^&]*/, "")

    assert_response :bad_request
    assert_select "h1", text: /can't be connected/
  end

  test "a resource other than this server is refused" do
    sign_in_as :david

    get authorize_path(register["client_id"], resource: "https://elsewhere.example/mcp")

    assert_response :bad_request
    assert_select "p", text: /elsewhere\.example/
  end

  test "a token can't stand in for the user at the consent screen" do
    get authorize_path(register["client_id"]), headers: bearer_headers_for(:david)

    assert_response :forbidden
  end

  # Tokens

  test "the code is exchanged with the PKCE verifier for a token that drives /mcp within the granted scopes" do
    tokens = connect(granted: %w[ read ])

    assert_equal "read", tokens["scope"]
    assert_equal 3600, tokens["expires_in"]

    names = mcp_tool_names(tokens["access_token"])
    assert_includes names, "get_card"
    assert_not_includes names, "create_card"

    post boards_path(format: :json), params: { name: "Nope" }, headers: bearer(tokens["access_token"]), as: :json
    assert_response :forbidden
  end

  test "what an OAuth client does is attributed to it" do
    tokens = connect(client_name: "Claude")

    post board_cards_path(boards(:writebook), format: :json), params: { title: "Via OAuth", due_on: "2026-12-01" },
      headers: bearer(tokens["access_token"]), as: :json

    assert_response :created
    assert_equal "Claude", Card.find(@response.parsed_body["id"]).events.find_by!(action: "card_created").agent_name
  end

  test "a wrong verifier redeems nothing" do
    sign_in_as :david
    client_id = register["client_id"]
    code = approve(client_id)

    post oauth_token_path, params: { grant_type: "authorization_code", code: code, client_id: client_id,
      redirect_uri: REDIRECT_URI, code_verifier: "wrong" * 10 }

    assert_response :bad_request
    assert_equal "invalid_grant", @response.parsed_body["error"]
  end

  test "a refresh token buys a new access token" do
    tokens = connect

    post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: tokens["refresh_token"], client_id: @client_id }

    assert_response :success
    get my_user_path(format: :json), headers: bearer(@response.parsed_body["access_token"])
    assert_response :success
  end

  test "an expired access token is refused" do
    tokens = connect

    travel 2.hours do
      get my_user_path(format: :json), headers: bearer(tokens["access_token"])
      assert_response :unauthorized
    end
  end

  test "revoking the client from API tokens ends its access token and its refresh token" do
    tokens = connect
    session = Session.token.find_by!(oauth_application: Doorkeeper::Application.find_by!(uid: @client_id))

    delete my_token_path(session)

    get my_user_path(format: :json), headers: bearer(tokens["access_token"])
    assert_response :unauthorized

    post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: tokens["refresh_token"], client_id: @client_id }
    assert_response :bad_request
  end

  test "the client may revoke its own token" do
    tokens = connect

    post oauth_revoke_path, params: { token: tokens["access_token"], client_id: @client_id }

    get my_user_path(format: :json), headers: bearer(tokens["access_token"])
    assert_response :unauthorized
  end

  test "an OAuth session's own signed id is not a credential" do
    connect
    session = Session.token.find_by!(oauth_application: Doorkeeper::Application.find_by!(uid: @client_id))

    get my_user_path(format: :json), headers: bearer(session.token)

    assert_response :unauthorized
  end

  test "the API tokens page lists a connected client" do
    connect(client_name: "Claude")

    get my_tokens_path

    assert_select "li.credential", text: /Claude.*connected/m
  end

  private
    def register(expect: :created, **metadata)
      post oauth_registrations_path, params: { client_name: "Test client", redirect_uris: [ REDIRECT_URI ],
        token_endpoint_auth_method: "none" }.merge(metadata), as: :json

      assert_response expect
      @response.parsed_body
    end

    def authorize_params(client_id, scope: "read write", **extra)
      { response_type: "code", client_id: client_id, redirect_uri: REDIRECT_URI, state: "xyz", scope: scope,
        code_challenge: challenge, code_challenge_method: "S256", resource: "http://www.example.com/mcp" }.merge(extra)
    end

    def authorize_path(client_id, **options)
      oauth_authorization_path(authorize_params(client_id, **options))
    end

    def approve(client_id, scope: "read write", granted: scope.split)
      get authorize_path(client_id, scope: scope)
      post oauth_authorization_path, params: authorize_params(client_id, scope: scope).merge(granted_scopes: granted)

      assert_response :redirect
      redirect = URI.parse(@response.location)
      assert_equal REDIRECT_URI, "#{redirect.scheme}://#{redirect.host}#{redirect.path}"
      query = Rack::Utils.parse_query(redirect.query)
      assert_equal "xyz", query["state"]
      query["code"]
    end

    def connect(client_name: "Test client", granted: %w[ read write ])
      sign_in_as :david
      @client_id = register(client_name: client_name)["client_id"]
      code = approve(@client_id, granted: granted)

      post oauth_token_path, params: { grant_type: "authorization_code", code: code, client_id: @client_id,
        redirect_uri: REDIRECT_URI, code_verifier: @verifier }

      assert_response :success
      @response.parsed_body
    end

    def mcp_tool_names(access_token)
      post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json,
        headers: bearer(access_token).merge("Content-Type" => "application/json", "Accept" => "application/json, text/event-stream")

      assert_response :success
      @response.parsed_body.dig("result", "tools").pluck("name")
    end

    def challenge
      Base64.urlsafe_encode64(Digest::SHA256.digest(@verifier), padding: false)
    end

    def bearer(token)
      { "Authorization" => "Bearer #{token}" }
    end
end
