require "test_helper"

class Cards::PinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
  end

  test "create" do
    assert_changes -> { cards(:text).reload.pinned? }, from: false, to: true do
      post board_card_pin_path(cards(:text).board, cards(:text)), as: :turbo_stream
      assert_card_container_rerendered(cards(:text))
    end
  end

  test "destroy" do
    assert_changes -> { cards(:logo).reload.pinned? }, from: true, to: false do
      delete board_card_pin_path(cards(:logo).board, cards(:logo)), as: :turbo_stream
      assert_card_container_rerendered(cards(:logo))
    end
  end

  # Pin is a boolean column on the card, so the pin button is the browser's and every
  # other client sets it by updating the card.
  test "pin has no JSON representation of its own" do
    card = cards(:text)

    post board_card_pin_path(card.board, card), as: :json
    assert_response :not_acceptable
    assert_not card.reload.pinned?

    put board_card_path(card.board, card), params: { card: { pinned: true } }, as: :json
    assert_response :success
    assert card.reload.pinned?
    assert @response.parsed_body["pinned"]
  end
end
