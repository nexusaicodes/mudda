class Sessions::PasswordsController < ApplicationController
  wrap_parameters :session, include: %i[ email_address password ]

  # Throttling the only way into the app can't ride on the general cache, which is the null
  # store in test and in development without caching — a rate limit that silently counts
  # nothing is worse than none, because it reads as protection.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  require_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: :rate_limit_exceeded,
    store: RATE_LIMIT_STORE

  layout "public"

  def create
    if identity = OwnerPassword.authenticate(email_address, password)
      start_new_session_for identity

      respond_to do |format|
        format.html { redirect_to after_authentication_url }
        format.json { render json: { session_token: session_token } }
      end
    else
      respond_to do |format|
        format.html { redirect_to new_session_path, alert: "That didn't work. Check your password and try again." }
        format.json { render_unauthorized "Invalid credentials" }
      end
    end
  end

  private
    # A JSON client may send the credentials flat or wrapped, the way every other write in
    # this API accepts both; a browser form always sends them flat.
    def credentials
      params[:session] || params
    end

    def email_address
      credentials[:email_address]
    end

    def password
      credentials[:password]
    end

    def rate_limit_exceeded
      rate_limit_exceeded_message = "Try again later."

      respond_to do |format|
        format.html { redirect_to new_session_path, alert: rate_limit_exceeded_message }
        format.json { render_json_errors({ base: [ rate_limit_exceeded_message ] }, status: :too_many_requests) }
      end
    end
end
