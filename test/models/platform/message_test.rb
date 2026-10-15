require "test_helper"

class Platform::MessageTest < ActiveSupport::TestCase
  setup do
    @account = accounts("37s")
  end

  test "disabled without keys" do
    with_env("MUDDA_PLATFORM_KEYS" => nil) { assert_not Platform::Message.enabled? }
  end

  test "a plan names the plan and the upgrade URL" do
    trusting_the_platform do
      apply platform_message("plan.updated", { plan: "free", upgrade_url: "https://mudda.today/upgrade?t=x" })

      @account.reload
      assert_equal [ "free", 100 ], [ @account.current_plan, @account.card_limit ]
      assert_equal "https://mudda.today/upgrade?t=x", @account.upgrade_url
      assert_equal 1, @account.platform_seq
    end
  end

  test "premium lifts the ceiling" do
    trusting_the_platform do
      apply platform_message("plan.updated", { plan: "premium", upgrade_url: nil })
      assert_not @account.reload.card_limited?
    end
  end

  test "sync.configured sets where the board's webhooks go" do
    trusting_the_platform do
      apply platform_message("sync.configured", { webhook_url: "https://mudda.today/webhooks/boards/7", webhook_secret: "s" * 64 })
      assert_equal "https://mudda.today/webhooks/boards/7", @account.reload.webhook_url

      assert_refused "bad webhook URL", platform_message("sync.configured", { webhook_url: "http://x.example", webhook_secret: "s" * 64 }, seq: 2)
      assert_refused "bad webhook secret", platform_message("sync.configured", { webhook_url: "https://x.example", webhook_secret: "short" }, seq: 2)
    end
  end

  test "an older or repeated message changes nothing" do
    trusting_the_platform do
      apply platform_message("plan.updated", { plan: "premium" }, seq: 5)
      apply platform_message("plan.updated", { plan: "free" }, seq: 4)
      apply platform_message("plan.updated", { plan: "free" }, seq: 5)

      assert_equal [ "premium", 5 ], @account.reload.values_at(:plan, :platform_seq)
    end
  end

  test "refuses what isn't signed by a trusted key, addressed here, and fresh" do
    trusting_the_platform do
      stranger = OpenSSL::PKey.generate_key("ED25519")

      assert_refused "bad signature", platform_message("plan.updated", key: stranger)
      assert_refused "unknown key", platform_message("plan.updated", kid: "k9")
      assert_refused "wrong audience", platform_message("plan.updated", aud: "other.example.com")
      assert_refused "expired", platform_message("plan.updated", iat: 10.minutes.ago.to_i)
      assert_refused "expired", platform_message("plan.updated", exp: Time.current.to_i + 1.hour.to_i)
      assert_refused "expired", platform_message("plan.updated", iat: 5.minutes.from_now.to_i)
      assert_refused "malformed", "not-a-message"
      assert_refused "too large", "x" * 9.kilobytes
    end
  end

  test "a tampered message is refused" do
    trusting_the_platform do
      claims, signature = platform_message("plan.updated", { plan: "free" }).split(".")
      forged = Base64.urlsafe_encode64(JSON.parse(Base64.urlsafe_decode64(claims)).merge("payload" => { "plan" => "premium" }).to_json, padding: false)

      assert_refused "bad signature", "#{forged}.#{signature}"
    end
  end

  test "refuses a payload that names an email, however deep" do
    trusting_the_platform do
      assert_refused "email can't be changed", platform_message("name.updated", { name: "X", email: "a@b.c" })
      assert_refused "email can't be changed", platform_message("plan.updated", { extra: [ { Email_Address: "a@b.c" } ] })
    end
  end

  test "refuses a bad plan" do
    trusting_the_platform do
      assert_refused "unknown plan", platform_message("plan.updated", { plan: "enterprise" })
      assert_refused "unknown plan", platform_message("plan.updated", { card_limit: 50 })
      assert_refused "bad upgrade URL", platform_message("plan.updated", { plan: "free", upgrade_url: "http://insecure.example.com" })
      assert_refused "bad upgrade URL", platform_message("plan.updated", { plan: "free", upgrade_url: "javascript:alert(1)" })
    end
  end

  test "a newer name from the platform is applied and not sent back" do
    owner = @account.users.order(:id).first
    owner.update_columns name_changed_at: 1.hour.ago

    trusting_the_platform do
      with_platform_webhooks(@account) do
        assert_no_difference -> { WebhookDelivery.count } do
          apply platform_message("name.updated", { name: "Renamed", name_changed_at: Time.current.iso8601(6) })
        end
      end
    end

    assert_equal "Renamed", owner.reload.name
  end

  test "an older name from the platform, or one changed at the same moment, is ignored" do
    owner = @account.users.order(:id).first
    changed_at = Time.current.change(usec: 0)
    owner.update_columns name: "Kept", name_changed_at: changed_at

    trusting_the_platform do
      apply platform_message("name.updated", { name: "Older", name_changed_at: 1.hour.ago.iso8601(6) }, seq: 1)
      apply platform_message("name.updated", { name: "Tied", name_changed_at: changed_at.iso8601(6) }, seq: 2)
    end

    assert_equal "Kept", owner.reload.name
  end

  test "a name the board can't take is refused and uses up nothing" do
    trusting_the_platform do
      assert_refused "bad name", platform_message("name.updated", { name: "", name_changed_at: Time.current.iso8601(6) })
      assert_refused "bad name_changed_at", platform_message("name.updated", { name: "X", name_changed_at: "soon" })
    end

    assert_equal 0, @account.reload.platform_seq
  end

  test "a state request answers without using up a sequence number" do
    trusting_the_platform do
      state = apply platform_message("state.requested", seq: 3)

      assert_equal @account.users.order(:id).first.email_address, state[:email]
      assert_equal 0, state[:platform_seq]
      assert_equal [ nil, false ], state.values_at(:plan, :webhook_configured)
      assert_equal 0, @account.reload.platform_seq
    end
  end

  test "password.set stores the hash and signs out every browser" do
    owner = @account.users.order(:id).first
    browser = owner.sessions.create!
    token = owner.sessions.create!(kind: :token, label: "agent", scopes: "read")
    digest = BCrypt::Password.create("reset-password", cost: BCrypt::Engine::MIN_COST).to_s

    trusting_the_platform do
      apply platform_message("password.set", { password_digest: digest })
    end

    assert_equal owner, OwnerPassword.authenticate(owner.email_address, "reset-password")
    assert_nil OwnerPassword.authenticate(owner.email_address, owner_password)
    assert_not Session.exists?(browser.id)
    assert Session.exists?(token.id)
    assert_equal 1, @account.reload.platform_seq
  end

  test "password.set refuses anything but a bcrypt hash" do
    trusting_the_platform do
      assert_refused "bad password digest", platform_message("password.set", { password_digest: "plaintext-password" })
      assert_refused "bad password digest", platform_message("password.set", {})
    end
    assert_nil @account.users.order(:id).first.password_digest
  end

  test "password.set at an old sequence number changes nothing" do
    digest = BCrypt::Password.create("reset-password", cost: BCrypt::Engine::MIN_COST).to_s

    trusting_the_platform do
      apply platform_message("name.updated", { name: "Ada", name_changed_at: Time.current.iso8601(6) }, seq: 2)
      apply platform_message("password.set", { password_digest: digest }, seq: 2)
    end
    assert_nil @account.users.order(:id).first.reload.password_digest
  end

  private
    def apply(token)
      Platform::Message.verify(token, host: Platform::Message.audience).apply(@account)
    end

    def assert_refused(reason, token)
      error = assert_raises(Platform::Message::Invalid) { apply(token) }
      assert_equal reason, error.message
    end
end
