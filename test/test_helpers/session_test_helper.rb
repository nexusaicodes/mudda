module SessionTestHelper
  # A throwaway EC public key so passkeys injected by the helper look real enough to satisfy the
  # enrollment gate. These passkeys are never used for an actual WebAuthn assertion in tests.
  DUMMY_PASSKEY_PUBLIC_KEY = OpenSSL::PKey::EC.generate("prime256v1").public_to_der

  def parsed_cookies
    ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
  end

  # Signs in via the day-0 password flow, then enrolls a passkey so the forced-enrollment gate is
  # satisfied for the rest of the test. Accepts an Identity, a User, or a fixture label.
  def sign_in_as(identity)
    identity = resolve_identity(identity)
    password_sign_in identity
    enroll_passkey_for identity
    identity
  end

  # Signs in without enrolling a passkey — for exercising the passkey-enrollment gate itself.
  def sign_in_without_passkey(identity)
    password_sign_in resolve_identity(identity)
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

  def with_multi_tenant_mode(enabled)
    previous = Account.multi_tenant
    Account.multi_tenant = enabled
    yield
  ensure
    Account.multi_tenant = previous
  end

  private
    def password_sign_in(identity)
      cookies.delete :session_token
      ActionPack::Passkey.delete_all # ensure day-0 so bootstrap password login is enabled

      untenanted do
        post session_password_path, params: { email_address: identity.email_address, password: owner_password }
      end

      assert_response :redirect, "Posting the owner password should grant access"
      assert_not_nil cookies.get_cookie("session_token"), "Expected session_token cookie to be set after sign in"
    end

    def enroll_passkey_for(identity)
      identity.passkeys.create!(
        credential_id: SecureRandom.base64(32),
        public_key: DUMMY_PASSKEY_PUBLIC_KEY,
        sign_count: 0,
        transports: [ "internal" ]
      )
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
