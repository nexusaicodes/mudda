require "test_helper"

class Card::TriageableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "cards in the Triage column are awaiting triage" do
    assert cards(:logo).awaiting_triage?
    assert cards(:buy_domain).awaiting_triage?
    assert_not cards(:text).awaiting_triage?
  end

  test "cards outside the Triage column are triaged" do
    assert cards(:text).triaged?
    assert_not cards(:logo).triaged?
  end

  test "new cards default to the Triage column" do
    card = boards(:writebook).cards.create!(creator: users(:david), due_on: 1.week.from_now)

    assert_equal "Triage", card.column.name
    assert card.awaiting_triage?
  end

  test "triage a card into a column" do
    card = cards(:logo)
    column = columns(:writebook_doing)

    assert_difference -> { card.reload.events.where(action: "card_triaged").count }, +1 do
      card.triage_into(column)
    end

    assert_equal column, card.reload.column
    assert card.triaged?
  end

  # The event follows column_id itself, not the method that changed it, so a plain attribute
  # write is audited the same as triage_into.
  test "any lane change is audited" do
    card = cards(:logo)

    assert_difference -> { card.reload.events.where(action: "card_triaged").count }, +1 do
      card.update! column: columns(:writebook_done)
    end
  end

  # A board change lands the card in the destination's Triage, which is a lane change like
  # any other and is recorded as one alongside the board-change event.
  test "landing in a new board's Triage is audited as a triage" do
    card = cards(:text)

    assert_difference -> { card.reload.events.where(action: "card_triaged").count }, +1 do
      assert_difference -> { card.reload.events.where(action: "card_board_changed").count }, +1 do
        card.update! board: boards(:private)
      end
    end

    assert card.reload.awaiting_triage?
  end

  test "scopes" do
    assert_includes Card.awaiting_triage, cards(:logo)
    assert_not_includes Card.awaiting_triage, cards(:text)

    assert_includes Card.triaged, cards(:text)
    assert_not_includes Card.triaged, cards(:logo)
  end
end
