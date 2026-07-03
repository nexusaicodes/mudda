# Blocks the password sign-in endpoint whenever bootstrap password login isn't available — no
# MUDDA_OWNER_PASSWORD configured, or a passkey already exists. Enforced in the middleware stack,
# before routing, so a controller-layer leak can't reopen password auth once a passkey is enrolled
# (defense in depth alongside BootstrapPassword.enabled? in Sessions::PasswordsController).
class PasswordLockdown
  PATHS = [ "/session/password", "/session/password.json" ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    if password_submission?(request) && !BootstrapPassword.enabled?
      denied(request)
    else
      @app.call(env)
    end
  end

  private
    def password_submission?(request)
      request.post? && PATHS.include?(request.path_info)
    end

    def denied(request)
      if json?(request)
        [ 403, { "content-type" => "application/json" }, [ %({"message":"Password sign-in is disabled."}) ] ]
      else
        [ 303, { "location" => "/session/new" }, [] ]
      end
    end

    def json?(request)
      request.path_info.end_with?(".json") || request.get_header("HTTP_ACCEPT").to_s.include?("json")
    end
end

Rails.application.config.middleware.use PasswordLockdown
