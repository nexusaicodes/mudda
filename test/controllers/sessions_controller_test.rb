require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    untenanted do
      get new_session_path
    end

    assert_response :success
  end

  test "new redirects authenticated users" do
    sign_in_as :kevin

    untenanted do
      get new_session_path
      assert_redirected_to root_url
    end
  end

  test "destroy" do
    sign_in_as :kevin

    untenanted do
      delete session_path

      assert_redirected_to new_session_path
      assert_not cookies[:session_token].present?
    end
  end

  test "destroy via JSON" do
    sign_in_as :kevin

    untenanted do
      delete session_path(format: :json)

      assert_response :no_content
      assert_not cookies[:session_token].present?
    end
  end
end
