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
end
