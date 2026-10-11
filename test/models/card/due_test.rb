require "test_helper"

class Card::DueTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "a date is optional in Backlog and required in every other lane" do
    card = boards(:writebook).cards.create! creator: users(:kevin), title: "Someday"
    assert card.backlogged?

    %w[ todo doing done ].each do |lane|
      assert_not card.update(column: columns(:"writebook_#{lane}")), "#{lane} took an undated card"
      assert card.errors.added?(:due_on, :blank, message: "can't be blank outside Backlog")
    end
  end

  test "a card is overdue once its due date has passed" do
    card = cards(:logo)

    card.update! due_on: 1.day.ago
    assert card.overdue?

    card.update! due_on: 1.day.from_now
    assert_not card.overdue?
  end
end
