# Mudda is its own OAuth 2.1 authorization server, so an MCP client (claude.ai, ChatGPT, Cursor,
# Claude Code) can be connected by signing in and approving it, with no token to copy. A client
# registers itself (Oauth::RegistrationsController), sends the user here to consent
# (Oauth::AuthorizationsController), and redeems the code with PKCE. What it is granted is a
# token Session like any other (Session::Oauth), so scopes, the rate limit, agent attribution,
# and revocation all work the same. See MCP.md → OAuth.
Doorkeeper.configure do
  orm :active_record

  # Consent needs the signed-in browser, so the authorization screen is one of the app's own
  # pages; the token endpoint stays a bare API controller.
  base_controller "ApplicationController"

  # Authentication has already sent a signed-out browser to the login page and back. A token
  # can't stand in for the user here: a read-only token must not be able to grant itself more.
  resource_owner_authenticator do
    if Current.session&.browser?
      Current.user
    else
      head :forbidden
    end
  end

  grant_flows %w[ authorization_code ]
  use_refresh_token
  force_pkce
  pkce_code_challenge_methods %w[ S256 ]

  # Session::SCOPES and Session::DEFAULT_SCOPES, spelled out because app constants can't be
  # loaded while initializing (test/models/session/oauth_test.rb holds the two together).
  default_scopes :read, :write
  optional_scopes :delete
  enforce_configured_scopes

  access_token_expires_in 1.hour
  authorization_code_expires_in 10.minutes

  hash_token_secrets
  hash_application_secrets

  # Loopback redirects are how native clients (Claude Code, Cursor) receive the code, so plain
  # http is allowed there and nowhere else. Private-use schemes (cursor://…) are allowed too.
  force_ssl_in_redirect_uri { |uri| !Session::Oauth.loopback?(uri.host) }
end

# A client that is removed takes the sessions it was granted with it.
Rails.application.config.to_prepare do
  Doorkeeper::Application.has_many :sessions, foreign_key: :oauth_application_id, dependent: :destroy
end
