require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  test "setting a session derives the identity, user, and account" do
    Current.session = sessions(:kevin)

    assert_equal identities(:kevin), Current.identity
    assert_equal users(:kevin), Current.user
    assert_equal accounts("37s"), Current.account
  end

  test "the account follows the identity rather than the URL" do
    Current.session = sessions(:mike)

    assert_equal users(:mike), Current.user
    assert_equal accounts(:initech), Current.account
  end

  test "clearing the session clears everything derived from it" do
    Current.session = sessions(:kevin)
    Current.session = nil

    assert_nil Current.identity
    assert_nil Current.user
    assert_nil Current.account
  end

  test "an identity with no user has no account" do
    identities(:kevin).users.delete_all

    Current.session = sessions(:kevin)

    assert_equal identities(:kevin), Current.identity
    assert_nil Current.user
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
