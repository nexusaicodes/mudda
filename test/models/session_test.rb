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
end
