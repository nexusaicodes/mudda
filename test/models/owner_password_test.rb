require "test_helper"

class OwnerPasswordTest < ActiveSupport::TestCase
  test "configured? reflects the env secret" do
    assert OwnerPassword.configured?
  end

  test "enabled? when a secret is configured" do
    assert OwnerPassword.enabled?
  end

  test "authenticate returns the user for a correct password" do
    user = users(:david)
    assert_equal user, OwnerPassword.authenticate(user.email_address, owner_password)
  end

  test "authenticate still succeeds once a passkey exists" do
    user = users(:david)
    create_passkey_for user
    assert_equal user, OwnerPassword.authenticate(user.email_address, owner_password)
  end

  test "authenticate is nil for a wrong password" do
    assert_nil OwnerPassword.authenticate(users(:david).email_address, "not-the-password")
  end

  test "authenticate is nil for an unknown email" do
    assert_nil OwnerPassword.authenticate("stranger@example.com", owner_password)
  end

  test "a stored password supersedes the env secret" do
    user = users(:david)
    user.update!(password: "a-new-password", password_confirmation: "a-new-password")

    assert_equal user, OwnerPassword.authenticate(user.email_address, "a-new-password")
    assert_nil OwnerPassword.authenticate(user.email_address, owner_password)
  end

  test "enabled? with a stored password and no secret" do
    users(:david).update!(password: "a-new-password")

    with_env("MUDDA_OWNER_PASSWORD" => nil) do
      assert OwnerPassword.enabled?
      assert_equal users(:david), OwnerPassword.authenticate(users(:david).email_address, "a-new-password")
    end
  end

  test "enabled? on a hosted board waiting for its password from the platform" do
    with_env("MUDDA_OWNER_PASSWORD" => nil) do
      trusting_the_platform do
        assert OwnerPassword.enabled?
        assert_nil OwnerPassword.authenticate(users(:david).email_address, "")
      end
    end
  end

  test "not enabled with neither a stored password nor a secret" do
    with_env("MUDDA_OWNER_PASSWORD" => nil) do
      assert_not OwnerPassword.enabled?
      assert_nil OwnerPassword.authenticate(users(:david).email_address, "")
    end
  end

  test "every attempt costs one bcrypt comparison, whichever email and password it names" do
    BCrypt::Password.any_instance.expects(:is_password?).times(3).returns(false)

    OwnerPassword.authenticate("stranger@example.com", owner_password)
    OwnerPassword.authenticate(users(:david).email_address, "not-the-password")

    users(:david).update_column :password_digest, BCrypt::Password.create("a-new-password", cost: BCrypt::Engine::MIN_COST)
    OwnerPassword.authenticate(users(:david).email_address, "not-the-password")
  end

  test "set_for? when the owner has a stored password or the env secret" do
    assert OwnerPassword.set_for?(users(:david))

    with_env("MUDDA_OWNER_PASSWORD" => nil) do
      assert_not OwnerPassword.set_for?(users(:david))

      users(:david).update!(password: "a-new-password")
      assert OwnerPassword.set_for?(users(:david))
    end
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
