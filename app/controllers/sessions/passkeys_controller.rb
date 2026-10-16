class Sessions::PasskeysController < ApplicationController
  include ActionPack::Passkey::Request

  # Its own store, as Sessions::PasswordsController keeps one: the general cache is the null
  # store in test and in development without caching.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  require_unauthenticated_access
  serves_json :create
  rate_limit to: 10, within: 3.minutes, only: :create, with: :rate_limit_exceeded, store: RATE_LIMIT_STORE

  def create
    if credential = ActionPack::Passkey.authenticate(passkey_authentication_params)
      start_new_session_for credential.holder

      respond_to do |format|
        format.html { redirect_to after_authentication_url }
        format.json { render json: { session_token: session_token } }
      end
    else
      StructuredLog.warn("auth.signin.failed", method: "passkey", reason: "passkey_rejected", ip: request.remote_ip)

      respond_to do |format|
        format.html { redirect_to new_session_path, alert: t(".failed") }
        format.json { render_unauthorized "That passkey didn't work. Try again." }
      end
    end
  end

  private
    def rate_limit_exceeded
      rate_limit_exceeded_message = "Try again later."

      respond_to do |format|
        format.html { redirect_to new_session_path, alert: t("sessions.passkeys.create.rate_limited") }
        format.json { render_json_errors({ base: [ rate_limit_exceeded_message ] }, status: :too_many_requests) }
      end
    end
end
