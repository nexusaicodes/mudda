module Authentication
  extend ActiveSupport::Concern

  included do
    # Refusals render through JsonErrors, so a host that authenticates gets the envelope
    # whether or not it remembered to include it (Active Storage's controllers do not).
    include JsonErrors

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
      if session = find_session_by_cookie || find_session_by_bearer_token
        set_current_session session
      end
    end

    def find_session_by_cookie
      Session.find_signed(cookies.signed[:session_token])
    end

    # Non-browser clients present the same signed id the JSON sign-in hands back, as
    # `Authorization: Bearer <token>`. See API.md.
    def find_session_by_bearer_token
      if token = bearer_token
        Session.find_signed(token)
      end
    end

    # The scheme is case-insensitive per RFC 7235, and clients vary on how they pad the value.
    def bearer_token
      request.authorization&.match(/\ABearer\s+(.+?)\s*\z/i)&.captures&.first
    end

    # An API client needs an error it can read, not a login page. Every other format —
    # including the binary ones Active Storage serves — keeps redirecting, so respond_to is
    # the wrong tool here: it would answer 406 to anything it wasn't told about.
    def request_authentication
      if request.format.json?
        render_unauthorized "Not authenticated"
      else
        if navigational_request?
          session[:return_to_after_authenticating] = request.url
        end

        redirect_to_login_url
      end
    end

    def navigational_request?
      request.get? && (request.format.html? || request.format.turbo_stream?)
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || landing_url
    end

    def redirect_authenticated_user
      if authenticated? && !json_credential_request?
        redirect_to main_app.root_url
      end
    end

    # Minting a fresh token while holding a valid one is legitimate, and a JSON client can't
    # act on a redirect to a page, so a token exchange is allowed through.
    def json_credential_request?
      request.post? && request.format.json?
    end

    def start_new_session_for(identity)
      return_to = session[:return_to_after_authenticating]
      reset_session
      session[:return_to_after_authenticating] = return_to

      attributes = { user_agent: request.user_agent, ip_address: request.remote_ip, label: session_label }

      identity.sessions.create!(attributes).tap do |session|
        set_current_session session
        cookies.signed.permanent[:session_token] = { value: session.signed_id, httponly: true, same_site: :lax }
      end
    end

    # A token handed to a JSON client is labelled so auth:tokens and auth:revoke can reach it;
    # a browser session carries no label.
    def session_label
      "json-sign-in" if request.format.json?
    end

    def set_current_session(session)
      Current.session = session
    end

    def terminate_session
      Current.session&.destroy
      cookies.delete(:session_token)
    end

    # The credential a non-browser client presents as `Authorization: Bearer <token>`. This is
    # the session's signed id — not the cookie's value, which wraps that id in a second layer
    # of cookie signing and so can't be handed back to Session.find_signed.
    def session_token
      Current.session&.signed_id
    end
end
