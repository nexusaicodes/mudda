require "test_helper"

class User::SettingsTest < ActiveSupport::TestCase
  setup do
    @user = users(:david)
    @settings = @user.settings
  end

  test "timezone returns the configured zone" do
    @settings.update!(timezone_name: "Eastern Time (US & Canada)")

    assert_equal ActiveSupport::TimeZone["Eastern Time (US & Canada)"], @settings.timezone
  end

  test "timezone falls back to UTC when blank" do
    @settings.update!(timezone_name: nil)

    assert_equal ActiveSupport::TimeZone["UTC"], @settings.timezone
  end

  test "timezone falls back to UTC for an unknown zone name" do
    @settings.update!(timezone_name: "Not A Real Zone")

    assert_equal ActiveSupport::TimeZone["UTC"], @settings.timezone
  end
end
