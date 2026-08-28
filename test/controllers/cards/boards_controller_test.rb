require "test_helper"

class Cards::BoardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "edit lists the boards a card can move to" do
    card = cards(:logo)

    get edit_board_card_board_path(card.board, card)

    assert_response :success
    users(:kevin).boards.each { |board| assert_select "li", text: /#{board.name}/ }
  end

  # The picker only offers the choice; CardsController#update is what moves the card.
  test "choosing a board moves the card" do
    card, destination = cards(:logo), boards(:private)

    assert_changes -> { card.reload.board }, from: card.board, to: destination do
      put board_card_path(card.board, card), params: { card: { board_id: destination.id } }
    end

    assert_redirected_to card
  end
end
