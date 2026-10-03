class Session < ApplicationRecord
  # A session is how a user is present: a browser holding a cookie, or a script or agent
  # holding a token (see lib/tasks/auth.rake and the JSON sign-in). Tokens expire; a browser
  # is not signed out on a timer.
  API_TOKEN_EXPIRY = 90.days

  # What a token may do: read anything, write (create and change), and delete. A browser
  # session may do all of it. Deleting is never granted unless asked for.
  SCOPES = %w[ read write delete ]
  DEFAULT_SCOPES = %w[ read write ]

  include Oauth

  belongs_to :user

  enum :kind, %w[ browser token ].index_by(&:itself), default: :browser, validate: true

  # A label names one token, so every token carries one and no browser session does.
  validates :label, presence: true, if: :token?
  validates :label, absence: true, unless: :token?

  validates :scopes, presence: true, if: :token?
  validates :scopes, absence: true, unless: :token?
  validate :scopes_are_known, if: :token?

  before_validation :grant_default_scopes, if: :token?
  after_create :revoke_others_sharing_its_label

  # The credential a client presents, as `Authorization: Bearer <token>` or in the session
  # cookie.
  def token
    signed_id expires_in: token_expiry
  end

  def token_expiry
    API_TOKEN_EXPIRY if token?
  end

  # A minted token lasts a fixed time from minting; an OAuth client's lasts while it is used.
  def expires_at
    if oauth?
      last_refreshed_at + Oauth::IDLE_EXPIRY
    elsif token?
      created_at + API_TOKEN_EXPIRY
    end
  end

  # Stored space-separated, as OAuth writes them; accepted as a list or that same string.
  def scopes
    super.to_s.split
  end

  def scopes=(value)
    names = value.is_a?(String) ? value.split : Array(value).compact_blank.map(&:to_s)
    super(SCOPES.intersection(names).union(names).join(" ").presence)
  end

  def permits?(scope)
    browser? || scopes.include?(scope.to_s)
  end

  private
    def grant_default_scopes
      self.scopes = DEFAULT_SCOPES if scopes.empty?
    end

    def scopes_are_known
      if (unknown = scopes - SCOPES).any?
        errors.add :scopes, "includes unknown #{"scope".pluralize(unknown.size)}: #{unknown.to_sentence}"
      end
    end

    # A label names one client, and make revoke LABEL=… revokes every session carrying it.
    # Minting is a replacement, so an agent signing in on each run holds one live token. So is
    # connecting: a client that registers again under the same name (Claude Code does, on each
    # `claude mcp add`) replaces the session its earlier registration held. The two kinds never
    # replace each other — a minted token that happens to share a client's name is left alone.
    def revoke_others_sharing_its_label
      if token?
        sessions_of_its_kind.where(label: label).where.not(id: id).destroy_all
      end
    end

    def sessions_of_its_kind
      oauth? ? user.sessions.token.where.not(oauth_application_id: nil) : user.sessions.token.minted
    end
end
