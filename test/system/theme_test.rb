require "application_system_test_case"

class ThemeTest < ApplicationSystemTestCase
  test "signing in from a deep link renders the owner's theme" do
    users(:david).settings.update!(theme: "dark")

    visit user_url(users(:david))
    assert_no_selector "html[data-theme]"

    fill_in "email_address", with: users(:david).email_address
    fill_in "password", with: owner_password
    find("#log_in").click

    assert_current_path user_path(users(:david))
    assert_selector "html[data-theme=dark]"
  end
end
