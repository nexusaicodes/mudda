require "test_helper"

class User::SettingsTest < ActiveSupport::TestCase
  test "locale is one the app speaks, or blank" do
    settings = users(:david).settings

    assert settings.update(locale: "ar")
    assert settings.update(locale: nil)
    assert_not settings.update(locale: "fr")
  end

  test "timezone_name names a zone, or is blank" do
    settings = users(:david).settings

    assert settings.update(timezone_name: "Asia/Kolkata")
    assert settings.update(timezone_name: "Eastern Time (US & Canada)")
    assert settings.update(timezone_name: nil)
    assert_not settings.update(timezone_name: "Mars/Olympus_Mons")
    assert_includes settings.errors[:timezone_name], "is invalid"
  end

  test "timezone_name is saved as sent, aliases included" do
    settings = users(:david).settings

    { "Asia/Calcutta" => "Asia/Calcutta", "Europe/Amsterdam" => "Europe/Amsterdam", "  Asia/Kolkata " => "Asia/Kolkata" }.each do |sent, saved|
      settings.update!(timezone_name: sent)
      assert_equal saved, settings.timezone_name
    end

    settings.update!(timezone_name: "")
    assert_nil settings.timezone_name

    settings.update!(timezone_name: "Asia/Calcutta")
    assert_equal ActiveSupport::TimeZone["Asia/Kolkata"].utc_offset, settings.timezone.utc_offset
  end

  test "a zone saved before zones were checked doesn't block another setting" do
    settings = users(:david).settings
    settings.update_column :timezone_name, "bogus"

    assert settings.update(locale: "ar")
    assert_equal ActiveSupport::TimeZone["UTC"], settings.timezone
  end

  test "timezone is UTC until a zone is saved" do
    settings = users(:david).settings

    assert_equal ActiveSupport::TimeZone["UTC"], settings.timezone

    settings.update!(timezone_name: "Asia/Kolkata")
    assert_equal ActiveSupport::TimeZone["Asia/Kolkata"], settings.timezone
  end
end
