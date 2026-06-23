require "test_helper"

class Card::ColoredTest < ActiveSupport::TestCase
  test "use default color if no column" do
    card = cards(:logo)
    card.column = nil
    assert_equal Column::Colored::DEFAULT_COLOR, card.color
  end

  test "infer color from column" do
    assert_equal cards(:layout).column.color, cards(:layout).color
  end
end
