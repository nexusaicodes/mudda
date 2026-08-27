module Authorization
  extend ActiveSupport::Concern

  included do
    before_action :ensure_can_access_account, if: :authenticated?
  end

  class_methods do
    def allow_unauthorized_access(**options)
      skip_before_action :ensure_can_access_account, **options
    end
  end

  private
    # An identity with no active user has no account to enter. A browser is signed out and sent
    # back to the login page — terminating the session is what keeps that from looping, since
    # otherwise the sign-in page would see an authenticated identity, bounce to root, and land
    # back here. An API client keeps its token and just gets the status code.
    def ensure_can_access_account
      unless Current.user&.active?
        if request.format.json?
          head :forbidden
        else
          terminate_session

          redirect_to login_url
        end
      end
    end
end
