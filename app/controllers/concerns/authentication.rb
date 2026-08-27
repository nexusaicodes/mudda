module Authentication
  extend ActiveSupport::Concern

  included do
    # Refusals render through JsonErrors, so it comes with the concern rather than with each
    # host — Active Storage's controllers authenticate without including it.
    include JsonErrors

    before_action :require_authentication
    helper_method :authenticated?

    etag { Current.user.id if authenticated? }

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
      Current.user.present?
    end

    def require_authentication
      resume_session || request_authentication
    end

    # An Authorization header is a deliberate act, so it decides the request outright — a
    # rejected token is a refusal, not an invitation to fall back on whichever cookie the
    # browser happened to be carrying.
    def resume_session
      if session = presented_session
        set_current_session session
      end
    end

    def presented_session
      if request.authorization.present?
        find_session_by_bearer_token
      else
        find_session_by_cookie
      end
    end

    def find_session_by_cookie
      Session.find_signed(cookies.signed[:session_token])
    end

    # Non-browser clients present the same signed id the JSON sign-in hands back, as
    # `Authorization: Bearer <token>`. See API.md.
    def find_session_by_bearer_token
      authenticate_with_http_token do |token, _options|
        Session.find_signed(token)
      end
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

    def start_new_session_for(user, label: nil)
      return_to = session[:return_to_after_authenticating]
      reset_session
      session[:return_to_after_authenticating] = return_to

      attributes = { user_agent: request.user_agent, ip_address: request.remote_ip,
        kind: session_kind, label: session_label(label) }

      user.sessions.create!(attributes).tap do |session|
        set_current_session session
        cookies.signed.permanent[:session_token] = { value: session.token, httponly: true, same_site: :lax }
      end
    end

    # A JSON sign-in is a script or an agent asking for a token; a browser asking for HTML
    # gets a cookie session.
    def session_kind
      request.format.json? ? :token : :browser
    end

    # A token is labelled so auth:tokens and auth:revoke can reach it. A client may name
    # itself, so two of them can hold tokens at once — a label holds one live token, and a
    # shared default would have them revoking each other on every sign-in.
    def session_label(label)
      if request.format.json?
        label.presence || "json-sign-in"
      end
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
      Current.session&.token
    end
end
