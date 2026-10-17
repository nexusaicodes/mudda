require "application_system_test_case"

class BoardHeaderTest < ApplicationSystemTestCase
  setup do
    sign_in_as(users(:david))
    visit root_url
  end

  test "the boards list opens a board, and the logo comes back to it" do
    click_on "Writebook"

    assert_selector ".board-title__name", text: "Writebook"
    find(".header__logo").click
    assert_current_path root_path
  end

  test "a board is renamed in place on the list" do
    within("#board_#{boards(:writebook).id}") do
      click_on "Rename this board"
      fill_in "Board name", with: "Writebook launch"
      click_on "Save"
    end

    assert_link "Writebook launch"
    assert_equal "Writebook launch", boards(:writebook).reload.name
  end

  test "Esc puts the name back untouched" do
    within("#board_#{boards(:writebook).id}") do
      click_on "Rename this board"
      fill_in "Board name", with: "Something else"
      find_field("Board name").send_keys(:escape)
    end

    assert_link "Writebook"
    assert_equal "Writebook", boards(:writebook).reload.name
  end

  test "a board is deleted from the list, behind a confirmation" do
    within("#board_#{boards(:writebook).id}") { click_on "Delete this board" }
    within("dialog[open]") { click_on "Delete board" }

    assert_current_path root_path
    assert_no_link "Writebook"
    assert_not Board.exists?(boards(:writebook).id)
  end

  test "the big button creates a board" do
    click_on "New board"
    fill_in "board_name", with: "Kitchen"
    click_on "Create board"

    assert_selector ".board-title__name", text: "Kitchen"
  end

  test "the header's search button opens a search panel that searches as you type" do
    card = Current.set(session: users(:david).sessions.first) do
      boards(:writebook).cards.create!(title: "Findable launch checklist", creator: users(:david))
    end

    find(".bar__trigger").click
    assert_selector "dialog.bar__panel[open]"

    find(".bar__panel .search__input").send_keys("checklist")
    within(".bar__results") { assert_text card.title }

    find(".bar__panel .search__input").send_keys(:escape)
    assert_no_selector "dialog.bar__panel[open]"
  end

  test "due soon narrows the board to cards due by tomorrow" do
    cards(:logo).update_columns(column_id: columns(:writebook_doing).id, due_on: Date.yesterday)
    cards(:text).update!(due_on: 2.weeks.from_now)
    visit board_url(boards(:writebook))

    click_on "Due soon"
    assert_selector ".due-toggle[aria-pressed=true]"
    assert_selector ".card", text: cards(:logo).title
    assert_no_selector ".card", text: cards(:text).title

    click_on "Due soon"
    assert_selector ".card", text: cards(:text).title
  end
end
