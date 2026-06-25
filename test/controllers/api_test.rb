require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  test "authenticate with user credentials" do
    identity = identities(:david)

    untenanted do
      post session_path(format: :json), params: { email_address: identity.email_address }
      assert_response :created
      pending_token = @response.parsed_body["pending_authentication_token"]
      assert pending_token.present?

      magic_link = MagicLink.last
      post session_magic_link_path(format: :json), params: { code: magic_link.code, pending_authentication_token: pending_token }
      assert_response :success
      assert @response.parsed_body["session_token"].present?
    end
  end

  test "logout with user credentials" do
    identity = identities(:david)

    untenanted do
      post session_path(format: :json), params: { email_address: identity.email_address }
      magic_link = MagicLink.last

      assert_difference -> { identity.sessions.count }, +1 do
        post session_magic_link_path(format: :json), params: { code: magic_link.code, pending_authentication_token: @response.parsed_body["pending_authentication_token"] }
      end
      assert cookies[:session_token].present?

      assert_difference -> { identity.sessions.count }, -1 do
        delete session_path(format: :json)
      end
      assert_response :no_content
      assert_not cookies[:session_token].present?
    end
  end
end
