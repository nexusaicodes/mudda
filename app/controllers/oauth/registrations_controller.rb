# Dynamic client registration (RFC 7591): an MCP client registers itself before sending the
# user to consent, so connecting one needs nothing set up in advance. Registering grants
# nothing — every client still has to be approved by the signed-in user — so it is open, and
# rate limited by address. Errors take RFC 7591's shape, not the API's envelope.
class Oauth::RegistrationsController < ActionController::API
  GRANT_TYPES = %w[ authorization_code refresh_token ]
  AUTH_METHODS = %w[ none client_secret_basic client_secret_post ]

  # Its own store, as the sign-in rate limit keeps one; see Sessions::PasswordsController.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  rate_limit to: 20, within: 1.hour, store: RATE_LIMIT_STORE,
    with: -> { render_registration_error :invalid_client_metadata, "Too many registrations; try again later", status: :too_many_requests }

  def create
    if (problem = metadata_problem)
      render_registration_error :invalid_client_metadata, problem
    elsif (application = build_application).save
      render json: registration_for(application), status: :created
    else
      render_registration_error error_code_for(application), application.errors.full_messages.to_sentence
    end
  end

  private
    def metadata_problem
      if redirect_uris.empty? || !redirect_uris.all?(String)
        "redirect_uris must list at least one URI"
      elsif redirect_uris.any? { it.start_with?("urn:") }
        "redirect_uris must be URLs; out-of-band redirects aren't supported"
      elsif (grant_types - GRANT_TYPES).any?
        "grant_types may only include #{GRANT_TYPES.to_sentence}"
      elsif response_types != %w[ code ]
        "response_types may only be code"
      elsif AUTH_METHODS.exclude?(auth_method)
        "token_endpoint_auth_method must be one of #{AUTH_METHODS.to_sentence(last_word_connector: ", or ")}"
      end
    end

    def build_application
      Doorkeeper::Application.new name: client_name, redirect_uri: redirect_uris.join("\n"), scopes: "",
        confidential: auth_method != "none"
    end

    def registration_for(application)
      {
        client_id: application.uid,
        client_id_issued_at: application.created_at.to_i,
        client_name: application.name,
        redirect_uris: redirect_uris,
        grant_types: grant_types,
        response_types: response_types,
        token_endpoint_auth_method: auth_method
      }.merge(application.confidential? ? { client_secret: application.plaintext_secret, client_secret_expires_at: 0 } : {})
    end

    def error_code_for(application)
      application.errors.include?(:redirect_uri) ? :invalid_redirect_uri : :invalid_client_metadata
    end

    def render_registration_error(code, description, status: :bad_request)
      render json: { error: code, error_description: description }, status: status
    end

    def client_name
      params[:client_name].presence&.to_s&.truncate(100) || "MCP client"
    end

    def redirect_uris
      Array(params[:redirect_uris])
    end

    def grant_types
      Array(params[:grant_types].presence || GRANT_TYPES)
    end

    def response_types
      Array(params[:response_types].presence || "code")
    end

    # RFC 7591's default is client_secret_basic; MCP clients that keep no secret send "none".
    def auth_method
      params[:token_endpoint_auth_method].presence || "client_secret_basic"
    end
end
