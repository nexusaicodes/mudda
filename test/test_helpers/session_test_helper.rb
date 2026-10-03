module SessionTestHelper
  # A throwaway EC public key so passkeys injected by tests look real enough. These passkeys are
  # never used for an actual WebAuthn assertion in tests.
  DUMMY_PASSKEY_PUBLIC_KEY = OpenSSL::PKey::EC.generate("prime256v1").public_to_der

  def parsed_cookies
    ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
  end

  # Signs in via the owner password. Accepts a User or a fixture label.
  def sign_in_as(user)
    user = resolve_user(user)
    password_sign_in user
    user
  end

  def logout_and_sign_in_as(user)
    ActionPack::Passkey.delete_all
    Session.delete_all
    sign_in_as user
  end

  # The credential a non-browser client presents. Mirrors what POST /session/password.json
  # hands back and what bin/rails auth:token prints. The label is unique per call because a
  # label holds one live token — a shared default would have two tokens in one test revoke
  # each other.
  def bearer_headers_for(user, label: "test-#{SecureRandom.hex(4)}")
    session = resolve_user(user).sessions.create!(kind: :token, label: label)

    { "Authorization" => "Bearer #{session.token}" }
  end

  def sign_out
    delete session_path

    assert_not cookies[:session_token].present?
  end

  private
    def password_sign_in(user)
      cookies.delete :session_token

      post session_password_path, params: { email_address: user.email_address, password: owner_password }

      assert_response :redirect, "Posting the owner password should grant access"
      assert_not_nil cookies.get_cookie("session_token"), "Expected session_token cookie to be set after sign in"
    end

    def resolve_user(user)
      user.is_a?(User) ? user : users(user)
    end

    def owner_password
      ENV.fetch("MUDDA_OWNER_PASSWORD")
    end
end
