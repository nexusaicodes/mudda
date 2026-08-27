require "test_helper"

# The contract a script or agent drives Mudda through. See API.md.
class ApiTest < ActionDispatch::IntegrationTest
  setup do
    @identity = identities(:david)
  end

  # Authentication

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

    # due_on has to survive the round trip — it was write-only before.
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
    assert_includes @response.parsed_body.pluck("number"), number
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

  # Every write that goes through a bang method used to raise into a 500 HTML page.
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

  # Pagination

  test "index responses carry the paging headers" do
    get cards_path(format: :json), headers: bearer_headers_for(@identity)

    assert_response :success
    assert_equal users(:david).accessible_cards.published.distinct.count.to_s,
      response.headers["X-Total-Count"]
  end
end
