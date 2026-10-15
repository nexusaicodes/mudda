require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_session_path

    assert_response :success
  end

  test "a hosted board shows the password form before its password arrives" do
    with_env("MUDDA_OWNER_PASSWORD" => nil) do
      trusting_the_platform { get new_session_path }
    end

    assert_select "form[action=?]", session_password_path
  end

  test "new redirects authenticated users" do
    sign_in_as :kevin

    get new_session_path
    assert_redirected_to root_url
  end

  test "destroy" do
    sign_in_as :kevin

    delete session_path

    assert_redirected_to new_session_path
    assert_not cookies[:session_token].present?
  end

  test "destroy via JSON" do
    sign_in_as :kevin

    delete session_path(format: :json)

    assert_response :no_content
    assert_not cookies[:session_token].present?
  end
end
