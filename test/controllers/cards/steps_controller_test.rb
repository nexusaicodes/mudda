require "test_helper"

class Cards::StepsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)

    assert_difference -> { card.steps.count }, +1 do
      post board_card_steps_path(card.board, card), params: { step: { content: "Research alternatives" } }, as: :turbo_stream
      assert_turbo_stream action: :before, target: dom_id(card, :new_step)
    end

    assert_equal "Research alternatives", card.steps.last.content
  end

  test "update" do
    card = cards(:logo)
    step = card.steps.create!(content: "Original content")

    assert_changes -> { step.reload.content }, from: "Original content", to: "Updated content" do
      put board_card_step_path(card.board, card, step), params: { step: { content: "Updated content" } }, as: :turbo_stream
      assert_turbo_stream action: :replace, target: dom_id(step)
    end
  end

  test "destroy" do
    card = cards(:logo)
    step = card.steps.create!(content: "Step to delete")

    assert_difference -> { card.steps.count }, -1 do
      delete board_card_step_path(card.board, card, step), as: :turbo_stream
      assert_turbo_stream action: :remove, target: dom_id(step)
    end
  end

  test "toggle completion" do
    card = cards(:logo)
    step = card.steps.create!(content: "Test step", completed: false)

    # Toggle to completed
    assert_changes -> { step.reload.completed? }, from: false, to: true do
      put board_card_step_path(card.board, card, step), params: { step: { completed: "1" } }, as: :turbo_stream
      assert_turbo_stream action: :replace, target: dom_id(step)
    end

    # Toggle back to incomplete
    assert_changes -> { step.reload.completed? }, from: true, to: false do
      put board_card_step_path(card.board, card, step), params: { step: { completed: "0" } }, as: :turbo_stream
      assert_turbo_stream action: :replace, target: dom_id(step)
    end
  end

  # Steps are part of the card everywhere but the browser: read from its own representation,
  # written through its steps_attributes.
  test "steps have no JSON representation of their own" do
    card = cards(:logo)
    step = card.steps.create!(content: "Test step")

    get board_card_steps_path(card.board, card), as: :json
    assert_response :not_found

    get board_card_step_path(card.board, card, step), as: :json
    assert_response :not_acceptable

    assert_no_difference -> { card.steps.count } do
      post board_card_steps_path(card.board, card), params: { step: { content: "New" } }, as: :json
    end
    assert_response :not_acceptable
  end

  test "a card carries its steps" do
    card = cards(:logo)
    card.steps.create!(content: "Step one")
    card.steps.create!(content: "Step two", completed: true)

    get board_card_path(card.board, card), as: :json

    assert_response :success
    assert_equal [ "Step one", "Step two" ], @response.parsed_body["steps"].map { |step| step["content"] }
    assert_equal [ false, true ], @response.parsed_body["steps"].map { |step| step["completed"] }
  end

  test "steps are added, edited, and removed by updating the card" do
    card = cards(:logo)
    step = card.steps.create!(content: "Original")

    assert_difference -> { card.steps.count }, +1 do
      put board_card_path(card.board, card), as: :json, params: { card: { steps_attributes: [
        { id: step.id, content: "Edited", completed: true },
        { content: "Added" }
      ] } }
    end

    assert_response :success
    assert_equal [ "Added", "Edited" ], card.reload.steps.map(&:content).sort
    assert step.reload.completed?

    assert_difference -> { card.steps.count }, -1 do
      put board_card_path(card.board, card), as: :json,
        params: { card: { steps_attributes: [ { id: step.id, _destroy: true } ] } }
    end

    assert_response :success
    assert_not Step.exists?(step.id)
  end

  # A step id from another card would otherwise be edited through whichever card names it.
  test "a card cannot edit another card's steps" do
    card = cards(:logo)
    other_step = cards(:layout).steps.create!(content: "Somebody else's")

    put board_card_path(card.board, card), as: :json,
      params: { card: { steps_attributes: [ { id: other_step.id, content: "Hijacked" } ] } }

    assert_response :not_found
    assert_equal "Somebody else's", other_step.reload.content
  end
end
