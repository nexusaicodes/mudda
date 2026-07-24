require "test_helper"

class LandingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "renders the landing with a redirect map of the account's boards" do
    get landing_path

    assert_response :success

    users(:kevin).boards.each do |board|
      assert_includes response.body, board_path(board)
    end
  end

  test "offers the most recently active board by default" do
    default_board = users(:kevin).boards.ordered_by_recent_activity.first

    get landing_path

    assert_response :success
    assert_select "a", text: "Open board"
    assert_includes response.body, board_path(default_board)
  end

  test "shows an empty state when there are no boards" do
    Board.destroy_all

    get landing_path

    assert_response :success
    assert_select "a", text: "Create a board"
  end
end
