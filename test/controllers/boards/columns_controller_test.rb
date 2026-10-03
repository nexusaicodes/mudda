require "test_helper"

class Boards::ColumnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get board_column_path(boards(:writebook), columns(:writebook_doing))
    assert_response :success
  end

  # A board's columns are fixed, so they have no JSON representation of their own — they
  # travel with the board, and each one names the card index that answers for it.
  test "a lane's JSON lives on its board" do
    board = boards(:writebook)
    column = board.columns.sorted.first

    get board_column_path(board, column), as: :json
    assert_response :not_acceptable

    get board_path(board), as: :json
    assert_response :success

    lane = @response.parsed_body["columns"].first
    assert_equal column.id, lane["id"]
    assert_equal board_cards_url(board, column_ids: [ column.id ]), lane["cards_url"]
  end
end
