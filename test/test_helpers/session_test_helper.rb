module SessionTestHelper
  # A throwaway EC public key so passkeys injected by tests look real enough. These passkeys are
  # never used for an actual WebAuthn assertion in tests.
  DUMMY_PASSKEY_PUBLIC_KEY = OpenSSL::PKey::EC.generate("prime256v1").public_to_der

  def parsed_cookies
    ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
  end

  # Signs in via the owner password. Accepts an Identity, a User, or a fixture label.
  def sign_in_as(identity)
    identity = resolve_identity(identity)
    password_sign_in identity
    identity
  end

  def logout_and_sign_in_as(identity)
    ActionPack::Passkey.delete_all
    Session.delete_all
    sign_in_as identity
  end

  def sign_out
    untenanted do
      delete session_path
    end
    assert_not cookies[:session_token].present?
  end

  def with_current_user(user)
    user = users(user) unless user.is_a? User
    @old_session = Current.session
    begin
      Current.session = Session.new(identity: user.identity)
      yield
    ensure
      Current.session = @old_session
    end
  end

  def untenanted(&block)
    original_script_name = integration_session.default_url_options[:script_name]
    integration_session.default_url_options[:script_name] = ""
    yield
  ensure
    integration_session.default_url_options[:script_name] = original_script_name
  end

  private
    def password_sign_in(identity)
      cookies.delete :session_token

      untenanted do
        post session_password_path, params: { email_address: identity.email_address, password: owner_password }
      end

      assert_response :redirect, "Posting the owner password should grant access"
      assert_not_nil cookies.get_cookie("session_token"), "Expected session_token cookie to be set after sign in"
    end

    def resolve_identity(identity)
      case identity
      when User then identity.identity or raise "User #{identity.name} (#{identity.id}) has no identity"
      when Identity then identity
      else identities(identity)
      end
    end

    def owner_password
      ENV.fetch("MUDDA_OWNER_PASSWORD")
    end
end
