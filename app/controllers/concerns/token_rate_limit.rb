# One allowance per token, shared across every endpoint, so an agent stuck in a loop slows down
# instead of saturating a small box. A tool call over MCP spends two: checking the credential
# and the call itself. Browser sessions aren't limited.
module TokenRateLimit
  extend ActiveSupport::Concern

  REQUESTS_PER_MINUTE = 600

  # Its own store, as Sessions::PasswordsController keeps one: the general cache is the null
  # store in test and in development without caching.
  STORE = ActiveSupport::Cache::MemoryStore.new

  included do
    rate_limit to: REQUESTS_PER_MINUTE, within: 1.minute, scope: "token", store: STORE,
      by: -> { Current.session.id }, with: :token_rate_limit_exceeded, if: -> { Current.session&.token? }
  end

  private
    def token_rate_limit_exceeded
      response.headers["Retry-After"] = "60"
      render_json_errors({ base: [ "Rate limit exceeded: #{REQUESTS_PER_MINUTE} requests a minute per token" ] },
        status: :too_many_requests)
    end
end
