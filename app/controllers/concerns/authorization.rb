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

    # For pages that manage credentials. A token can't mint tokens or enroll passkeys — either
    # would turn what it was granted into a browser session, which nothing limits.
    def require_browser_session(**options)
      before_action :ensure_browser_session, **options
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
    # DELETE or a write that removes nested records, and everything else writes. A browser
    # session is never limited.
    def ensure_token_permits_request
      unless Current.session.permits?(scope_for_request)
        render_forbidden "This token is not granted the #{scope_for_request} scope"
      end
    end

    def scope_for_request
      if request.get? || request.head?
        "read"
      elsif request.delete? || removes_nested_records?(request.request_parameters)
        "delete"
      else
        "write"
      end
    end

    def ensure_browser_session
      head :forbidden unless Current.session.browser?
    end

    # Nested attributes marked `_destroy` (a card's steps) are deleted as surely as by a DELETE.
    def removes_nested_records?(value)
      case value
      when Hash
        value.any? { |key, nested| (key.to_s == "_destroy" && ActiveModel::Type::Boolean.new.cast(nested)) || removes_nested_records?(nested) }
      when Array
        value.any? { |nested| removes_nested_records?(nested) }
      else
        false
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
