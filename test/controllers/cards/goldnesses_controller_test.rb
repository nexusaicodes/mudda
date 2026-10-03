require "test_helper"

class Cards::GoldnessesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    assert_changes -> { cards(:text).reload.golden? }, from: false, to: true do
      post board_card_goldness_path(cards(:text).board, cards(:text)), as: :turbo_stream
      assert_card_container_rerendered(cards(:text))
    end
  end

  test "destroy" do
    assert_changes -> { cards(:logo).reload.golden? }, from: true, to: false do
      delete board_card_goldness_path(cards(:logo).board, cards(:logo)), as: :turbo_stream
      assert_card_container_rerendered(cards(:logo))
    end
  end

  # Goldness is a boolean column on the card, so the star button is the browser's and every
  # other client sets it by updating the card.
  test "goldness has no JSON representation of its own" do
    card = cards(:text)

    post board_card_goldness_path(card.board, card), as: :json
    assert_response :not_acceptable
    assert_not card.reload.golden?

    put board_card_path(card.board, card), params: { card: { golden: true } }, as: :json
    assert_response :success
    assert card.reload.golden?
    assert @response.parsed_body["golden"]
  end
end
