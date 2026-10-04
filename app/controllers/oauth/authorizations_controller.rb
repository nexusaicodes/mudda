# The consent screen an OAuth client sends the user to. Doorkeeper runs the protocol; this adds
# what Mudda needs around it: the user picks which of the requested scopes to grant, a client may
# only ask for a token for this server, and consent becomes the client's session.
class Oauth::AuthorizationsController < Doorkeeper::AuthorizationsController
  layout "public"

  # The redirect back to the client follows a form submission, which the page's form-action
  # would otherwise refuse for any origin but this one, so that origin joins the sources the app
  # already allows. It is set ahead of the checks below, because a page they render — the
  # consent screen again, with nothing ticked — is submitted too.
  content_security_policy do |policy|
    policy.form_action(*policy.directives.fetch("form-action", [ "'self'" ]), *redirect_source)
  end

  before_action :ensure_resource_is_this_server
  before_action :narrow_scopes_to_those_granted, only: :create

  private
    # RFC 8707: a client names the resource it wants a token for. Tokens from here work only
    # here, so naming any other server is an error rather than a token that wouldn't.
    def ensure_resource_is_this_server
      if (resource = params[:resource].presence) && !this_server?(resource)
        render :error, status: :bad_request, locals: { message: "This app asked for access to #{resource}, which isn't this Mudda." }
      end
    end

    def this_server?(resource)
      URI.parse(resource).then { |uri| "#{uri.scheme}://#{uri.authority}" == request.base_url }
    rescue URI::InvalidURIError
      false
    end

    # The form ticks each requested scope; what goes on to Doorkeeper is the ticked ones. With
    # none ticked there is nothing to grant, so the screen comes back saying so.
    def narrow_scopes_to_those_granted
      return unless pre_auth.authorizable?

      granted = pre_auth.scopes.to_a & Array(params[:granted_scopes])

      if granted.any?
        params[:scope] = granted.join(" ")
        @pre_auth = nil
      else
        flash.now[:alert] = "Choose at least one thing #{pre_auth.client.name} may do, or deny it."
        render :new, status: :unprocessable_entity
      end
    end

    def after_successful_authorization(context)
      super

      Session.authorize_oauth_application pre_auth.client.application, user: current_resource_owner,
        scopes: pre_auth.scopes.to_a, user_agent: request.user_agent, ip_address: request.remote_ip
    end

    # Doorkeeper approves a confidential client without asking when it already holds a token for
    # these scopes. Consent here also sets what the client's session may do, so the user is
    # always asked: an old token must not quietly restore scopes the user has since narrowed.
    def can_authorize_response?
      false
    end

    # Only a redirect URI registered to the client is trusted with a place in the policy.
    def redirect_source
      if pre_auth.client_valid? && (uri = URI.parse(pre_auth.redirect_uri.to_s)).scheme
        uri.host ? "#{uri.scheme}://#{uri.authority}" : "#{uri.scheme}:"
      end
    rescue URI::InvalidURIError
      nil
    end
end
