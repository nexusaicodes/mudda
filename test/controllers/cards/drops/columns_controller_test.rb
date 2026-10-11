require "test_helper"

class Cards::Drops::ColumnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)
    column = columns(:writebook_doing)

    assert_changes -> { card.reload.column }, to: column do
      post board_card_drops_column_path(card.board, card, column_id: column.id), as: :turbo_stream
      assert_response :success
    end
  end

  test "an undated card dropped outside Backlog stays put and says why" do
    card = cards(:logo)
    card.update!(due_on: nil)

    assert_no_changes -> { card.reload.column } do
      post board_card_drops_column_path(card.board, card, column_id: columns(:writebook_doing).id), as: :turbo_stream
      assert_response :success
    end

    assert_select "turbo-stream[action=replace][target=flash]", text: /Due date can't be blank outside Backlog/
  end
end
