require "test_helper"

class CardsHelperTest < ActionView::TestCase
  setup do
    travel_to Date.new(2026, 10, 14) # a Wednesday
  end

  test "a preview's due label is relative while it is close, then the date" do
    assert_equal "Overdue 2d", card_due_relative_label(due(-2))
    assert_equal "Today", card_due_relative_label(due(0))
    assert_equal "Tomorrow", card_due_relative_label(due(1))
    assert_equal "Fri", card_due_relative_label(due(2))
    assert_equal "Tue", card_due_relative_label(due(6))
    assert_equal "Oct 21", card_due_relative_label(due(7))
    assert_equal "Jan 5, 2027", card_due_relative_label(Card.new(due_on: Date.new(2027, 1, 5)))
  end

  test "only a late card or one due within a day asks for attention" do
    assert_equal "overdue", card_due_tone(due(-1))
    assert_equal "soon", card_due_tone(due(0))
    assert_equal "soon", card_due_tone(due(1))
    assert_equal "later", card_due_tone(due(2))
  end

  test "a due date's badge colour follows its tone" do
    assert_equal "badge-error", card_due_badge_class(due(-1))
    assert_equal "badge-warning", card_due_badge_class(due(1))
    assert_equal "badge-ghost", card_due_badge_class(due(2))
  end

  private
    def due(days)
      Card.new(due_on: Date.current + days)
    end
end
