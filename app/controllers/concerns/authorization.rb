module Authorization
  extend ActiveSupport::Concern

  included do
    include JsonErrors

    before_action :ensure_can_access_account, if: :authenticated?
  end

  class_methods do
    def allow_unauthorized_access(**options)
      skip_before_action :ensure_can_access_account, **options
    end
  end

  private
    # A deactivated user has no account to enter. What happens to the session follows its kind,
    # not the format asked for: a token is refused but kept, so it works again once the user is
    # reactivated, while a browser is signed out — which is what keeps the login page from
    # bouncing it back to root forever.
    def ensure_can_access_account
      unless Current.user&.active?
        if Current.session.token?
          render_forbidden "Not authorized"
        else
          terminate_session
          refuse_signed_out_browser
        end
      end
    end

    def refuse_signed_out_browser
      if request.format.json?
        render_forbidden "Not authorized"
      else
        redirect_to login_url
      end
    end
end
