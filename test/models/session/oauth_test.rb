require "test_helper"

class Session::OauthTest < ActiveSupport::TestCase
  setup do
    @application = Doorkeeper::Application.create!(name: "Claude", redirect_uri: "https://claude.ai/callback", confidential: false)
  end

  test "Doorkeeper offers exactly the session scopes, delete only when asked for" do
    assert_equal Session::DEFAULT_SCOPES, Doorkeeper.config.default_scopes.to_a
    assert_equal Session::SCOPES.sort, Doorkeeper.config.scopes.to_a.sort
  end

  test "consent keeps one session per client, brought up to date with each grant" do
    first = Session.authorize_oauth_application(@application, user: users(:david), scopes: %w[ read write delete ])
    second = Session.authorize_oauth_application(@application, user: users(:david), scopes: %w[ read ])

    assert_equal first, second
    assert_equal %w[ read ], second.reload.scopes
    assert_equal "Claude", second.label
  end

  test "a client's session and a minted token with the same name don't replace each other" do
    minted = users(:david).sessions.create!(kind: :token, label: "Claude")
    oauth = Session.authorize_oauth_application(@application, user: users(:david), scopes: %w[ read ])

    assert Session.exists?(minted.id)
    users(:david).sessions.create!(kind: :token, label: "Claude")
    assert Session.exists?(oauth.id)
  end

  test "a client registering again under the same name replaces its earlier registration's session" do
    earlier = Session.authorize_oauth_application(@application, user: users(:david), scopes: %w[ read ])
    access_token = Doorkeeper::AccessToken.create!(application: @application, resource_owner_id: users(:david).id,
      scopes: "read", expires_in: 1.hour)
    again = Doorkeeper::Application.create!(name: "Claude", redirect_uri: "https://claude.ai/callback", confidential: false)

    Session.authorize_oauth_application(again, user: users(:david), scopes: %w[ read ])

    assert_not Session.exists?(earlier.id)
    assert access_token.reload.revoked?
  end

  test "the database holds a user to one session per client" do
    Session.authorize_oauth_application(@application, user: users(:david), scopes: %w[ read ])

    assert_raises(ActiveRecord::RecordNotUnique) do
      Session.insert_all! [ { user_id: users(:david).id, kind: "token", label: "Other", scopes: "read",
        oauth_application_id: @application.id, created_at: Time.current, updated_at: Time.current } ]
    end
  end

  test "a client's session expires once the client goes unused, a minted token a fixed time after minting" do
    session = Session.authorize_oauth_application(@application, user: users(:david), scopes: %w[ read ])
    assert_equal session.created_at + Session::Oauth::IDLE_EXPIRY, session.expires_at

    travel 30.days
    Doorkeeper::AccessToken.create!(application: @application, resource_owner_id: users(:david).id, scopes: "read", expires_in: 1.hour)
    assert_in_delta 120.days.after(session.created_at), session.expires_at, 1.second

    minted = users(:david).sessions.create!(kind: :token, label: "cli")
    assert_equal minted.created_at + Session::API_TOKEN_EXPIRY, minted.expires_at
  end

  test "an access token resolves to its client's session while it is live" do
    session = Session.authorize_oauth_application(@application, user: users(:david), scopes: %w[ read ])
    access_token = Doorkeeper::AccessToken.create!(application: @application, resource_owner_id: users(:david).id,
      scopes: "read", expires_in: 1.hour)

    assert_equal session, Session.find_by_oauth_token(access_token.plaintext_token)

    access_token.revoke
    assert_nil Session.find_by_oauth_token(access_token.plaintext_token)
  end

  test "destroying the session revokes its client's tokens" do
    session = Session.authorize_oauth_application(@application, user: users(:david), scopes: %w[ read ])
    access_token = Doorkeeper::AccessToken.create!(application: @application, resource_owner_id: users(:david).id,
      scopes: "read", expires_in: 1.hour)

    session.destroy

    assert access_token.reload.revoked?
  end

  test "a browser session can't belong to a client" do
    assert_raises(ActiveRecord::RecordInvalid) { users(:david).sessions.create!(oauth_application: @application) }
  end
end
