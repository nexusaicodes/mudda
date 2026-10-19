require "test_helper"

class ColumnTest < ActiveSupport::TestCase
  test "a lane's name is fixed once created" do
    assert_raises ActiveRecord::ReadonlyAttributeError do
      columns(:writebook_backlog).update!(name: "Someday")
    end
  end
end
