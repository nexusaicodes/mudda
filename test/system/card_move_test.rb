require "application_system_test_case"

class CardMoveTest < ApplicationSystemTestCase
  # A move renumbers the card on its new board, so the page has to follow it there: left at
  # the old URL, its note form would post to a card that no longer answers to it.
  test "moving a card through the board picker follows it to its new address" do
    sign_in_as(users(:david))
    card, destination = cards(:logo), boards(:private)

    visit board_card_url(card.board, card)
    find("button[aria-label='Choose a board for this card']").click
    within("turbo-frame#board_picker") { click_on destination.name }

    assert_current_path board_card_path(destination, 1)
    assert_selector "form[action='#{board_card_notes_path(destination, 1)}']"
    assert_equal destination, card.reload.board
  end
end
