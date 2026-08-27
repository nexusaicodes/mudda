require "test_helper"

# The contract a script or agent drives Mudda through. See API.md.
class ApiTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:david)
  end

  # Authentication

  # Parsing is Rails' own, so the accepted schemes are its schemes: the RFC 7235 names,
  # matched case-sensitively. Pinned because that strictness is a contract, not an accident.
  test "the Bearer and Token schemes authenticate, and padding is tolerated" do
    token = raw_token_for(@user)

    [ "Bearer #{token}", "Token #{token}", "Bearer  #{token} " ].each do |header|
      get boards_path(format: :json), headers: { "Authorization" => header }

      assert_response :success, "Expected #{header.sub(token, "<token>")} to authenticate"
    end
  end

  test "a lowercased or uppercased scheme is not accepted" do
    token = raw_token_for(@user)

    [ "bearer #{token}", "BEARER #{token}" ].each do |header|
      get boards_path(format: :json), headers: { "Authorization" => header }

      assert_response :unauthorized, "Expected #{header.sub(token, "<token>")} to be refused"
    end
  end

  # A header is deliberate, a cookie ambient: a tool run from a signed-in machine must get
  # the user it asked for.
  # Fail closed: a header that was presented and refused is a refusal, not a cue to fall back
  # on whichever cookie the browser was carrying.
  test "a rejected Authorization header refuses the request even with a valid cookie" do
    sign_in_as @user

    get boards_path(format: :json), headers: { "Authorization" => "Bearer nonsense" }

    assert_response :unauthorized
  end

  test "an explicit Authorization header wins over a session cookie" do
    sign_in_as @user

    get my_user_path(format: :json), headers: bearer_headers_for(:jz)

    assert_response :success
    assert_equal users(:jz).id, @response.parsed_body["id"]
  end

  test "password sign-in over JSON labels the session it mints" do
    post session_password_path(format: :json),
      params: { email_address: @user.email_address, password: owner_password }

    assert_equal "json-sign-in", @user.sessions.order(:created_at).last.label
  end

  test "a client holding a token can mint another one" do
    post session_password_path(format: :json),
      params: { email_address: @user.email_address, password: owner_password },
      headers: bearer_headers_for(@user)

    assert_response :success
    assert @response.parsed_body["session_token"].present?
  end

  test "authenticate with the owner password" do
    post session_password_path(format: :json),
      params: { email_address: @user.email_address, password: owner_password }

    assert_response :success
    assert @response.parsed_body["session_token"].present?
  end

  test "the token from password sign-in authenticates later requests" do
    post session_password_path(format: :json),
      params: { email_address: @user.email_address, password: owner_password }

    token = @response.parsed_body["session_token"]

    reset!
    get boards_path(format: :json), headers: { "Authorization" => "Bearer #{token}" }

    assert_response :success
  end

  test "a bearer token authenticates without a cookie" do
    get boards_path(format: :json), headers: bearer_headers_for(@user)

    assert_response :success
    assert_nil cookies[:session_token].presence, "A bearer request must not be handed a session cookie"
  end

  test "a garbage token is rejected" do
    get boards_path(format: :json), headers: { "Authorization" => "Bearer nonsense" }

    assert_response :unauthorized
  end

  test "a revoked token is rejected while others keep working" do
    revoked = bearer_headers_for(@user, label: "revoked")
    kept    = bearer_headers_for(@user, label: "kept")

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
      params: { email_address: @user.email_address, password: owner_password }

    assert_difference -> { @user.sessions.count }, -1 do
      delete session_path(format: :json)
    end

    assert_response :no_content
    assert_not cookies[:session_token].present?
  end

  # The whole workflow an agent needs

  test "create a board, add a card, move it through the columns, note it, and find it" do
    headers = bearer_headers_for(@user)

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
    board = Board.find(board_id)

    # due_on has to survive the round trip: what was sent in comes back out.
    get board_card_path(board, number, format: :json), headers: headers
    assert_equal 1.week.from_now.to_date.to_s, @response.parsed_body["due_on"]
    assert_not @response.parsed_body["overdue"]
    assert_equal "Triage", @response.parsed_body["column"]["name"]

    %w[ Todo Doing Done ].each do |name|
      column_id = columns.find { |column| column["name"] == name }["id"]

      put board_card_path(board, number, format: :json),
        params: { column_id: column_id }, headers: headers, as: :json

      assert_response :success
      assert_equal name, @response.parsed_body["column"]["name"]
    end

    assert board.cards.find_by(number: number).closed?

    post board_card_notes_path(board, number, format: :json),
      params: { body: "Shipped it" }, headers: headers, as: :json
    assert_response :created

    get search_path(format: :json, q: "Ship the API"), headers: headers
    assert_includes @response.parsed_body["data"].pluck("number"), number
  end

  test "an overdue card reports itself as overdue" do
    headers = bearer_headers_for(@user)

    put board_card_path(cards(:logo).board, cards(:logo), format: :json),
      params: { due_on: 1.week.ago.to_date }, headers: headers, as: :json

    assert_response :success
    assert @response.parsed_body["overdue"]
  end

  # Errors

  test "an unknown card is a JSON 404" do
    get board_card_path(boards(:writebook), 999_999, format: :json), headers: bearer_headers_for(@user)

    assert_response :not_found
    assert @response.parsed_body["errors"].present?
  end

  test "publishing a card without a due date is a JSON 422 naming the field" do
    headers = bearer_headers_for(@user)

    post board_cards_path(boards(:writebook), format: :json),
      params: { title: "No due date" }, headers: headers, as: :json

    assert_response :unprocessable_entity
    assert_equal [ "can't be blank" ], @response.parsed_body.dig("errors", "due_on")
  end

  # A bang method's RecordInvalid has to reach the client as the JSON error envelope, and a
  # nested record's errors in the same one as the card's own. Blanking an *existing* step is
  # the failure; a blank new row is dropped instead (see Card::Multistep).
  test "a validation failure inside a card's steps is a JSON 422" do
    card, headers = cards(:logo), bearer_headers_for(@user)
    step = card.steps.create!(content: "Original")

    put board_card_path(card.board, card, format: :json),
      params: { steps_attributes: [ { id: step.id, content: "" } ] }, headers: headers, as: :json

    assert_response :unprocessable_entity
    assert_equal [ "can't be blank" ], @response.parsed_body.dig("errors", "steps.content")
    assert_equal "Original", step.reload.content
  end

  test "a blank new step row is dropped rather than failing the card" do
    card, headers = cards(:logo), bearer_headers_for(@user)

    assert_no_difference -> { card.steps.count } do
      put board_card_path(card.board, card, format: :json),
        params: { title: "Still fine", steps_attributes: [ { content: "" } ] }, headers: headers, as: :json
    end

    assert_response :success
    assert_equal "Still fine", card.reload.title
  end

  test "moving a card to a column that is not on its board is a JSON 404, not a silent no-op" do
    headers = bearer_headers_for(@user)
    card = cards(:logo)

    put board_card_path(card.board, card, format: :json),
      params: { column_id: columns(:private_todo).id }, headers: headers, as: :json

    assert_response :not_found
    assert_equal "Triage", card.reload.column.name
  end

  # Token lifetime and labels

  test "an API token expires but a browser session does not" do
    api_token = @user.sessions.create!(kind: :token, label: "agent").token
    browser   = @user.sessions.create!.token

    travel Session::API_TOKEN_EXPIRY + 1.day do
      get boards_path(format: :json), headers: { "Authorization" => "Bearer #{api_token}" }
      assert_response :unauthorized

      assert_not_nil Session.find_signed(browser), "A browser session must not expire on a timer"
    end
  end

  test "an API token still authenticates inside its lifetime" do
    token = @user.sessions.create!(kind: :token, label: "agent").token

    travel Session::API_TOKEN_EXPIRY - 1.day do
      get boards_path(format: :json), headers: { "Authorization" => "Bearer #{token}" }

      assert_response :success
    end
  end

  test "minting a token replaces the one already carrying that label" do
    first = @user.sessions.create!(kind: :token, label: "agent").token
    assert_difference -> { @user.sessions.where(label: "agent").count }, 0 do
      @second = @user.sessions.create!(kind: :token, label: "agent").token
    end

    get boards_path(format: :json), headers: { "Authorization" => "Bearer #{first}" }
    assert_response :unauthorized, "The replaced token must stop working"

    get boards_path(format: :json), headers: { "Authorization" => "Bearer #{@second}" }
    assert_response :success
  end

  test "a token carrying one label leaves the other labels alone" do
    kept = @user.sessions.create!(kind: :token, label: "kept").token
    @user.sessions.create!(kind: :token, label: "other")

    get boards_path(format: :json), headers: { "Authorization" => "Bearer #{kept}" }

    assert_response :success
  end

  test "browser sessions never revoke each other" do
    assert_difference -> { @user.sessions.where(label: nil).count }, 2 do
      @user.sessions.create!
      @user.sessions.create!
    end
  end

  # Two agents that both sign in over JSON must not revoke each other, which a shared default
  # label would guarantee.
  test "a signing-in client can name its own token label" do
    post session_password_path(format: :json),
      params: { email_address: @user.email_address, password: owner_password, label: "agent-a" },
      as: :json
    assert_response :success
    first = @response.parsed_body["session_token"]

    reset!
    post session_password_path(format: :json),
      params: { email_address: @user.email_address, password: owner_password, label: "agent-b" },
      as: :json
    assert_response :success
    second = @response.parsed_body["session_token"]

    reset!
    get boards_path(format: :json), headers: { "Authorization" => "Bearer #{first}" }
    assert_response :success, "agent-a's token must survive agent-b signing in"

    get boards_path(format: :json), headers: { "Authorization" => "Bearer #{second}" }
    assert_response :success
    assert_equal %w[ agent-a agent-b ], @user.sessions.where.not(label: nil).pluck(:label).sort
  end

  test "a malformed session body is refused rather than raising" do
    post session_password_path(format: :json), params: { session: "nonsense" }, as: :json

    assert_response :unauthorized
    assert_error_envelope "base"
  end

  test "signing in over JSON accepts the credentials wrapped as well as flat" do
    post session_password_path(format: :json),
      params: { session: { email_address: @user.email_address, password: owner_password } },
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
    headers = bearer_headers_for(@user)
    users(:david).deactivate

    get boards_path(format: :json), headers: headers

    assert_response :forbidden
    assert_error_envelope "base"
  end

  test "invalid credentials carry the error envelope" do
    post session_password_path(format: :json),
      params: { email_address: @user.email_address, password: "wrong" }

    assert_response :unauthorized
    assert_error_envelope "base"
  end

  test "the sign-in rate limit carries the error envelope" do
    11.times do
      post session_password_path(format: :json),
        params: { email_address: @user.email_address, password: "wrong" }
    end

    assert_response :too_many_requests
    assert_error_envelope "base"
  end

  # Pagination

  test "index responses carry the paging headers" do
    get cards_path(format: :json), headers: bearer_headers_for(@user)

    assert_response :success
    assert_equal users(:david).accessible_cards.published.distinct.count.to_s,
      response.headers["X-Total-Count"]
  end

  # Paging travels in the body, in the same shape on every index, paginated or not.
  test "every index answers with data and paging" do
    headers = bearer_headers_for(@user)
    board = boards(:writebook)

    [ cards_path(format: :json),
      board_cards_path(board, format: :json),
      boards_path(format: :json),
      board_card_notes_path(cards(:logo).board, cards(:logo), format: :json),
      search_path(format: :json, q: "layout") ].each do |path|
      get path, headers: headers

      assert_response :success, "#{path} should answer"
      assert_kind_of Array, @response.parsed_body["data"], "#{path} should carry data"
      assert_kind_of Integer, @response.parsed_body.dig("paging", "total"), "#{path} should carry paging"
      assert_equal 1, @response.parsed_body.dig("paging", "page")
    end
  end

  test "paging counts the whole result set and links the next page" do
    headers = bearer_headers_for(@user)
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
    get boards_path(format: :json), headers: bearer_headers_for(@user)

    assert_equal 1, @response.parsed_body.dig("paging", "pages")
    assert_nil @response.parsed_body.dig("paging", "next")
  end

  # Filters

  # Silently dropping it would widen the result set: every card back, and no reason to doubt it.
  test "an unknown filter is refused rather than ignored" do
    get cards_path(format: :json, column_id: columns(:writebook_doing).id),
      headers: bearer_headers_for(@user)

    assert_response :unprocessable_entity
    assert_equal [ "is not a recognised parameter" ], @response.parsed_body.dig("errors", "column_id")
  end

  test "every unknown filter is named, not just the first" do
    get cards_path(format: :json, nope: 1, nah: 2), headers: bearer_headers_for(@user)

    assert_response :unprocessable_entity
    assert_equal %w[ nah nope ], @response.parsed_body["errors"].keys.sort
  end

  # A mistyped search parameter fails the other way — an empty result reads as "nothing
  # found" rather than "you asked the wrong question".
  # Each endpoint is held to its own contract, not the union of everyone's.
  test "a filter that belongs to another endpoint is not accepted here" do
    headers = bearer_headers_for(@user)

    get search_path(format: :json, q: "layout", column_ids: [ columns(:writebook_doing).id ]), headers: headers
    assert_response :unprocessable_entity

    get cards_path(format: :json, q: "layout"), headers: headers
    assert_response :unprocessable_entity
  end

  test "the indexes that take no filters are strict too" do
    headers = bearer_headers_for(@user)

    [ board_card_notes_path(cards(:logo).board, cards(:logo), format: :json, pagee: 3),
      board_card_notes_path(cards(:logo).board, cards(:logo), format: :json, complete: true) ].each do |path|
      get path, headers: headers

      assert_response :unprocessable_entity, "#{path} should refuse a parameter it does not answer to"
    end
  end

  test "an unknown parameter on search is refused too" do
    get search_path(format: :json, query: "layout"), headers: bearer_headers_for(@user)

    assert_response :unprocessable_entity
    assert_equal [ "is not a recognised parameter" ], @response.parsed_body.dig("errors", "query")
  end

  test "the filters that do exist are still accepted" do
    get cards_path(format: :json, column_ids: [ columns(:writebook_doing).id ], sorted_by: "oldest", page: 1),
      headers: bearer_headers_for(@user)

    assert_response :success
  end

  # The browser sends assorted form and Turbo params; a person can't act on a 422 anyway.
  test "an unknown param is still tolerated on HTML" do
    sign_in_as @user

    get cards_path(nope: 1)

    assert_response :success
  end

  # Card numbers run per board

  test "each board numbers its own cards, so a number needs a board to address a card" do
    writebook, private_board = boards(:writebook), boards(:private)
    headers = bearer_headers_for(@user)

    [ writebook, private_board ].each do |board|
      post board_cards_path(board, format: :json),
        params: { title: "First on #{board.name}", due_on: 1.week.from_now.to_date },
        headers: headers, as: :json

      assert_response :created
    end

    assert_equal 1, private_board.cards.count
    assert_equal 1, private_board.cards.sole.number

    get board_card_path(private_board, 1, format: :json), headers: headers
    assert_response :success
    assert_equal "First on Private board", @response.parsed_body["title"]

    get board_card_path(writebook, 1, format: :json), headers: headers
    assert_response :success
    assert_equal cards(:logo).title, @response.parsed_body["title"],
      "The same number on another board must address that board's card"
  end

  test "a board's card index answers for that board alone" do
    headers = bearer_headers_for(@user)
    elsewhere = published_card_on(boards(:private), "Elsewhere")

    get board_cards_path(boards(:writebook), format: :json), headers: headers

    assert_response :success
    assert_equal [ boards(:writebook).id ],
      @response.parsed_body["data"].pluck("board").pluck("id").uniq
    # Numbers run per board, so both boards hold a card 1 — the title is what distinguishes them.
    assert_not_includes @response.parsed_body["data"].pluck("title"), elsewhere.title
    assert_equal boards(:writebook).cards.published.count, @response.parsed_body["paging"]["total"]
  end

  test "a board's card index still honours filters, narrowed to that board" do
    headers = bearer_headers_for(@user)
    cards(:logo).gild
    published_card_on(boards(:private), "Golden elsewhere").gild

    get board_cards_path(boards(:writebook), format: :json, indexed_by: "golden"), headers: headers

    assert_response :success
    assert_equal [ cards(:logo).number ], @response.parsed_body["data"].pluck("number")
  end

  test "the top-level card index still spans every board" do
    published_card_on(boards(:private), "Elsewhere")

    get cards_path(format: :json), headers: bearer_headers_for(@user)

    assert_response :success
    assert_equal [ boards(:private).id, boards(:writebook).id ].sort,
      @response.parsed_body["data"].pluck("board").pluck("id").uniq.sort
  end

  # Filter#boards is a HABTM, so a careless board_ids= would write join rows and permanently
  # re-scope whatever saved filter the request happened to match.
  test "a board's card index leaves a saved filter alone" do
    Current.user = @user
    filter = Current.user.filters.remember(indexed_by: "golden")

    get board_cards_path(boards(:writebook), format: :json, indexed_by: "golden"),
      headers: bearer_headers_for(@user)

    assert_response :success
    assert_equal filter, Current.user.filters.from_params(indexed_by: "golden"),
      "The request must match the saved filter, or this test proves nothing"
    # Re-find rather than reload: Filter#boards memoizes into @boards, which reload keeps.
    assert_empty Filter.find(filter.id).boards, "A GET must not rewrite a saved filter's boards"
  end

  test "a blank board_id leaves the card where it is" do
    card = cards(:logo)

    put board_card_path(card.board, card, format: :json),
      params: { title: "Renamed", board_id: "" }, headers: bearer_headers_for(@user), as: :json

    assert_response :success
    assert_equal boards(:writebook), card.reload.board
    assert_equal "Renamed", card.title
  end

  # board_id is client-supplied now that moving a card is editing it, so it has to be
  # resolved through the caller's own boards.
  test "a card cannot be moved onto another account's board" do
    card = cards(:logo)
    foreign = boards(:miltons_wish_list)
    assert_not_equal card.board.account, foreign.account

    put board_card_path(card.board, card, format: :json),
      params: { board_id: foreign.id }, headers: bearer_headers_for(@user), as: :json

    assert_response :not_found
    assert_equal boards(:writebook), card.reload.board
  end

  test "a card moving to a board already using its number is renumbered, not rejected" do
    card, destination = cards(:logo), boards(:private)
    Current.user = @user
    destination.cards.create!(title: "Already number one", due_on: 1.week.from_now,
      status: "published", creator: @user, last_active_at: Time.current)

    put board_card_path(card.board, card, format: :json),
      params: { board_id: destination.id }, headers: bearer_headers_for(@user), as: :json

    assert_response :success
    assert_equal destination, card.reload.board
    assert_equal 2, card.number
  end

  test "a card moving to another board is renumbered there" do
    card, destination = cards(:logo), boards(:private)

    put board_card_path(card.board, card, format: :json),
      params: { board_id: destination.id }, headers: bearer_headers_for(@user), as: :json

    assert_response :success
    assert_equal destination, card.reload.board
    assert_equal 1, card.number, "The first card to land on an empty board is its number 1"
  end

  test "search jumps to a card by number only while one board answers to it" do
    headers = bearer_headers_for(@user)

    get search_path(format: :json, q: cards(:logo).number.to_s), headers: headers
    assert_response :success
    assert_equal [ cards(:logo).number ], @response.parsed_body["data"].pluck("number")

    Current.user = @user
    boards(:private).cards.create!(title: "Also number one", due_on: 1.week.from_now,
      status: "published", creator: @user, last_active_at: Time.current)

    get search_path(format: :json, q: "1"), headers: headers
    assert_response :success
  end

  # Goldness

  test "goldness round-trips through the JSON API" do
    card, headers = cards(:text), bearer_headers_for(@user)

    put board_card_path(card.board, card, format: :json),
      params: { golden: true }, headers: headers, as: :json
    assert_response :success
    assert @response.parsed_body["golden"]

    put board_card_path(card.board, card, format: :json),
      params: { golden: false }, headers: headers, as: :json
    assert_not @response.parsed_body["golden"]

    get board_card_path(card.board, card, format: :json), headers: headers
    assert_not @response.parsed_body["golden"]
  end

  # A card is read in one request: its steps and the tail of its note log come with it.
  test "a card carries the tail of its note log" do
    card, headers = cards(:logo), bearer_headers_for(@user)
    limit = Card::Notable::EMBEDDED_NOTES_LIMIT

    (limit + 3).times { |i| card.notes.create!(body: "Note #{i}", creator: @user) }

    get board_card_path(card.board, card, format: :json), headers: headers

    assert_response :success
    notes = @response.parsed_body["notes"]
    assert_equal limit, notes.size
    assert_equal "Note 3", notes.first.dig("body", "plain_text")
    assert_equal "Note #{limit + 2}", notes.last.dig("body", "plain_text")
    assert @response.parsed_body["notes_truncated"]

    # And the whole log is a page away, at the url the card names.
    get @response.parsed_body["notes_url"], headers: headers, as: :json
    assert_response :success
    assert_operator @response.parsed_body["data"].size, :>, 0
    assert @response.parsed_body["paging"].key?("next")
  end

  test "a card whose notes all fit is not marked truncated" do
    card, headers = cards(:logo), bearer_headers_for(@user)
    assert_operator card.notes.count, :<, Card::Notable::EMBEDDED_NOTES_LIMIT

    get board_card_path(card.board, card, format: :json), headers: headers

    assert_equal card.notes.count, @response.parsed_body["notes"].size
    assert_not @response.parsed_body["notes_truncated"]
  end

  # column_id is the single source of a card's lifecycle, so moving lanes has to leave the
  # same audit trail whichever door it comes through.
  test "moving a card between lanes by updating it records the triage" do
    card, headers = cards(:logo), bearer_headers_for(@user)
    done = card.board.columns.find_by!(name: "Done")

    assert_difference -> { card.events.where(action: "card_triaged").count }, +1 do
      put board_card_path(card.board, card, format: :json),
        params: { column_id: done.id }, headers: headers, as: :json
    end

    assert_response :success
    assert_equal "Done", @response.parsed_body["column"]["name"]
    assert card.reload.closed?
    assert_equal({ "column" => "Done" }, card.events.where(action: "card_triaged").last.particulars)
  end

  private
    def published_card_on(board, title)
      Current.user = @user
      board.cards.create!(title: title, due_on: 1.week.from_now, status: "published",
        creator: @user, last_active_at: Time.current)
    end

    def raw_token_for(user)
      bearer_headers_for(user)["Authorization"].delete_prefix("Bearer ")
    end

    def assert_error_envelope(key)
      errors = @response.parsed_body["errors"]

      assert errors.is_a?(Hash), "Expected an errors object, got #{@response.parsed_body.inspect}"
      assert errors[key].is_a?(Array), "Expected errors[#{key.inspect}] to be an array of messages"
      assert errors[key].all?(&:present?), "Expected every message to say something"
    end
end
