require "test_helper"

class My::TimezonesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update" do
    time_zone = ActiveSupport::TimeZone["America/New_York"]

    assert_not_equal time_zone, users(:kevin).timezone
    patch my_timezone_path, params: { timezone_name: "America/New_York" }
    assert_equal time_zone, users(:kevin).reload.timezone
  end

  test "update as JSON" do
    assert_not_equal ActiveSupport::TimeZone["America/Chicago"], users(:kevin).timezone
    patch my_timezone_path, params: { timezone_name: "America/Chicago" }, as: :json
    assert_response :no_content
    assert_equal ActiveSupport::TimeZone["America/Chicago"], users(:kevin).reload.timezone
  end

  # The layout auto-submits this sync on every page load; if the enrollment gate redirected it,
  # the write would never land and the enrollment page would reload forever.
  test "syncs during forced passkey enrollment instead of redirecting" do
    sign_in_without_passkey :kevin

    patch my_timezone_path, params: { timezone_name: "America/New_York" }

    assert_response :no_content
    assert_equal ActiveSupport::TimeZone["America/New_York"], users(:kevin).reload.timezone
  end
end
