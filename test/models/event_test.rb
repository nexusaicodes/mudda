require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "blank board filter returns the current relation unchanged" do
    relation = Event.where(action: "card_created")

    assert_equal relation.to_sql, relation.for_boards(nil).to_sql
    assert_equal relation.to_sql, relation.for_boards([]).to_sql
  end

  test "blank board filter remains chainable" do
    relation = Event.where(action: "card_created")

    assert_nothing_raised do
      relation.for_boards([]).load
    end
  end
end
