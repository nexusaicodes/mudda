require "test_helper"

class RouteTest < ActionDispatch::IntegrationTest
  test "account/join_code" do
    assert_recognizes({ controller: "account/join_codes", action: "show" }, "/account/join_code")
  end

  test "account/settings" do
    assert_recognizes({ controller: "account/settings", action: "show" }, "/account/settings")
  end
end
