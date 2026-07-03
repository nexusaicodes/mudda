require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  test "authenticate with the owner password" do
    identity = identities(:david)

    untenanted do
      post session_password_path(format: :json),
        params: { email_address: identity.email_address, password: owner_password }

      assert_response :success
      assert @response.parsed_body["session_token"].present?
    end
  end

  test "logout" do
    identity = identities(:david)

    untenanted do
      assert_difference -> { identity.sessions.count }, +1 do
        post session_password_path(format: :json),
          params: { email_address: identity.email_address, password: owner_password }
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
