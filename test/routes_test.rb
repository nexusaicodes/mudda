require "test_helper"

class RouteTest < ActionDispatch::IntegrationTest
  test "account/upgrade" do
    assert_recognizes({ controller: "account/upgrades", action: "show" }, "/account/upgrade")
  end
end
