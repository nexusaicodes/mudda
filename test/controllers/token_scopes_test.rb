require "test_helper"

# A token does what its scopes grant, read off the request's verb. See API.md → Scopes.
class TokenScopesTest < ActionDispatch::IntegrationTest
  setup do
    @board = boards(:writebook)
  end

  test "a read-only token reads but can't write" do
    headers = bearer_headers_for(:david, scopes: %w[ read ])

    get boards_path(format: :json), headers: headers
    assert_response :success

    post boards_path(format: :json), params: { name: "Nope" }, headers: headers, as: :json
    assert_response :forbidden
    assert_equal [ "This token is not granted the write scope" ], @response.parsed_body.dig("errors", "base")
  end

  test "a refused write writes nothing" do
    assert_no_difference -> { Board.count } do
      post boards_path(format: :json), params: { name: "Nope" }, headers: bearer_headers_for(:david, scopes: %w[ read ]), as: :json
    end
  end

  test "a token without the delete scope can't delete" do
    headers = bearer_headers_for(:david, scopes: %w[ read write ])

    assert_no_difference -> { Card.count } do
      delete board_card_path(@board, cards(:logo), format: :json), headers: headers
    end

    assert_response :forbidden
  end

  test "a token with the delete scope deletes" do
    assert_difference -> { Card.count }, -1 do
      delete board_card_path(@board, cards(:logo), format: :json), headers: bearer_headers_for(:david, scopes: Session::SCOPES)
    end
  end

  test "any token may end its own session" do
    delete session_path(format: :json), headers: bearer_headers_for(:david, scopes: %w[ read ])

    assert_response :no_content
  end

  test "a browser session is limited by no scope" do
    sign_in_as :david

    assert_difference -> { Card.count }, -1 do
      delete board_card_path(@board, cards(:logo))
    end
  end

  test "whoami reports the token's label and scopes" do
    get my_user_path(format: :json), headers: bearer_headers_for(:david, label: "claude", scopes: %w[ read ])

    assert_equal({ "label" => "claude", "scopes" => [ "read" ] }, @response.parsed_body["token"])
  end

  test "the JSON sign-in mints the scopes asked for, and reads and writes when none are" do
    post session_password_path(format: :json),
      params: { email_address: users(:david).email_address, password: owner_password, label: "a", scopes: "read" }, as: :json
    assert_equal [ "read" ], @response.parsed_body["scopes"]

    post session_password_path(format: :json),
      params: { email_address: users(:david).email_address, password: owner_password, label: "b" }, as: :json
    assert_equal %w[ read write ], @response.parsed_body["scopes"]
  end

  test "the JSON sign-in refuses an unknown scope" do
    post session_password_path(format: :json),
      params: { email_address: users(:david).email_address, password: owner_password, scopes: "root" }, as: :json

    assert_response :unprocessable_entity
  end
end
