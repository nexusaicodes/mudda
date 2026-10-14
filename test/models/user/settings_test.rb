require "test_helper"

class User::SettingsTest < ActiveSupport::TestCase
  test "locale is one the app speaks, or blank" do
    settings = users(:kevin).settings

    assert settings.update(locale: "ar")
    assert settings.update(locale: nil)
    assert_not settings.update(locale: "fr")
  end

  test "timezone_name names a zone, or is blank" do
    settings = users(:kevin).settings

    assert settings.update(timezone_name: "Asia/Kolkata")
    assert settings.update(timezone_name: "Eastern Time (US & Canada)")
    assert settings.update(timezone_name: nil)
    assert_not settings.update(timezone_name: "Mars/Olympus_Mons")
    assert_includes settings.errors[:timezone_name], "is invalid"
  end

  test "timezone_name is saved under the zone's canonical name" do
    settings = users(:kevin).settings

    settings.update!(timezone_name: "Asia/Calcutta")
    assert_equal "Asia/Kolkata", settings.timezone_name

    settings.update!(timezone_name: "Eastern Time (US & Canada)")
    assert_equal "America/New_York", settings.timezone_name
  end

  test "timezone_name is stripped, and a blank one is nil" do
    settings = users(:kevin).settings

    settings.update!(timezone_name: "  Asia/Kolkata ")
    assert_equal "Asia/Kolkata", settings.timezone_name

    settings.update!(timezone_name: "")
    assert_nil settings.timezone_name
  end

  test "timezone is UTC until a zone is saved" do
    settings = users(:kevin).settings

    assert_equal ActiveSupport::TimeZone["UTC"], settings.timezone

    settings.update!(timezone_name: "Asia/Kolkata")
    assert_equal ActiveSupport::TimeZone["Asia/Kolkata"], settings.timezone
  end
end
