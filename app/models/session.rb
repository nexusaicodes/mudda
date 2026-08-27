class Session < ApplicationRecord
  # A labelled session is an API token minted for a script or agent (see lib/tasks/auth.rake
  # and the JSON sign-in). An unlabelled one is a browser cookie.
  API_TOKEN_EXPIRY = 90.days

  belongs_to :identity

  after_create :revoke_others_sharing_its_label

  # The credential a client presents, as `Authorization: Bearer <token>` or in the session
  # cookie. API tokens expire; a browser is not signed out on a timer.
  def token
    signed_id expires_in: (API_TOKEN_EXPIRY if api_token?)
  end

  def api_token?
    label.present?
  end

  private
    # A label names one client, and make revoke LABEL=… revokes every session carrying it.
    # Minting is a replacement, so an agent signing in on each run holds one live token.
    def revoke_others_sharing_its_label
      if api_token?
        identity.sessions.where(label: label).where.not(id: id).destroy_all
      end
    end
end
