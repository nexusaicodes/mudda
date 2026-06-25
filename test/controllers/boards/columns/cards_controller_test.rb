require "test_helper"

class Boards::Columns::CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index as JSON" do
    column = columns(:writebook_doing)

    get board_column_cards_path(column.board, column), as: :json

    assert_response :success
    assert_kind_of Array, @response.parsed_body
    assert_equal [ cards(:text).number ], @response.parsed_body.pluck("number")
    assert_equal "1", response.headers["X-Total-Count"]
  end
end
