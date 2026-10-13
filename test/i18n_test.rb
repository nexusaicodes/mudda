require "test_helper"
require "i18n/tasks"

class I18nTest < ActiveSupport::TestCase
  setup do
    @i18n = I18n::Tasks::BaseTask.new
  end

  test "every key used in the app exists in every locale" do
    missing = @i18n.missing_keys
    assert_empty missing, "Missing #{missing.leaves.count} keys, run `i18n-tasks missing` to show them"
  end

  test "every key in the locale files is used" do
    unused = @i18n.unused_keys
    assert_empty unused, "#{unused.leaves.count} unused keys, run `i18n-tasks unused` to show them"
  end
end
