require "test_helper"

class Account::UpgradesControllerTest < ActionDispatch::IntegrationTest
  UPGRADE_URL = "https://mudda.example/upgrade/new?token=signed"

  test "a signed-in owner is handed to the platform's upgrade page" do
    sign_in_as :david

    on_the_free_plan(upgrade_url: UPGRADE_URL) { get account_upgrade_path }

    assert_redirected_to UPGRADE_URL
  end

  test "the billing they picked is passed on, and anything else is dropped" do
    sign_in_as :david

    on_the_free_plan(upgrade_url: UPGRADE_URL) { get account_upgrade_path(billing: "monthly") }
    assert_redirected_to "#{UPGRADE_URL}&billing=monthly"

    on_the_free_plan(upgrade_url: UPGRADE_URL) { get account_upgrade_path(billing: "weekly") }
    assert_redirected_to UPGRADE_URL
  end

  test "a signed-out visitor signs in first, then comes back here" do
    on_the_free_plan(upgrade_url: UPGRADE_URL) { get account_upgrade_path(billing: "monthly") }

    assert_redirected_to new_session_path
    assert_equal account_upgrade_url(billing: "monthly"), session[:return_to_after_authenticating]
  end

  test "with no upgrade URL and no ceiling, the account already has unlimited cards" do
    sign_in_as :david

    with_env("MUDDA_PLATFORM_KEYS" => nil) { get account_upgrade_path }

    assert_redirected_to root_path
    assert_equal "This account already has unlimited cards", flash[:notice]
  end

  test "with no upgrade URL under a ceiling, there is no upgrade to offer" do
    sign_in_as :david

    on_the_free_plan { get account_upgrade_path }

    assert_redirected_to root_path
    assert_equal "Upgrades aren't available here", flash[:notice]
  end
end
