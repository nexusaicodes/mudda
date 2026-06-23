require "test_helper"

class Boards::ColumnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get board_column_path(boards(:writebook), columns(:writebook_doing))
    assert_response :success
  end

  test "index as JSON" do
    board = boards(:writebook)

    get board_columns_path(board), as: :json

    assert_response :success
    assert_equal board.columns.count, @response.parsed_body.count
    assert_equal board_column_cards_url(board, board.columns.sorted.first), @response.parsed_body.first["cards_url"]
  end

  test "show as JSON" do
    column = columns(:writebook_doing)

    get board_column_path(column.board, column), as: :json

    assert_response :success
    assert_equal column.id, @response.parsed_body["id"]
    assert_equal board_column_cards_url(column.board, column), @response.parsed_body["cards_url"]
  end
end
