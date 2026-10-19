require "test_helper"

class Card::DueTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "a date is required in Todo and Doing, and optional in Backlog and Done" do
    card = boards(:writebook).cards.create! creator: users(:david), title: "Someday"
    assert card.backlogged?

    %w[ todo doing ].each do |lane|
      assert_not card.update(column: columns(:"writebook_#{lane}")), "#{lane} took an undated card"
      assert_equal [ "can't be blank in Todo or Doing" ], card.errors[:due_on]
    end

    assert card.update(column: columns(:writebook_done)), "Done refused an undated card"
  end

  test "anything but a date is refused as invalid, and only that" do
    card = boards(:writebook).cards.create! creator: users(:david), title: "Someday"

    [ "2026-02-30", "next friday", 20261201, true, false ].each do |value|
      assert_not card.update(due_on: value), "Backlog took #{value.inspect}"
      assert_equal [ "is invalid" ], card.errors[:due_on], "for #{value.inspect}"

      assert_not card.update(due_on: value, column: columns(:writebook_doing)), "Doing took #{value.inspect}"
      assert_equal [ "is invalid" ], card.errors[:due_on], "for #{value.inspect} in Doing"
      card.reload
    end

    assert card.update(due_on: ""), "Backlog refused a cleared date"
    assert_nil card.due_on
  end

  test "a card is overdue once its due date has passed" do
    card = cards(:logo)

    card.update! due_on: 1.day.ago
    assert card.overdue?

    card.update! due_on: 1.day.from_now
    assert_not card.overdue?
  end
end
