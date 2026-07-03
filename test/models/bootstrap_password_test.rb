require "test_helper"

class BootstrapPasswordTest < ActiveSupport::TestCase
  setup do
    ActionPack::Passkey.delete_all
  end

  test "configured? reflects the env secret" do
    assert BootstrapPassword.configured?
  end

  test "enabled? when configured and no passkey exists" do
    assert BootstrapPassword.enabled?
  end

  test "enabled? is false once any passkey exists" do
    create_passkey_for identities(:david)
    assert_not BootstrapPassword.enabled?
  end

  test "authenticate returns the identity for a correct password" do
    identity = identities(:david)
    assert_equal identity, BootstrapPassword.authenticate(identity.email_address, owner_password)
  end

  test "authenticate is nil for a wrong password" do
    assert_nil BootstrapPassword.authenticate(identities(:david).email_address, "not-the-password")
  end

  test "authenticate is nil for an unknown email" do
    assert_nil BootstrapPassword.authenticate("stranger@example.com", owner_password)
  end

  test "authenticate is nil once a passkey exists, even with the correct password" do
    identity = identities(:david)
    create_passkey_for identity
    assert_nil BootstrapPassword.authenticate(identity.email_address, owner_password)
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
