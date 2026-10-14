require "test_helper"

class User::ConfigurableTest < ActiveSupport::TestCase
  test "should create settings for new users" do
    user = User.create! account: accounts("37s"), email_address: "new@example.com", name: "Some new user"
    assert user.settings.present?
  end

  test "a user without settings reads the defaults" do
    user = users(:mike)
    assert_nil User::Settings.find_by(user: user)

    assert_equal ActiveSupport::TimeZone["UTC"], user.timezone
    assert_nil user.locale
  end
end
