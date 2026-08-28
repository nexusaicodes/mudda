require "application_system_test_case"

class BackLinkNavigationTest < ApplicationSystemTestCase
  test "card back link returns to board filter view when navigating from it" do
    sign_in_as(users(:david))

    filter_url = board_url(boards(:writebook), column_ids: [ columns(:writebook_triage).id ])
    visit filter_url
    click_on cards(:logo).title

    back_link = find("a.btn--back")
    assert_selector "a.btn--back strong", text: "Back to Writebook"
    back_link.click
    assert_current_path filter_url, ignore_query: false
  end

  test "card back link returns to global filter view when navigating from it" do
    sign_in_as(users(:kevin))

    filter_url = cards_url(column_ids: [ columns(:writebook_doing).id ])
    visit filter_url
    click_on cards(:text).title

    assert_selector "a.btn--back strong", text: "Back to all boards"
    find("a.btn--back").click
    assert_current_path filter_url, ignore_query: false
  end

  # Only the card indexes are worth returning to, so arriving from anywhere else — a
  # maximized lane, here — leaves the back link pointing at the card's own board.
  test "card back link is not rewritten when navigating from a non-filter page" do
    sign_in_as(users(:david))

    visit board_column_url(boards(:writebook), columns(:writebook_triage))
    click_on cards(:logo).title

    assert_selector "a.btn--back strong", text: "Back to Writebook"
  end
end
