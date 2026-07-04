class Sessions::PasswordsController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: :rate_limit_exceeded

  layout "public"

  def create
    if identity = OwnerPassword.authenticate(email_address, password)
      start_new_session_for identity

      respond_to do |format|
        format.html { redirect_to session_menu_path(script_name: nil) }
        format.json { render json: { session_token: session_token } }
      end
    else
      respond_to do |format|
        format.html { redirect_to new_session_path, alert: "That didn't work. Check your password and try again." }
        format.json { render json: { message: "Invalid credentials." }, status: :unauthorized }
      end
    end
  end

  private
    def email_address
      params[:email_address]
    end

    def password
      params[:password]
    end

    def rate_limit_exceeded
      rate_limit_exceeded_message = "Try again later."

      respond_to do |format|
        format.html { redirect_to new_session_path, alert: rate_limit_exceeded_message }
        format.json { render json: { message: rate_limit_exceeded_message }, status: :too_many_requests }
      end
    end
end
