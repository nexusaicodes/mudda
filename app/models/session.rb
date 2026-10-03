class Session < ApplicationRecord
  # A session is how a user is present: a browser holding a cookie, or a script or agent
  # holding a token (see lib/tasks/auth.rake and the JSON sign-in). Tokens expire; a browser
  # is not signed out on a timer.
  API_TOKEN_EXPIRY = 90.days

  belongs_to :user

  enum :kind, %w[ browser token ].index_by(&:itself), default: :browser, validate: true

  # A label names one token, so every token carries one and no browser session does.
  validates :label, presence: true, if: :token?
  validates :label, absence: true, unless: :token?

  after_create :revoke_others_sharing_its_label

  # The credential a client presents, as `Authorization: Bearer <token>` or in the session
  # cookie.
  def token
    signed_id expires_in: token_expiry
  end

  def token_expiry
    API_TOKEN_EXPIRY if token?
  end

  private
    # A label names one client, and make revoke LABEL=… revokes every session carrying it.
    # Minting is a replacement, so an agent signing in on each run holds one live token.
    def revoke_others_sharing_its_label
      if token?
        user.sessions.token.where(label: label).where.not(id: id).destroy_all
      end
    end
end
