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
    card = boards(:writebook).cards.create!(creator: users(:david))

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

  test "cannot triage into a column from a different board" do
    card = cards(:logo)

    assert_raises(RuntimeError) do
      card.triage_into(columns(:private_todo))
    end
  end

  test "scopes" do
    assert_includes Card.awaiting_triage, cards(:logo)
    assert_not_includes Card.awaiting_triage, cards(:text)

    assert_includes Card.triaged, cards(:text)
    assert_not_includes Card.triaged, cards(:logo)
  end
end
