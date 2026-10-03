require "test_helper"

class ControllerAuthenticationTest < ActionDispatch::IntegrationTest
  test "access without a session redirects to new session" do
    get cards_path

    assert_redirected_to new_session_path
  end

  test "access with a session allows functional access" do
    sign_in_as :kevin

    get cards_path

    assert_response :success
  end

  test "the requested page is remembered and returned to after signing in" do
    card = cards(:logo)

    get board_card_path(card.board, card)
    assert_redirected_to new_session_path

    post session_password_path, params: {
      email_address: users(:kevin).email_address, password: owner_password
    }

    assert_redirected_to board_card_url(card.board, card)
  end

  test "a sub-resource request is not remembered as the page to return to" do
    get cards_path(format: :png)
    assert_redirected_to new_session_path

    post session_password_path, params: {
      email_address: users(:kevin).email_address, password: owner_password
    }

    assert_redirected_to landing_url
  end

  # A deactivated owner keeps the API token they were issued: it is refused for as long as they
  # are deactivated, and works again once they are not — whatever format it asks for.
  test "a deactivated user's token is refused without being revoked" do
    headers = bearer_headers_for(:kevin)
    users(:kevin).update!(active: false)

    assert_no_difference -> { Session.count } do
      get cards_path, as: :json, headers: headers
      assert_response :forbidden

      get cards_path, headers: headers
      assert_response :forbidden
    end

    users(:kevin).update!(active: true)
    get cards_path, as: :json, headers: headers
    assert_response :success
  end

  # The session's kind decides, not the format: a browser asking for JSON is still a browser.
  test "a deactivated user's browser is signed out even when it asks for JSON" do
    sign_in_as :kevin
    users(:kevin).update!(active: false)

    assert_difference -> { users(:kevin).sessions.browser.count }, -1 do
      get cards_path, as: :json
    end

    assert_response :forbidden
    assert_not cookies[:session_token].present?
  end

  test "a deactivated user is signed out on a format the app does not render" do
    sign_in_as :kevin
    users(:kevin).update!(active: false)

    get cards_path(format: :png)

    assert_redirected_to new_session_path
    assert_not cookies[:session_token].present?
  end

  # A deactivated user has no account to enter. Without terminating the session here, the
  # sign-in page would bounce an authenticated user to root and root would bounce it back
  # — forever.
  test "a deactivated user is signed out rather than looping" do
    sign_in_as :kevin
    users(:kevin).deactivate

    get cards_path

    assert_redirected_to new_session_path
    assert_not cookies[:session_token].present?

    follow_redirect!
    assert_response :success
  end
end
