module Authorization
  extend ActiveSupport::Concern

  included do
    include JsonErrors

    before_action :ensure_can_access_account, if: :authenticated?
    before_action :ensure_token_permits_request, if: :authenticated?
  end

  class_methods do
    def allow_unauthorized_access(**options)
      skip_before_action :ensure_can_access_account, **options
      skip_before_action :ensure_token_permits_request, **options
    end

    # For an action any token may take whatever it was granted — ending its own session.
    def allow_any_token_scope(**options)
      skip_before_action :ensure_token_permits_request, **options
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

    # A token does what its scopes grant, read off the verb: reading is a GET, deleting a
    # DELETE, and everything else writes. A browser session is never limited.
    def ensure_token_permits_request
      unless Current.session.permits?(scope_for_request)
        render_forbidden "This token is not granted the #{scope_for_request} scope"
      end
    end

    def scope_for_request
      if request.get? || request.head?
        "read"
      elsif request.delete?
        "delete"
      else
        "write"
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
