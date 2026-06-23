require "test_helper"

class Card::DueTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "a draft can be saved without a due date" do
    card = boards(:writebook).cards.create! creator: users(:kevin), title: "No due date yet"

    assert card.persisted?
    assert_nil card.due_on
  end

  test "publishing requires a due date" do
    card = boards(:writebook).cards.create! creator: users(:kevin), title: "Needs a date"

    assert_not card.publish
    assert card.reload.drafted?
    assert card.errors.added?(:due_on, :blank)
  end

  test "publishing succeeds with a due date" do
    card = boards(:writebook).cards.create! creator: users(:kevin), title: "Has a date", due_on: 1.week.from_now

    assert card.publish
    assert card.reload.published?
  end

  test "a published card is overdue once its due date has passed" do
    card = cards(:logo)

    card.update! due_on: 1.day.ago
    assert card.overdue?

    card.update! due_on: 1.day.from_now
    assert_not card.overdue?
  end

  test "a draft is never overdue" do
    card = boards(:writebook).cards.create! creator: users(:kevin), title: "Draft", due_on: 1.day.ago

    assert_not card.overdue?
  end
end
