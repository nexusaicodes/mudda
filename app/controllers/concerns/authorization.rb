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
    # A deactivated user has no account to enter. Signing the browser out is what keeps the
    # login page from bouncing it back to root forever; a token keeps working.
    def ensure_can_access_account
      unless Current.user&.active?
        if request.format.json?
          render_forbidden "Not authorized"
        else
          terminate_session

          redirect_to login_url
        end
      end
    end
end
