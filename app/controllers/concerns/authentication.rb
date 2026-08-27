module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?

    etag { Current.identity.id if authenticated? }

    include LoginHelper
  end

  class_methods do
    def require_unauthenticated_access(**options)
      allow_unauthenticated_access **options
      before_action :redirect_authenticated_user, **options
    end

    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      before_action :resume_session, **options
      allow_unauthorized_access **options
    end
  end

  private
    def authenticated?
      Current.identity.present?
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      if session = find_session_by_cookie
        set_current_session session
      end
    end

    def find_session_by_cookie
      Session.find_signed(cookies.signed[:session_token])
    end

    def request_authentication
      if navigational_request?
        session[:return_to_after_authenticating] = request.url
      end

      redirect_to_login_url
    end

    # Only a page the browser is navigating to is worth returning to after signing in. The
    # sub-resource requests a signed-out page fires — the Active Storage blobs behind private
    # images, say — would otherwise land the owner on a raw file.
    def navigational_request?
      request.get? && (request.format.html? || request.format.turbo_stream?)
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || landing_url
    end

    def redirect_authenticated_user
      redirect_to main_app.root_url if authenticated?
    end

    # Rotating the session on sign-in keeps a pre-authentication one from deciding where the
    # owner lands, so the return-to destination is carried across deliberately.
    def start_new_session_for(identity)
      return_to = session[:return_to_after_authenticating]
      reset_session
      session[:return_to_after_authenticating] = return_to

      identity.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        set_current_session session
      end
    end

    def set_current_session(session)
      Current.session = session
      cookies.signed.permanent[:session_token] = { value: session.signed_id, httponly: true, same_site: :lax }
    end

    def terminate_session
      Current.session&.destroy
      cookies.delete(:session_token)
    end

    def session_token
      cookies[:session_token]
    end
end
