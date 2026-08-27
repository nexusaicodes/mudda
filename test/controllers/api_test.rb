require "test_helper"

# The contract a script or agent drives Mudda through. See API.md.
class ApiTest < ActionDispatch::IntegrationTest
  setup do
    @identity = identities(:david)
  end

  # Authentication

  # Parsing is Rails' own, so the accepted schemes are its schemes: the RFC 7235 names,
  # matched case-sensitively. Pinned because that strictness is a contract, not an accident.
  test "the Bearer and Token schemes authenticate, and padding is tolerated" do
    token = raw_token_for(@identity)

    [ "Bearer #{token}", "Token #{token}", "Bearer  #{token} " ].each do |header|
      get boards_path(format: :json), headers: { "Authorization" => header }

      assert_response :success, "Expected #{header.sub(token, "<token>")} to authenticate"
    end
  end

  test "a lowercased or uppercased scheme is not accepted" do
    token = raw_token_for(@identity)

    [ "bearer #{token}", "BEARER #{token}" ].each do |header|
      get boards_path(format: :json), headers: { "Authorization" => header }

      assert_response :unauthorized, "Expected #{header.sub(token, "<token>")} to be refused"
    end
  end

  # A header is deliberate, a cookie ambient: a tool run from a signed-in machine must get
  # the identity it asked for.
  # Fail closed: a header that was presented and refused is a refusal, not a cue to fall back
  # on whichever cookie the browser was carrying.
  test "a rejected Authorization header refuses the request even with a valid cookie" do
    sign_in_as @identity

    get boards_path(format: :json), headers: { "Authorization" => "Bearer nonsense" }

    assert_response :unauthorized
  end

  test "an explicit Authorization header wins over a session cookie" do
    sign_in_as @identity

    get my_identity_path(format: :json), headers: bearer_headers_for(:jz)

    assert_response :success
    assert_equal identities(:jz).id, @response.parsed_body["id"]
  end

  test "password sign-in over JSON labels the session it mints" do
    post session_password_path(format: :json),
      params: { email_address: @identity.email_address, password: owner_password }

    assert_equal "json-sign-in", @identity.sessions.order(:created_at).last.label
  end

  test "a client holding a token can mint another one" do
    post session_password_path(format: :json),
      params: { email_address: @identity.email_address, password: owner_password },
      headers: bearer_headers_for(@identity)

    assert_response :success
    assert @response.parsed_body["session_token"].present?
  end

  test "authenticate with the owner password" do
    post session_password_path(format: :json),
      params: { email_address: @identity.email_address, password: owner_password }

    assert_response :success
    assert @response.parsed_body["session_token"].present?
  end

  test "the token from password sign-in authenticates later requests" do
    post session_password_path(format: :json),
      params: { email_address: @identity.email_address, password: owner_password }

    token = @response.parsed_body["session_token"]

    reset!
    get boards_path(format: :json), headers: { "Authorization" => "Bearer #{token}" }

    assert_response :success
  end

  test "a bearer token authenticates without a cookie" do
    get boards_path(format: :json), headers: bearer_headers_for(@identity)

    assert_response :success
    assert_nil cookies[:session_token].presence, "A bearer request must not be handed a session cookie"
  end

  test "a garbage token is rejected" do
    get boards_path(format: :json), headers: { "Authorization" => "Bearer nonsense" }

    assert_response :unauthorized
  end

  test "a revoked token is rejected while others keep working" do
    revoked = bearer_headers_for(@identity, label: "revoked")
    kept    = bearer_headers_for(@identity, label: "kept")

    Session.where(label: "revoked").destroy_all

    get boards_path(format: :json), headers: revoked
    assert_response :unauthorized

    get boards_path(format: :json), headers: kept
    assert_response :success
  end

  test "an unauthenticated JSON request is rejected rather than redirected to sign-in" do
    get boards_path(format: :json)

    assert_response :unauthorized
  end

  test "an unauthenticated HTML request still redirects to sign-in" do
    get boards_path

    assert_redirected_to new_session_path
  end

  test "logout" do
    post session_password_path(format: :json),
      params: { email_address: @identity.email_address, password: owner_password }

    assert_difference -> { @identity.sessions.count }, -1 do
      delete session_path(format: :json)
    end

    assert_response :no_content
    assert_not cookies[:session_token].present?
  end

  # The whole workflow an agent needs

  test "create a board, add a card, move it through the columns, note it, and find it" do
    headers = bearer_headers_for(@identity)

    post boards_path(format: :json), params: { name: "Agent board" }, headers: headers, as: :json
    assert_response :created
    board_id = @response.parsed_body["id"]

    # The board names its own lanes, so nothing has to be guessed.
    get board_path(board_id, format: :json), headers: headers
    columns = @response.parsed_body["columns"]
    assert_equal %w[ Triage Backlog Todo Doing Done ], columns.pluck("name")

    post board_cards_path(board_id, format: :json),
      params: { title: "Ship the API", due_on: 1.week.from_now.to_date }, headers: headers, as: :json
    assert_response :created
    number = @response.parsed_body["number"]

    # due_on has to survive the round trip: what was sent in comes back out.
    get card_path(number, format: :json), headers: headers
    assert_equal 1.week.from_now.to_date.to_s, @response.parsed_body["due_on"]
    assert_not @response.parsed_body["overdue"]
    assert_equal "Triage", @response.parsed_body["column"]["name"]

    %w[ Todo Doing Done ].each do |name|
      column_id = columns.find { |column| column["name"] == name }["id"]

      put card_column_path(number, format: :json),
        params: { column_id: column_id }, headers: headers, as: :json

      assert_response :success
      assert_equal name, @response.parsed_body["column"]["name"]
    end

    assert Card.find_by(number: number).closed?

    post card_notes_path(number, format: :json),
      params: { body: "Shipped it" }, headers: headers, as: :json
    assert_response :created

    get search_path(format: :json, q: "Ship the API"), headers: headers
    assert_includes @response.parsed_body["data"].pluck("number"), number
  end

  test "an overdue card reports itself as overdue" do
    headers = bearer_headers_for(@identity)

    put card_path(cards(:logo), format: :json),
      params: { due_on: 1.week.ago.to_date }, headers: headers, as: :json

    assert_response :success
    assert @response.parsed_body["overdue"]
  end

  # Errors

  test "an unknown card is a JSON 404" do
    get card_path(999_999, format: :json), headers: bearer_headers_for(@identity)

    assert_response :not_found
    assert @response.parsed_body["errors"].present?
  end

  test "publishing a card without a due date is a JSON 422 naming the field" do
    headers = bearer_headers_for(@identity)

    post board_cards_path(boards(:writebook), format: :json),
      params: { title: "No due date" }, headers: headers, as: :json

    assert_response :unprocessable_entity
    assert_equal [ "can't be blank" ], @response.parsed_body.dig("errors", "due_on")
  end

  # A bang method's RecordInvalid has to reach the client as the JSON error envelope.
  test "a validation failure on a bang-method write is a JSON 422" do
    headers = bearer_headers_for(@identity)

    post card_steps_path(cards(:logo), format: :json),
      params: { content: "" }, headers: headers, as: :json

    assert_response :unprocessable_entity
    assert_equal [ "can't be blank" ], @response.parsed_body.dig("errors", "content")
  end

  test "moving a card to a column that is not on its board is a JSON 404, not a silent no-op" do
    headers = bearer_headers_for(@identity)
    card = cards(:logo)

    put card_column_path(card, format: :json),
      params: { column_id: columns(:private_todo).id }, headers: headers, as: :json

    assert_response :not_found
    assert_equal "Triage", card.reload.column.name
  end

  # Token lifetime and labels

  test "an API token expires but a browser session does not" do
    api_token = @identity.sessions.create!(label: "agent").token
    browser   = @identity.sessions.create!.token

    travel Session::API_TOKEN_EXPIRY + 1.day do
      get boards_path(format: :json), headers: { "Authorization" => "Bearer #{api_token}" }
      assert_response :unauthorized

      assert_not_nil Session.find_signed(browser), "A browser session must not expire on a timer"
    end
  end

  test "an API token still authenticates inside its lifetime" do
    token = @identity.sessions.create!(label: "agent").token

    travel Session::API_TOKEN_EXPIRY - 1.day do
      get boards_path(format: :json), headers: { "Authorization" => "Bearer #{token}" }

      assert_response :success
    end
  end

  test "minting a token replaces the one already carrying that label" do
    first = @identity.sessions.create!(label: "agent").token
    assert_difference -> { @identity.sessions.where(label: "agent").count }, 0 do
      @second = @identity.sessions.create!(label: "agent").token
    end

    get boards_path(format: :json), headers: { "Authorization" => "Bearer #{first}" }
    assert_response :unauthorized, "The replaced token must stop working"

    get boards_path(format: :json), headers: { "Authorization" => "Bearer #{@second}" }
    assert_response :success
  end

  test "a token carrying one label leaves the other labels alone" do
    kept = @identity.sessions.create!(label: "kept").token
    @identity.sessions.create!(label: "other")

    get boards_path(format: :json), headers: { "Authorization" => "Bearer #{kept}" }

    assert_response :success
  end

  test "browser sessions never revoke each other" do
    assert_difference -> { @identity.sessions.where(label: nil).count }, 2 do
      @identity.sessions.create!
      @identity.sessions.create!
    end
  end

  # Two agents that both sign in over JSON must not revoke each other, which a shared default
  # label would guarantee.
  test "a signing-in client can name its own token label" do
    post session_password_path(format: :json),
      params: { email_address: @identity.email_address, password: owner_password, label: "agent-a" },
      as: :json
    assert_response :success
    first = @response.parsed_body["session_token"]

    reset!
    post session_password_path(format: :json),
      params: { email_address: @identity.email_address, password: owner_password, label: "agent-b" },
      as: :json
    assert_response :success
    second = @response.parsed_body["session_token"]

    reset!
    get boards_path(format: :json), headers: { "Authorization" => "Bearer #{first}" }
    assert_response :success, "agent-a's token must survive agent-b signing in"

    get boards_path(format: :json), headers: { "Authorization" => "Bearer #{second}" }
    assert_response :success
    assert_equal %w[ agent-a agent-b ], @identity.sessions.where.not(label: nil).pluck(:label).sort
  end

  test "a malformed session body is refused rather than raising" do
    post session_password_path(format: :json), params: { session: "nonsense" }, as: :json

    assert_response :unauthorized
    assert_error_envelope "base"
  end

  test "signing in over JSON accepts the credentials wrapped as well as flat" do
    post session_password_path(format: :json),
      params: { session: { email_address: @identity.email_address, password: owner_password } },
      as: :json

    assert_response :success
    assert @response.parsed_body["session_token"].present?
  end

  # Every JSON failure carries the same envelope, so a client never has to branch on the
  # response shape to find out what went wrong. See API.md.

  test "an unauthenticated JSON request carries the error envelope" do
    get boards_path(format: :json)

    assert_response :unauthorized
    assert_error_envelope "base"
  end

  test "a rejected token carries the error envelope" do
    get boards_path(format: :json), headers: { "Authorization" => "Bearer nonsense" }

    assert_response :unauthorized
    assert_error_envelope "base"
  end

  test "a deactivated user's token is forbidden and carries the error envelope" do
    headers = bearer_headers_for(@identity)
    users(:david).deactivate

    get boards_path(format: :json), headers: headers

    assert_response :forbidden
    assert_error_envelope "base"
  end

  test "invalid credentials carry the error envelope" do
    post session_password_path(format: :json),
      params: { email_address: @identity.email_address, password: "wrong" }

    assert_response :unauthorized
    assert_error_envelope "base"
  end

  test "the sign-in rate limit carries the error envelope" do
    11.times do
      post session_password_path(format: :json),
        params: { email_address: @identity.email_address, password: "wrong" }
    end

    assert_response :too_many_requests
    assert_error_envelope "base"
  end

  # Pagination

  test "index responses carry the paging headers" do
    get cards_path(format: :json), headers: bearer_headers_for(@identity)

    assert_response :success
    assert_equal users(:david).accessible_cards.published.distinct.count.to_s,
      response.headers["X-Total-Count"]
  end

  # Paging travels in the body, in the same shape on every index, paginated or not.
  test "every index answers with data and paging" do
    headers = bearer_headers_for(@identity)
    board = boards(:writebook)
    column = board.columns.sorted.first

    [ cards_path(format: :json),
      boards_path(format: :json),
      board_columns_path(board, format: :json),
      board_column_cards_path(board, column, format: :json),
      card_notes_path(cards(:logo), format: :json),
      card_steps_path(cards(:logo), format: :json),
      search_path(format: :json, q: "layout") ].each do |path|
      get path, headers: headers

      assert_response :success, "#{path} should answer"
      assert_kind_of Array, @response.parsed_body["data"], "#{path} should carry data"
      assert_kind_of Integer, @response.parsed_body.dig("paging", "total"), "#{path} should carry paging"
      assert_equal 1, @response.parsed_body.dig("paging", "page")
    end
  end

  test "paging counts the whole result set and links the next page" do
    headers = bearer_headers_for(@identity)
    board = boards(:writebook)
    Current.user = users(:david)
    16.times { |i| board.cards.create! title: "Filler #{i}", due_on: 1.week.from_now, status: "published" }

    get cards_path(format: :json), headers: headers

    total = users(:david).accessible_cards.published.distinct.count
    assert_equal total, @response.parsed_body.dig("paging", "total")
    assert_operator @response.parsed_body.dig("paging", "pages"), :>, 1
    assert_match %r{\Ahttps?://.+\?.*page=2}, @response.parsed_body.dig("paging", "next"),
      "next must be a URL a client can follow without rebuilding it"

    get @response.parsed_body.dig("paging", "next"), headers: headers

    assert_response :success
    assert_equal 2, @response.parsed_body.dig("paging", "page")
  end

  test "the last page links nowhere" do
    get boards_path(format: :json), headers: bearer_headers_for(@identity)

    assert_equal 1, @response.parsed_body.dig("paging", "pages")
    assert_nil @response.parsed_body.dig("paging", "next")
  end

  # Filters

  # Silently dropping it would widen the result set: every card back, and no reason to doubt it.
  test "an unknown filter is refused rather than ignored" do
    get cards_path(format: :json, column_id: columns(:writebook_doing).id),
      headers: bearer_headers_for(@identity)

    assert_response :unprocessable_entity
    assert_equal [ "is not a recognised parameter" ], @response.parsed_body.dig("errors", "column_id")
  end

  test "every unknown filter is named, not just the first" do
    get cards_path(format: :json, nope: 1, nah: 2), headers: bearer_headers_for(@identity)

    assert_response :unprocessable_entity
    assert_equal %w[ nah nope ], @response.parsed_body["errors"].keys.sort
  end

  # A mistyped search parameter fails the other way — an empty result reads as "nothing
  # found" rather than "you asked the wrong question".
  # Each endpoint is held to its own contract, not the union of everyone's.
  test "a filter that belongs to another endpoint is not accepted here" do
    headers = bearer_headers_for(@identity)

    get search_path(format: :json, q: "layout", column_ids: [ columns(:writebook_doing).id ]), headers: headers
    assert_response :unprocessable_entity

    get cards_path(format: :json, q: "layout"), headers: headers
    assert_response :unprocessable_entity
  end

  test "the indexes that take no filters are strict too" do
    headers = bearer_headers_for(@identity)
    board = boards(:writebook)

    [ card_notes_path(cards(:logo), format: :json, pagee: 3),
      card_steps_path(cards(:logo), format: :json, complete: true),
      board_columns_path(board, format: :json, sorted_by: "oldest"),
      board_column_cards_path(board, board.columns.sorted.first, format: :json, colum_ids: "x") ].each do |path|
      get path, headers: headers

      assert_response :unprocessable_entity, "#{path} should refuse a parameter it does not answer to"
    end
  end

  test "an unknown parameter on search is refused too" do
    get search_path(format: :json, query: "layout"), headers: bearer_headers_for(@identity)

    assert_response :unprocessable_entity
    assert_equal [ "is not a recognised parameter" ], @response.parsed_body.dig("errors", "query")
  end

  test "the filters that do exist are still accepted" do
    get cards_path(format: :json, column_ids: [ columns(:writebook_doing).id ], sorted_by: "oldest", page: 1),
      headers: bearer_headers_for(@identity)

    assert_response :success
  end

  # The browser sends assorted form and Turbo params; a person can't act on a 422 anyway.
  test "an unknown param is still tolerated on HTML" do
    sign_in_as @identity

    get cards_path(nope: 1)

    assert_response :success
  end

  private
    def raw_token_for(identity)
      bearer_headers_for(identity)["Authorization"].delete_prefix("Bearer ")
    end

    def assert_error_envelope(key)
      errors = @response.parsed_body["errors"]

      assert errors.is_a?(Hash), "Expected an errors object, got #{@response.parsed_body.inspect}"
      assert errors[key].is_a?(Array), "Expected errors[#{key.inspect}] to be an array of messages"
      assert errors[key].all?(&:present?), "Expected every message to say something"
    end
end
