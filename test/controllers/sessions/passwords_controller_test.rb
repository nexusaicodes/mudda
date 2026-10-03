require "test_helper"

class Sessions::PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "sign in with the owner password" do
    user = users(:david)

    post session_password_path, params: { email_address: user.email_address, password: owner_password }

    assert_response :redirect
    assert cookies[:session_token].present?
  end

  test "reject a wrong password" do
    post session_password_path, params: { email_address: users(:david).email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_not cookies[:session_token].present?
  end

  test "password sign-in still works once a passkey exists" do
    create_passkey_for users(:david)

    post session_password_path, params: { email_address: users(:david).email_address, password: owner_password }

    assert_response :redirect
    assert cookies[:session_token].present?
  end

  private
    def create_passkey_for(user)
      user.passkeys.create!(
        credential_id: SecureRandom.base64(32),
        public_key: SessionTestHelper::DUMMY_PASSKEY_PUBLIC_KEY,
        sign_count: 0
      )
    end
end
