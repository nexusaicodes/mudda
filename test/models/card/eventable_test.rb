require "test_helper"

class Card::EventableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "new cards default last_active_at to created_at" do
    freeze_time

    card = boards(:writebook).cards.create!(title: "Some card", creator: users(:david))
    assert_equal card.created_at, card.last_active_at
  end

  test "new cards with custom created_at default last_active_at to that time" do
    custom_time = 1.week.ago.change(usec: 0)

    card = boards(:writebook).cards.create!(title: "Backdated card", creator: users(:david), created_at: custom_time)
    assert_equal custom_time, card.created_at
    assert_equal custom_time, card.last_active_at
  end

  test "new cards preserve explicit last_active_at" do
    created_time = 2.weeks.ago.change(usec: 0)
    last_active_time = 1.week.ago.change(usec: 0)

    card = boards(:writebook).cards.create! \
      title: "Card with explicit timestamps",
      creator: users(:david),
      created_at: created_time,
      last_active_at: last_active_time

    assert_equal created_time, card.created_at
    assert_equal last_active_time, card.last_active_at
  end

  test "publishing a card does not overwrite last_active_at" do
    created_time = 2.weeks.ago.change(usec: 0)
    last_active_time = 1.week.ago.change(usec: 0)

    card = boards(:writebook).cards.create! \
      title: "Published card",
      creator: users(:david),
      status: :published, due_on: 1.week.from_now,
      created_at: created_time,
      last_active_at: last_active_time

    assert_equal last_active_time, card.last_active_at
  end

  test "tracking events update the last activity time" do
    travel_to Time.current

    cards(:logo).triage_into(columns(:writebook_done))
    assert_equal Time.current, cards(:logo).last_active_at
  end

  # particulars is the audit trail's payload, so an event has to record the change itself
  # rather than a wrapper around it.
  test "an event records its particulars flat" do
    card = cards(:logo)
    old_title = card.title

    card.update!(title: "Renamed logo")
    assert_equal({ "old_title" => old_title, "new_title" => "Renamed logo" },
      card.events.where(action: "card_title_changed").last.particulars)

    card.update!(board: boards(:private))
    assert_equal({ "old_board" => boards(:writebook).name, "new_board" => boards(:private).name },
      card.events.where(action: "card_board_changed").last.particulars)
  end

  test "renaming a card touches its events so the activity feed cache invalidates" do
    card = cards(:logo)
    event = card.events.first
    assert_not_nil event, "expected the published card to have at least one event"

    travel_to 1.hour.from_now do
      card.update!(title: "Renamed logo")
      assert_equal Time.current, event.reload.updated_at
    end
  end
end
