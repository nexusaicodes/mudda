require "test_helper"

class User::SettingsTest < ActiveSupport::TestCase
  test "locale is one the app speaks, or blank" do
    settings = users(:kevin).settings

    assert settings.update(locale: "ar")
    assert settings.update(locale: nil)
    assert_not settings.update(locale: "fr")
  end
end
