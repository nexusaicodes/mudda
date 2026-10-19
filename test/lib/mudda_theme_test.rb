require "test_helper"

class MuddaThemeTest < ActiveSupport::TestCase
  test "the error pages' token copy matches the installed mudda-theme" do
    assert_empty MuddaTheme.stale_static_files(Rails.root.join("public/mudda-theme")),
      "run bin/rails mudda_theme:sync_static"
  end
end
