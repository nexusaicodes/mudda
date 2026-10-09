require "test_helper"

class Account::UpgradesControllerTest < ActionDispatch::IntegrationTest
  UPGRADE_URL = "https://mudda.example/upgrade/new?token=signed"

  test "a signed-in owner is handed to the platform's upgrade page" do
    sign_in_as :kevin

    with_env("MUDDA_UPGRADE_URL" => UPGRADE_URL) { get account_upgrade_path }

    assert_redirected_to UPGRADE_URL
  end

  test "the billing they picked is passed on, and anything else is dropped" do
    sign_in_as :kevin

    with_env("MUDDA_UPGRADE_URL" => UPGRADE_URL) { get account_upgrade_path(billing: "monthly") }
    assert_redirected_to "#{UPGRADE_URL}&billing=monthly"

    with_env("MUDDA_UPGRADE_URL" => UPGRADE_URL) { get account_upgrade_path(billing: "weekly") }
    assert_redirected_to UPGRADE_URL
  end

  test "a signed-out visitor signs in first, then comes back here" do
    with_env("MUDDA_UPGRADE_URL" => UPGRADE_URL) { get account_upgrade_path(billing: "monthly") }

    assert_redirected_to new_session_path
    assert_equal account_upgrade_url(billing: "monthly"), session[:return_to_after_authenticating]
  end

  test "a board with no upgrade URL already has unlimited cards" do
    sign_in_as :kevin

    with_env("MUDDA_UPGRADE_URL" => nil) { get account_upgrade_path }

    assert_redirected_to root_path
    assert_equal "This board already has unlimited cards", flash[:notice]
  end
end
