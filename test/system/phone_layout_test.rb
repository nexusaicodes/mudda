require "application_system_test_case"

class PhoneLayoutTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:david))
    on_a_phone
  end

  teardown do
    back_on_a_desktop
  end

  test "the profile fits a phone, in English and in Arabic" do
    visit user_url(users(:david))
    assert_selector ".preference-choice__option", count: 2
    assert_no_horizontal_scroll

    click_on "العربية"
    assert_selector "html[dir=rtl]"
    assert_no_horizontal_scroll
  end

  test "the boards list and a board fit a phone" do
    visit root_url
    assert_link "New board"
    assert_no_horizontal_scroll

    visit board_url(boards(:writebook))
    assert_selector ".due-toggle"
    assert_no_horizontal_scroll
  end

  test "the avatar opens the profile, which signs out" do
    find(".account-link").click
    click_on "Sign out of Mudda on this device"

    assert_current_path new_session_path
  end
end
