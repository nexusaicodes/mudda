require "test_helper"

class Account::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get account_settings_path
    assert_response :success
    assert_select "h2", text: "Plan", count: 0
  end

  test "under a card limit, show says how many cards are used and links to upgrading" do
    with_env("MUDDA_CARD_LIMIT" => "100", "MUDDA_UPGRADE_URL" => "https://mudda.example/upgrade/new?token=signed") do
      get account_settings_path
    end

    assert_select "h2", text: "Plan"
    assert_select "p", /#{accounts("37s").cards_created_count} cards? of 100 used/
    assert_select "a[href=?]", account_upgrade_path, text: "Upgrade for unlimited cards"
  end

  test "under a card limit with nowhere to upgrade, show has no upgrade link" do
    with_env("MUDDA_CARD_LIMIT" => "100", "MUDDA_UPGRADE_URL" => nil) { get account_settings_path }

    assert_select "h2", text: "Plan"
    assert_select "a[href=?]", account_upgrade_path, count: 0
  end

  test "update" do
    put account_settings_path, params: { account: { name: "New Account Name" } }
    assert_equal "New Account Name", Current.account.reload.name
    assert_redirected_to account_settings_path
  end

  test "update as JSON" do
    put account_settings_path, params: { account: { name: "New Account Name" } }, as: :json

    assert_response :no_content
    assert_equal "New Account Name", Current.account.reload.name
  end

  test "show as JSON" do
    get account_settings_path, as: :json

    assert_response :success
    assert_equal Current.account.name, @response.parsed_body["name"]
    assert_equal Current.account.id, @response.parsed_body["id"]
  end
end
