require "application_system_test_case"

class BoardHeaderTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:david))
    visit board_url(boards(:writebook))
  end

  test "the board's name renames it in place" do
    find(".board-title__rename").click
    fill_in "Board name", with: "Writebook launch"
    click_on "Save"

    assert_selector ".board-title__rename", text: "Writebook launch"
    assert_equal "Writebook launch", boards(:writebook).reload.name
  end

  test "Esc puts the name back untouched" do
    find(".board-title__rename").click
    fill_in "Board name", with: "Something else"
    find_field("Board name").send_keys(:escape)

    assert_selector ".board-title__rename", text: "Writebook"
    assert_equal "Writebook", boards(:writebook).reload.name
  end

  test "the switcher lists the boards and the cross-board views" do
    find(".switcher__trigger").click

    within ".switcher__menu" do
      assert_selector ".popup__item--current", text: "Writebook"
      assert_link "Due today & tomorrow"
      click_on "Doing everywhere"
    end

    assert_selector ".board-title__name", text: "Doing everywhere"
  end
end
