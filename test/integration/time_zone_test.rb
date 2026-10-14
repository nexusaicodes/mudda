require "test_helper"

# Which day "today" is, for every kind of request (see CurrentTimezone). The clock is stopped at
# 20:00 UTC on 14 October, when it is already 01:30 on the 15th in Kolkata and 13:00 on the
# 14th in Los Angeles, so the three zones disagree about due dates.
class TimeZoneTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 14, 20, 0)

    @user = users(:david)
    @board = boards(:writebook)
    Current.user = @user
    @card = @board.cards.create!(title: "Due on the 14th", due_on: Date.new(2026, 10, 14), creator: @user)
  end

  # A script or agent sends no cookie, so its day is the one saved from the owner's browser.

  test "a token's dates follow the owner's saved zone" do
    save_zone "Asia/Kolkata"

    get board_card_path(@board, @card, format: :json), headers: bearer_headers_for(@user)

    assert @response.parsed_body["overdue"], "the 14th has passed in Kolkata"
  end

  test "a token's dates are UTC while no zone has been saved" do
    get board_card_path(@board, @card, format: :json), headers: bearer_headers_for(@user)

    assert_not @response.parsed_body["overdue"], "it is still the 14th in UTC"
  end

  test "a saved zone that no longer names one reads as UTC" do
    @user.settings.update_column :timezone_name, "Atlantis/Lost_City"

    get my_user_path(format: :json), headers: bearer_headers_for(@user)

    assert_equal "UTC", @response.parsed_body["timezone"]
  end

  test "due=soon reaches the owner's tomorrow" do
    soon = @board.cards.create!(title: "Due on the 16th", due_on: Date.new(2026, 10, 16), creator: @user)
    headers = bearer_headers_for(@user)

    get cards_path(format: :json, due: "soon"), headers: headers
    assert_not_includes @response.parsed_body["data"].pluck("id"), soon.id, "the 16th is two days off in UTC"

    save_zone "Asia/Kolkata"

    get cards_path(format: :json, due: "soon"), headers: headers
    assert_includes @response.parsed_body["data"].pluck("id"), soon.id, "the 16th is tomorrow in Kolkata"
  end

  test "creation=today is the owner's today" do
    @card.update_column :created_at, Time.utc(2026, 10, 14, 18, 0) # 23:30 on the 14th in Kolkata
    headers = bearer_headers_for(@user)

    get cards_path(format: :json, creation: "today"), headers: headers
    assert_includes @response.parsed_body["data"].pluck("id"), @card.id

    save_zone "Asia/Kolkata"

    get cards_path(format: :json, creation: "today"), headers: headers
    assert_not_includes @response.parsed_body["data"].pluck("id"), @card.id, "that was yesterday in Kolkata"
  end

  test "who am I reports the zone the request was reckoned in" do
    headers = bearer_headers_for(@user)

    get my_user_path(format: :json), headers: headers
    assert_equal "UTC", @response.parsed_body["timezone"]

    save_zone "Asia/Kolkata"

    get my_user_path(format: :json), headers: headers
    assert_equal "Asia/Kolkata", @response.parsed_body["timezone"]
  end

  test "a conditional GET isn't answered from a day reckoned in another zone" do
    headers = bearer_headers_for(@user)

    get board_path(@board, format: :json), headers: headers
    etag = response.headers.fetch("ETag")

    get board_path(@board, format: :json), headers: headers.merge("If-None-Match" => etag)
    assert_response :not_modified

    save_zone "Asia/Kolkata"

    get board_path(@board, format: :json), headers: headers.merge("If-None-Match" => etag)
    assert_response :success
  end

  # A browser's own zone decides, whatever was saved.

  test "the browser's zone decides its pages" do
    save_zone "Asia/Kolkata"
    sign_in_as @user
    cookies[:timezone] = "America/Los_Angeles"

    get cards_path(lane: "backlog")
    assert_select "#article_card_#{@card.id} .card__when--soon", text: /Today/

    get board_card_path(@board, @card)
    assert_select ".card__due--soon"
  end

  test "a browser without its zone yet gets the saved one" do
    save_zone "Asia/Kolkata"
    sign_in_as @user

    get cards_path(lane: "backlog")
    assert_select "#article_card_#{@card.id} .card__when--overdue", text: /Overdue 1d/

    get board_card_path(@board, @card)
    assert_select ".card__due--overdue"
  end

  test "a browser zone that doesn't name one falls back to the saved one" do
    save_zone "Asia/Kolkata"
    sign_in_as @user
    cookies[:timezone] = "Not/A_Zone"

    get my_user_path(format: :json)

    assert_equal "Asia/Kolkata", @response.parsed_body["timezone"]
  end

  test "a browser saves its zone when it differs from the saved one" do
    sign_in_as @user
    cookies[:timezone] = "America/Los_Angeles"

    get board_path(@board)

    assert_select "form[action='#{my_timezone_path}'] input[name='timezone[timezone_name]'][value='America/Los_Angeles']"
  end

  test "a browser reporting a zone by its old name gets that zone, and doesn't resave it" do
    save_zone "Asia/Kolkata"
    sign_in_as @user
    cookies[:timezone] = "Asia/Calcutta" # what Chromium reports for India

    get my_user_path(format: :json)
    assert_equal "Asia/Kolkata", @response.parsed_body["timezone"]

    get board_path(@board)
    assert_select "form[action='#{my_timezone_path}']", count: 0
  end

  test "a browser doesn't resave a zone that is already saved" do
    save_zone "America/Los_Angeles"
    sign_in_as @user
    cookies[:timezone] = "America/Los_Angeles"

    get board_path(@board)

    assert_select "form[action='#{my_timezone_path}']", count: 0
  end

  private
    def save_zone(name)
      @user.settings.update!(timezone_name: name)
    end
end
