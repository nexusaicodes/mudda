# OAuth authorization server metadata (RFC 8414): the endpoints and the parts of OAuth 2.1 this
# server supports, which an MCP client reads before registering and sending the user to consent.
class Oauth::AuthorizationServersController < ActionController::API
  def show
    render json: {
      issuer: request.base_url,
      authorization_endpoint: oauth_authorization_url,
      token_endpoint: oauth_token_url,
      registration_endpoint: oauth_registrations_url,
      revocation_endpoint: oauth_revoke_url,
      scopes_supported: Session::SCOPES,
      response_types_supported: %w[ code ],
      response_modes_supported: %w[ query ],
      grant_types_supported: Oauth::RegistrationsController::GRANT_TYPES,
      code_challenge_methods_supported: %w[ S256 ],
      token_endpoint_auth_methods_supported: Oauth::RegistrationsController::AUTH_METHODS,
      revocation_endpoint_auth_methods_supported: Oauth::RegistrationsController::AUTH_METHODS
    }
  end
end
