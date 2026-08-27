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

    get card_path(card)
    assert_redirected_to new_session_path

    post session_password_path, params: {
      email_address: identities(:kevin).email_address, password: owner_password
    }

    assert_redirected_to card_url(card)
  end

  # An identity whose users are gone has no account to enter. Without terminating the
  # session here, the sign-in page would bounce an authenticated identity to root and
  # root would bounce it back — forever.
  test "an identity with no user is signed out rather than looping" do
    sign_in_as :kevin
    identities(:kevin).users.delete_all

    get cards_path

    assert_redirected_to new_session_path
    assert_not cookies[:session_token].present?

    follow_redirect!
    assert_response :success
  end
end
