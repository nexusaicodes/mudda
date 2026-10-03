class Session < ApplicationRecord
  # A session is how a user is present: a browser holding a cookie, or a script or agent
  # holding a token (see lib/tasks/auth.rake and the JSON sign-in). Tokens expire; a browser
  # is not signed out on a timer.
  API_TOKEN_EXPIRY = 90.days

  # What a token may do: read anything, write (create and change), and delete. A browser
  # session may do all of it. Deleting is never granted unless asked for.
  SCOPES = %w[ read write delete ]
  DEFAULT_SCOPES = %w[ read write ]

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
    # Minting is a replacement, so an agent signing in on each run holds one live token.
    def revoke_others_sharing_its_label
      if token?
        user.sessions.token.where(label: label).where.not(id: id).destroy_all
      end
    end
end
