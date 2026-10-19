require "test_helper"

class Platform::MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts("37s")
    Account.stubs(:sole).returns(@account)
    Platform::MessagesController::RATE_LIMIT_STORE.clear
  end

  test "not there without platform keys" do
    with_env("MUDDA_PLATFORM_KEYS" => nil) do
      post platform_messages_path, params: "anything", headers: { "Content-Type" => "text/plain" }
      assert_response :not_found
    end
  end

  test "applies a signed plan" do
    trusting_the_platform do
      send_message platform_message("plan.updated", { plan: "premium", upgrade_url: nil })
      assert_response :no_content
      assert_not @account.reload.card_limited?
    end
  end

  test "answers a state request with the owner's state" do
    trusting_the_platform do
      send_message platform_message("state.requested")
      assert_response :success
      assert_equal %w[ email name name_changed_at plan platform_seq webhook_configured ], @response.parsed_body.keys.sort
    end
  end

  test "refuses a bad message, a replay, and a forged Host" do
    trusting_the_platform do
      send_message "garbage"
      assert_response :unauthorized
      assert_equal [ "malformed" ], @response.parsed_body.dig("errors", "message")

      message = platform_message("plan.updated", { plan: "premium" })
      send_message message
      assert_response :no_content
      send_message message
      assert_response :no_content
      assert_equal 1, @account.reload.platform_seq

      send_message platform_message("plan.updated", { plan: "free" }, seq: 2, aud: "evil.example.com"), host: "evil.example.com"
      assert_response :unauthorized
    end
  end

  test "a refusal is logged at warn with its reason, and a replay at debug" do
    trusting_the_platform do
      assert_event_reported("platform.message.refused", payload: { reason: "malformed" }) do
        send_message "garbage"
      end

      message = platform_message("plan.updated", { plan: "premium" })
      send_message message
      assert_event_reported("platform.message.stale", payload: { kind: "plan.updated", seq: 1 }) do
        send_message message
      end
    end
  end

  test "malformed platform keys are the board's fault: a 503 and an error, not a refusal" do
    with_env("MUDDA_PLATFORM_KEYS" => "k1:not base64!", "BASE_URL" => "https://#{PLATFORM_HOST}") do
      assert_event_reported("platform.keys.malformed") do
        send_message platform_message("plan.updated", { plan: "premium" })
      end
    end

    assert_response :service_unavailable
    assert @response.parsed_body["request_id"]
  end

  test "ignores a session or token, which can't stand in for a signature" do
    sign_in_as :david

    trusting_the_platform do
      send_message platform_message("plan.updated", { plan: "free" }, key: OpenSSL::PKey.generate_key("ED25519"))
      assert_response :unauthorized
    end
  end

  private
    def send_message(body, host: PLATFORM_HOST)
      post platform_messages_url(host: host), params: body, headers: { "Content-Type" => "application/jose" }
    end
end
