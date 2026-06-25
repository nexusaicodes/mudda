require "test_helper"

class BoardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new" do
    get new_board_path
    assert_response :success
  end

  test "show" do
    get board_path(boards(:writebook))
    assert_response :success
  end

  test "invalidates page title cache when account updates" do
    get board_path(boards(:writebook))
    etag = response.headers["ETag"]

    accounts("37s").update!(name: "Renamed Account")

    get board_path(boards(:writebook)), headers: { "If-None-Match" => etag }
    assert_response :success
  end

  test "create" do
    assert_difference -> { Board.count }, +1 do
      post boards_path, params: { board: { name: "Remodel Punch List" } }
    end

    board = Board.last
    assert_redirected_to board_path(board)
    assert_equal "Remodel Punch List", board.name
  end

  test "edit" do
    get edit_board_path(boards(:writebook))
    assert_response :success
  end

  test "update" do
    patch board_path(boards(:writebook)), params: {
      board: { name: "Writebook bugs" }
    }

    assert_redirected_to edit_board_path(boards(:writebook))
    assert_equal "Writebook bugs", boards(:writebook).reload.name
  end

  test "destroy" do
    board = boards(:writebook)
    delete board_path(board)
    assert_redirected_to root_path
    assert_raises(ActiveRecord::RecordNotFound) { board.reload }
  end

  test "index as JSON" do
    get boards_path, as: :json
    assert_response :success
    assert_equal users(:kevin).boards.count, @response.parsed_body.count
  end

  test "show as JSON" do
    get board_path(boards(:writebook)), as: :json
    assert_response :success
    assert_equal boards(:writebook).name, @response.parsed_body["name"]
  end

  test "create as JSON" do
    assert_difference -> { Board.count }, +1 do
      post boards_path, params: { board: { name: "My new board" } }, as: :json
    end

    assert_response :created
    assert_equal board_path(Board.last, format: :json), @response.headers["Location"]
    assert_equal "My new board", @response.parsed_body["name"]
  end

  test "update as JSON" do
    board = boards(:writebook)

    put board_path(board), params: { board: { name: "Updated Name" } }, as: :json

    assert_response :success
    assert_equal "Updated Name", board.reload.name

    json = @response.parsed_body
    assert_equal board.id, json["id"]
    assert_equal "Updated Name", json["name"]
    assert_equal board.creator.id, json["creator"]["id"]
  end

  test "destroy as JSON" do
    board = boards(:writebook)

    assert_difference -> { Board.count }, -1 do
      delete board_path(board), as: :json
    end

    assert_response :no_content
  end

  test "index avoids N+1 queries on creator and identity" do
    assert_queries_match(/FROM [`"]users[`"].* IN \(/, count: 1) do
      assert_queries_match(/FROM [`"]identities[`"].* IN \(/, count: 1) do
        get boards_path, as: :json
        assert_response :success
      end
    end

    json = @response.parsed_body
    first_board = json.first
    assert first_board["creator"].present?
    assert first_board["creator"]["email_address"].present?
  end
end
