require "application_system_test_case"

class SmokeTest < ApplicationSystemTestCase
  test "create a card" do
    sign_in_as(users(:david))

    visit board_url(boards(:writebook))
    click_on "Add a card"
    fill_in "card_title", with: "Hello, world!"
    fill_in_lexxy with: "I am editing this thing"
    fill_in "card_due_on", with: 1.week.from_now.to_date
    click_on "Create card"

    assert_current_path %r{/boards/\d+/cards/\d+}
    assert_text "Hello, world!"
  end

  test "active storage attachments" do
    sign_in_as(users(:david))

    visit board_card_url(cards(:layout).board, cards(:layout))
    fill_in_lexxy with: "Here is a note"
    attach_file file_fixture("moon.jpg") do
      click_on "Upload file"
    end

    within("form lexxy-editor figure.attachment[data-content-type='image/jpeg']") do
      assert_selector "img[src*='/rails/active_storage']"
      assert_selector "figcaption textarea[placeholder='moon.jpg']"
    end

    click_on "Post"

    within("action-text-attachment") do
      assert_selector "a img[src*='/rails/active_storage']"
      assert_selector "figcaption span.attachment__name", text: "moon.jpg"
    end

    # Click the image to open the lightbox
    find("action-text-attachment figure.attachment a:has(img)").click

    assert_selector "dialog.lightbox[open]"
    within("dialog.lightbox") do
      assert_selector "img.lightbox__image[src*='/rails/active_storage']"
    end
  end

  test "dragging card to a new column" do
    sign_in_as(users(:david))

    # Doing is the lane the board opens expanded, so its cards are the ones on screen to drag.
    card, destination = cards(:text), columns(:writebook_todo)
    assert_equal "Doing", card.column.name

    visit board_url(boards(:writebook))

    # Each lane loads its cards in its own turbo frame, so scope the lookup to the lane and
    # let Capybara wait for that frame rather than the whole page.
    card_el = page.find("#column_#{card.column_id}").find("#article_card_#{card.id}")
    column_el = page.find("#column_#{destination.id}")
    cards_count = column_el.find(".cards__expander-count").text.to_i

    card_el.drag_to(column_el)

    column_el.find(".cards__expander-count", text: cards_count + 1)
    assert_equal("Todo", card.reload.column.name)
  end
end
