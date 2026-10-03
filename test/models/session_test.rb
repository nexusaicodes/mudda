require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "a session says how its user is present" do
    browser = users(:david).sessions.create!
    token = users(:david).sessions.create!(kind: :token, label: "agent")

    assert browser.browser?
    assert token.token?
    assert_equal [ token ], users(:david).sessions.token.to_a
  end

  test "a label names a token, and only a token" do
    assert_raises(ActiveRecord::RecordInvalid) { users(:david).sessions.create!(kind: :token) }
    assert_raises(ActiveRecord::RecordInvalid) { users(:david).sessions.create!(label: "agent") }
  end

  test "only a token expires" do
    assert_nil Session.new(kind: :browser).token_expiry
    assert_equal Session::API_TOKEN_EXPIRY, Session.new(kind: :token).token_expiry
  end

  test "a token reads and writes unless it is granted more, and never deletes by default" do
    token = users(:david).sessions.create!(kind: :token, label: "agent")

    assert_equal %w[ read write ], token.scopes
    assert token.permits?(:write)
    assert_not token.permits?(:delete)
  end

  test "scopes are accepted as a list or a space-separated string, and stored in order" do
    assert_equal Session::SCOPES, users(:david).sessions.create!(kind: :token, label: "a", scopes: "delete read write").scopes
    assert_equal %w[ read ], users(:david).sessions.create!(kind: :token, label: "b", scopes: [ "read", "" ]).scopes
  end

  test "an unknown scope is refused" do
    session = users(:david).sessions.build(kind: :token, label: "agent", scopes: "read admin")

    assert_not session.valid?
    assert_match "admin", session.errors[:scopes].first
  end

  test "a browser session carries no scopes and is limited by none" do
    browser = users(:david).sessions.create!

    assert_empty browser.scopes
    assert browser.permits?(:delete)
    assert_raises(ActiveRecord::RecordInvalid) { users(:david).sessions.create!(scopes: "read") }
  end
end
