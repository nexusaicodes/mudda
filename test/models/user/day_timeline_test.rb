require "test_helper"

class User::DayTimelineTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "Done column shows cards triaged into Done; other column moves go to Updated" do
    board = boards(:writebook)

    cards(:logo).triage_into(board.columns.find_by(name: Card::Triageable::DONE_COLUMN))
    cards(:layout).triage_into(board.columns.find_by(name: "Doing"))

    done_event  = cards(:logo).events.where(action: "card_triaged").last
    other_event = cards(:layout).events.where(action: "card_triaged").last

    timeline = users(:david).timeline_for(Date.current, filter: users(:david).filters.new)

    assert_includes timeline.closed_column.events.to_a, done_event
    assert_not_includes timeline.closed_column.events.to_a, other_event
    assert_includes timeline.updated_column.events.to_a, other_event
    assert_not_includes timeline.updated_column.events.to_a, done_event
  end
end
