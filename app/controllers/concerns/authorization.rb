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
    # An identity with no active user has no account to enter. Terminating the session is
    # what keeps this from looping: without it the sign-in page would see an authenticated
    # identity, bounce to root, and land back here.
    def ensure_can_access_account
      unless Current.user&.active?
        terminate_session

        respond_to do |format|
          format.html { redirect_to login_url }
          format.json { head :forbidden }
        end
      end
    end
end
