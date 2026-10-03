require "test_helper"

class Card::DueTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  # A card lands complete, so there is no state in which it can be saved without a date.
  test "a card requires a due date" do
    card = boards(:writebook).cards.new creator: users(:kevin), title: "Needs a date"

    assert_not card.save
    assert card.errors.added?(:due_on, :blank)
  end

  test "a card is overdue once its due date has passed" do
    card = cards(:logo)

    card.update! due_on: 1.day.ago
    assert card.overdue?

    card.update! due_on: 1.day.from_now
    assert_not card.overdue?
  end
end
