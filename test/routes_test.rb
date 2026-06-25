require "test_helper"

class RouteTest < ActionDispatch::IntegrationTest
  test "account/settings" do
    assert_recognizes({ controller: "account/settings", action: "show" }, "/account/settings")
  end
end
