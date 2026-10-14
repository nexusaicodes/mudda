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

  test "a card needs a due date to enter Todo or Doing" do
    card = boards(:writebook).cards.create!(creator: users(:david))

    assert_not card.update(column: columns(:writebook_doing))
    assert_equal [ "can't be blank in Todo or Doing" ], card.errors[:due_on]
    assert_equal columns(:writebook_backlog), card.reload.column

    assert card.update(column: columns(:writebook_doing), due_on: Date.tomorrow)
  end

  test "an undated card can go straight to Done" do
    card = boards(:writebook).cards.create!(creator: users(:david))

    assert card.update(column: columns(:writebook_done))
    assert card.reload.closed?
  end

  test "a card in Todo or Doing can't drop its due date" do
    card = cards(:text)

    assert_not card.update(due_on: nil)
    assert card.update(due_on: nil, column: columns(:writebook_backlog))
  end

  test "a due date that doesn't parse is refused, even in Backlog" do
    card = cards(:logo)
    due_on = card.due_on

    assert_not card.update(due_on: "2026-02-30")
    assert_equal [ "is invalid" ], card.errors[:due_on]
    assert_equal due_on, card.reload.due_on

    assert_not boards(:writebook).cards.new(creator: users(:david), due_on: "next friday").valid?
    assert boards(:writebook).cards.new(creator: users(:david), due_on: "").valid?
  end

  # The event follows column_id itself, so a plain attribute write is audited.
  test "a lane change is audited" do
    card = cards(:logo)
    column = columns(:writebook_doing)

    assert_difference -> { card.reload.events.where(action: "card_triaged").count }, +1 do
      card.update! column: column
    end

    assert_equal column, card.reload.column
    assert_not card.backlogged?
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
