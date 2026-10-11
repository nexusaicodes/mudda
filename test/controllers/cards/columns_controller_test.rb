require "test_helper"

class Cards::ColumnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update moves the card to the picked lane" do
    card = cards(:logo)

    patch board_card_column_path(card.board, card, column_id: columns(:writebook_doing).id)

    assert_redirected_to board_card_path(card.board, card)
    assert_equal columns(:writebook_doing), card.reload.column
  end

  test "an undated card picked out of Backlog stays put and says why" do
    card = cards(:logo)
    card.update!(due_on: nil)

    patch board_card_column_path(card.board, card, column_id: columns(:writebook_doing).id)

    assert_redirected_to board_card_path(card.board, card)
    assert_equal "Due date can't be blank outside Backlog", flash[:alert]
    assert card.reload.backlogged?
  end
end
