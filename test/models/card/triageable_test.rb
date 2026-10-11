require "test_helper"

class Card::TriageableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "cards in the Backlog column are backlogged" do
    assert cards(:logo).backlogged?
    assert cards(:buy_domain).backlogged?
    assert_not cards(:text).backlogged?
  end

  test "new cards land in Backlog, with or without a due date" do
    dated = boards(:writebook).cards.create!(creator: users(:david), due_on: 1.week.from_now)
    undated = boards(:writebook).cards.create!(creator: users(:david))

    assert_equal [ "Backlog", "Backlog" ], [ dated.column.name, undated.column.name ]
    assert_nil undated.due_on
  end

  test "a card needs a due date to leave Backlog" do
    card = boards(:writebook).cards.create!(creator: users(:david))

    assert_not card.update(column: columns(:writebook_doing))
    assert_equal [ "can't be blank outside Backlog" ], card.errors[:due_on]
    assert_equal columns(:writebook_backlog), card.reload.column

    assert card.update(column: columns(:writebook_doing), due_on: Date.tomorrow)
  end

  test "a card outside Backlog can't drop its due date" do
    card = cards(:text)

    assert_not card.update(due_on: nil)
    assert card.update(due_on: nil, column: columns(:writebook_backlog))
  end

  test "triage a card into a column" do
    card = cards(:logo)
    column = columns(:writebook_doing)

    assert_difference -> { card.reload.events.where(action: "card_triaged").count }, +1 do
      card.triage_into(column)
    end

    assert_equal column, card.reload.column
    assert_not card.backlogged?
  end

  # The event follows column_id itself, not the method that changed it, so a plain attribute
  # write is audited the same as triage_into.
  test "any lane change is audited" do
    card = cards(:logo)

    assert_difference -> { card.reload.events.where(action: "card_triaged").count }, +1 do
      card.update! column: columns(:writebook_done)
    end
  end

  # A board change lands the card in the destination's Backlog, which is a lane change like
  # any other and is recorded as one alongside the board-change event.
  test "landing in a new board's Backlog is audited as a triage" do
    card = cards(:text)

    assert_difference -> { card.reload.events.where(action: "card_triaged").count }, +1 do
      assert_difference -> { card.reload.events.where(action: "card_board_changed").count }, +1 do
        card.update! board: boards(:private)
      end
    end

    assert card.reload.backlogged?
  end

  test "scopes" do
    assert_includes Card.backlogged, cards(:logo)
    assert_not_includes Card.backlogged, cards(:text)

    assert_includes Card.active, cards(:text)
    assert_not_includes Card.active, cards(:logo)
  end
end
