require "test_helper"

class My::TokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index lists the user's tokens" do
    users(:kevin).sessions.create!(kind: :token, label: "claude")

    get my_tokens_path

    assert_response :success
    assert_select "li.credential", text: /claude/
  end

  test "minting shows the token once, with the scopes chosen" do
    assert_difference -> { users(:kevin).sessions.token.count } do
      post my_tokens_path, params: { token: { label: "cursor", scopes: [ "", "read", "delete" ] } }
    end

    assert_response :created
    token = users(:kevin).sessions.token.find_by!(label: "cursor")
    assert_equal %w[ read delete ], token.scopes

    presented = css_select("input[name=token]").first["value"]
    assert_equal token, Session.token.find_signed(presented)
  end

  test "minting with no scope ticked is refused rather than granted the defaults" do
    assert_no_difference -> { Session.token.count } do
      post my_tokens_path, params: { token: { label: "cursor", scopes: [ "" ] } }
    end

    assert_response :unprocessable_entity
    assert_select "p.txt-negative", text: /at least one/
  end

  test "minting without a name is refused" do
    post my_tokens_path, params: { token: { label: "", scopes: [ "read" ] } }

    assert_response :unprocessable_entity
  end

  test "minting with no scope ticked and no name points out both" do
    post my_tokens_path, params: { token: { label: "", scopes: [ "" ] } }

    assert_response :unprocessable_entity
    assert_match "Choose at least one thing", @response.body
    assert_match "Label can", @response.body
  end

  test "revoking a token ends it" do
    token = users(:kevin).sessions.create!(kind: :token, label: "claude")

    delete my_token_path(token)

    assert_redirected_to my_tokens_path
    assert_not Session.exists?(token.id)
  end

  test "another user's token, or a browser session, can't be revoked here" do
    other = users(:david).sessions.create!(kind: :token, label: "claude")

    delete my_token_path(other)
    assert_response :not_found

    delete my_token_path(users(:kevin).sessions.browser.first)
    assert_response :not_found
  end

  test "a token can't manage tokens" do
    headers = bearer_headers_for(:kevin)

    get my_tokens_path, headers: headers
    assert_response :forbidden

    assert_no_difference -> { Session.token.count } do
      post my_tokens_path, params: { token: { label: "escalated", scopes: Session::SCOPES } }, headers: headers
    end
    assert_response :forbidden
  end
end
