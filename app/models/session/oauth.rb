# A client connected over OAuth holds a token session like a minted one — labelled with the
# client's name, carrying the scopes the user consented to — so scopes, the rate limit, agent
# attribution, and revocation need nothing of their own. What differs is the credential: the
# client presents Doorkeeper's short-lived access tokens, refreshed as they expire, and each one
# resolves to this session. Revoking the session revokes them.
module Session::Oauth
  extend ActiveSupport::Concern

  LOOPBACK_HOSTS = %w[ localhost 127.0.0.1 ::1 [::1] ]

  # A client that hasn't refreshed its access token for this long can't refresh it any more
  # (see config/initializers/doorkeeper.rb), so a client that stopped being used stops working
  # instead of holding a refresh token forever.
  IDLE_EXPIRY = 90.days

  # Where a native client (Claude Code, Cursor) listens for the code; see
  # config/initializers/doorkeeper.rb.
  def self.loopback?(host)
    LOOPBACK_HOSTS.include?(host)
  end

  included do
    belongs_to :oauth_application, class_name: "Doorkeeper::Application", optional: true

    # A session's own signed id is a credential only for a minted token. An OAuth session is
    # reached through its client's access tokens, which expire and are revoked on their own.
    scope :minted, -> { where(oauth_application_id: nil) }

    validates :oauth_application, absence: true, unless: :token?

    after_destroy_commit :revoke_oauth_tokens, if: :oauth?
  end

  class_methods do
    # The session an unexpired, unrevoked access token was issued under, if it is still there.
    def find_by_oauth_token(token)
      if (access_token = Doorkeeper::AccessToken.by_token(token))&.accessible?
        self.token.find_by(user_id: access_token.resource_owner_id, oauth_application_id: access_token.application_id)
      end
    end

    # Consent creates the client's session, or brings it up to date with what was granted this
    # time. A user has one session per client, which a unique index holds even when two consents
    # arrive together.
    def authorize_oauth_application(application, user:, scopes:, **attributes)
      attributes = attributes.merge(label: application.name.truncate(100), scopes: scopes)

      user.sessions.token.create_or_find_by!(oauth_application: application) { it.assign_attributes(attributes) }
        .tap { it.update!(attributes) }
    end
  end

  def oauth?
    oauth_application_id.present?
  end

  # When the client last refreshed its access token, which is when it was last used, give or
  # take the token's hour.
  def last_refreshed_at
    Doorkeeper::AccessToken.where(application_id: oauth_application_id, resource_owner_id: user_id).maximum(:created_at) || created_at
  end

  private
    def revoke_oauth_tokens
      Doorkeeper::AccessToken.revoke_all_for oauth_application_id, user
      Doorkeeper::AccessGrant.revoke_all_for oauth_application_id, user
    end
end
