require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    travel_to Time.utc(2025, 1, 22, 17, 30, 0)

    events(:layout_published).update!(created_at: Time.current.beginning_of_day + 8.hours)
  end

  test "index" do
    get events_path

    assert_select "div.events__time-block" do
      assert_select "strong", text: /added Layout is broken/
      assert_select "time[datetime=?]", events(:layout_published).created_at.to_i.to_s
    end
  end

  test "index emits absolute epoch timestamps regardless of the viewer timezone" do
    # Columns stack top-down and never encode the hour server-side; the <time>
    # element carries an absolute epoch that local-time localizes in the browser.
    cookies[:timezone] = "America/New_York"

    get events_path

    assert_select "time[datetime=?]", events(:layout_published).created_at.to_i.to_s
  end

  test "only displays events from filtered boards" do
    get events_path(board_ids: [ boards(:writebook).id ])
    assert_response :success

    events_shown = css_select(".event").count
    assert events_shown > 0, "Should show some events"

    css_select(".event").each do |event|
      assert_includes event.text, boards(:writebook).name
    end
  end

  test "index with a valid day" do
    get events_path(day: "2025-01-15")
    assert_response :success
  end

  test "index with an out-of-range day returns not found" do
    get events_path(day: "2020-99-99")
    assert_response :not_found
  end

  test "index with an unparseable day returns not found" do
    get events_path(day: "hello")
    assert_response :not_found
  end
end
