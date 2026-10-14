require "test_helper"

class Column::PositionedTest < ActiveSupport::TestCase
  test "auto position new columns" do
    board = boards(:writebook)
    max_position = board.columns.maximum(:position)

    new_column = board.columns.create!(name: "New Column", color: "#000000")

    assert_equal max_position + 1, new_column.position
  end
end
