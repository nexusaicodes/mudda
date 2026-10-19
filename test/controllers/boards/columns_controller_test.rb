require "test_helper"

class Boards::ColumnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
  end

  test "a lane's cards load into its frame on the board" do
    get board_column_path(boards(:writebook), columns(:writebook_doing)), headers: { "Turbo-Frame" => "column_#{columns(:writebook_doing).id}_cards" }

    assert_response :success
    assert_select "turbo-frame#cards_column_#{columns(:writebook_doing).id}"
    assert_select "h1", count: 0
  end

  test "a lane has no page of its own, so a plain visit goes to the board" do
    get board_column_path(boards(:writebook), columns(:writebook_doing))

    assert_redirected_to board_path(boards(:writebook), anchor: "column_#{columns(:writebook_doing).id}")
  end

  test "a lane's cards don't name the board they are already on" do
    get board_column_path(boards(:writebook), columns(:writebook_doing)), headers: { "Turbo-Frame" => "cards" }

    assert_select ".card .card__title"
    assert_select ".card .card__details-board", count: 0
  end

  test "due=soon narrows a lane to its cards due by tomorrow" do
    frame = { "Turbo-Frame" => "column_#{columns(:writebook_doing).id}_cards" }

    cards(:text).update!(due_on: Date.yesterday)
    get board_column_path(boards(:writebook), columns(:writebook_doing), due: "soon"), headers: frame
    assert_select ".card .card__title", text: cards(:text).title

    cards(:text).update!(due_on: 2.weeks.from_now)
    get board_column_path(boards(:writebook), columns(:writebook_doing), due: "soon"), headers: frame
    assert_select ".card .card__title", text: cards(:text).title, count: 0
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
