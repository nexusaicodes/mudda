# OAuth protected resource metadata (RFC 9728) for /mcp: where an MCP client that was refused
# with a 401 goes to learn which authorization server issues tokens for it — this one.
class Oauth::ProtectedResourcesController < ActionController::API
  def show
    render json: {
      resource: "#{request.base_url}#{Mudda::Mcp::Endpoint::PATH}",
      resource_name: "Mudda",
      authorization_servers: [ request.base_url ],
      scopes_supported: Session::SCOPES,
      bearer_methods_supported: %w[ header ]
    }
  end
end
