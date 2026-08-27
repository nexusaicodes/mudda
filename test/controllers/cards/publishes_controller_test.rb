require "test_helper"

class Cards::PublishesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)
    card.drafted!

    assert_changes -> { card.reload.published? }, from: false, to: true do
      post board_card_publish_path(card.board, card)
    end

    assert_redirected_to card.board
  end

  test "create as JSON" do
    card = cards(:logo)
    card.drafted!

    assert_changes -> { card.reload.published? }, from: false, to: true do
      post board_card_publish_path(card.board, card), as: :json
    end

    assert_response :created
  end

  test "create is blocked without a due date" do
    card = cards(:logo)
    card.update! status: :drafted, due_on: nil

    assert_no_changes -> { card.reload.published? } do
      post board_card_publish_path(card.board, card)
    end

    assert_redirected_to board_card_draft_path(card.board, card)
  end

  test "create as JSON is unprocessable without a due date" do
    card = cards(:logo)
    card.update! status: :drafted, due_on: nil

    post board_card_publish_path(card.board, card), as: :json

    assert_response :unprocessable_entity
  end

  test "create and add another" do
    card = cards(:logo)
    card.drafted!

    assert_changes -> { card.reload.published? }, from: false, to: true do
      assert_difference -> { Card.count }, +1 do
        post board_card_publish_path(card.board, card, creation_type: "add_another")
      end
    end

    new_card = Card.last
    assert new_card.drafted?
    assert_redirected_to board_card_draft_path(new_card.board, new_card)
  end
end
