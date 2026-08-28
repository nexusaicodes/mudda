require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  test "setting a session derives the user and account" do
    Current.session = sessions(:kevin)

    assert_equal users(:kevin), Current.user
    assert_equal accounts("37s"), Current.account
  end

  test "the account follows the user rather than the URL" do
    Current.session = sessions(:mike)

    assert_equal users(:mike), Current.user
    assert_equal accounts(:initech), Current.account
  end

  test "clearing the session clears everything derived from it" do
    Current.session = sessions(:kevin)
    Current.session = nil

    assert_nil Current.user
    assert_nil Current.account
  end

  # Authorization is what refuses a deactivated user; Current still names them, so the
  # refusal can tell a signed-out browser apart from a forbidden token.
  test "a deactivated user is still identified but has no account" do
    users(:kevin).update!(active: false)

    Current.session = sessions(:kevin)

    assert_equal users(:kevin), Current.user
    assert_nil Current.account
  end

  test "with_account overrides the derived account for the block" do
    Current.session = sessions(:kevin)

    Current.with_account(accounts(:initech)) do
      assert_equal accounts(:initech), Current.account
    end

    assert_equal accounts("37s"), Current.account
  end
end
