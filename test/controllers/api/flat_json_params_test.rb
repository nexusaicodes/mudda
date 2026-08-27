require "test_helper"

class FlatJsonParamsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update account settings with flat JSON" do
    put account_settings_path, params: { name: "New Name" }, as: :json

    assert_response :no_content
    assert_equal "New Name", Current.account.reload.name
  end

  test "create card with flat JSON" do
    assert_difference -> { Card.count }, +1 do
      post board_cards_path(boards(:writebook)),
        params: { title: "Flat card", description: "<p>Flat description</p>", due_on: 1.week.from_now },
        as: :json
    end

    assert_response :created
    card = Card.last
    assert_equal "Flat card", card.title
    assert_equal "Flat description", card.description.to_plain_text
  end

  test "update card with flat JSON" do
    card = cards(:logo)

    put board_card_path(card.board, card),
      params: { title: "Flat update", description: "<p>Updated flat</p>" },
      as: :json

    assert_response :success
    card.reload
    assert_equal "Flat update", card.title
    assert_equal "Updated flat", card.description.to_plain_text
  end

  test "create board with flat JSON" do
    assert_difference -> { Board.count }, +1 do
      post boards_path, params: { name: "Flat board" }, as: :json
    end

    assert_response :created
    assert_equal "Flat board", Board.last.name
  end

  test "update board with flat JSON" do
    board = boards(:writebook)

    put board_path(board), params: { name: "Flat board" }, as: :json

    assert_response :success
    board.reload
    assert_equal "Flat board", board.name
    assert_equal board.id, @response.parsed_body["id"]
    assert_equal "Flat board", @response.parsed_body["name"]
  end

  test "create step with flat JSON" do
    card = cards(:logo)

    assert_difference -> { card.steps.count }, +1 do
      post board_card_steps_path(card.board, card), params: { content: "Flat step" }, as: :json
    end

    assert_response :created
    assert_equal "Flat step", Step.last.content
  end

  test "update step with flat JSON" do
    card = cards(:logo)
    step = card.steps.create!(content: "Original")

    put board_card_step_path(card.board, card, step), params: { content: "Flat updated" }, as: :json

    assert_response :success
    assert_equal "Flat updated", step.reload.content
  end

  test "update user with flat JSON" do
    put user_path(users(:kevin)), params: { name: "Flat Name" }, as: :json

    assert_response :success
    assert_equal "Flat Name", users(:kevin).reload.name
    assert_equal users(:kevin).id, @response.parsed_body["id"]
    assert_equal "Flat Name", @response.parsed_body["name"]
  end
end
