require "test_helper"

class OwnerPasswordTest < ActiveSupport::TestCase
  test "configured? reflects the env secret" do
    assert OwnerPassword.configured?
  end

  test "enabled? when a secret is configured" do
    assert OwnerPassword.enabled?
  end

  test "authenticate returns the identity for a correct password" do
    identity = identities(:david)
    assert_equal identity, OwnerPassword.authenticate(identity.email_address, owner_password)
  end

  test "authenticate still succeeds once a passkey exists" do
    identity = identities(:david)
    create_passkey_for identity
    assert_equal identity, OwnerPassword.authenticate(identity.email_address, owner_password)
  end

  test "authenticate is nil for a wrong password" do
    assert_nil OwnerPassword.authenticate(identities(:david).email_address, "not-the-password")
  end

  test "authenticate is nil for an unknown email" do
    assert_nil OwnerPassword.authenticate("stranger@example.com", owner_password)
  end

  private
    def create_passkey_for(identity)
      identity.passkeys.create!(
        credential_id: SecureRandom.base64(32),
        public_key: SessionTestHelper::DUMMY_PASSKEY_PUBLIC_KEY,
        sign_count: 0
      )
    end
end
