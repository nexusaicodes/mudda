class My::PasswordsController < ApplicationController
  # Its own store, for the same reason as Sessions::PasswordsController's.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  require_browser_session
  rate_limit to: 10, within: 3.minutes, only: :update, store: RATE_LIMIT_STORE,
    with: -> { redirect_to edit_my_password_path, alert: t("sessions.passwords.create.rate_limited") }

  def edit
  end

  # Changing the password signs out every other browser; this one, tokens, and passkeys stay.
  def update
    if OwnerPassword.authenticate(Current.user.email_address, params[:current_password]).nil?
      flash.now[:alert] = t(".wrong_password")
      render :edit, status: :unprocessable_entity
    elsif Current.user.update(password_params)
      Current.user.sessions.browser.where.not(id: Current.session).destroy_all
      redirect_to user_path(Current.user), notice: t(".changed")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def password_params
      params.expect(user: %i[ password password_confirmation ])
    end
end
