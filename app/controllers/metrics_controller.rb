# GET /metrics: Prometheus scrape target, off unless MUDDA_METRICS_TOKEN is set (then 404).
# Inherits from ActionController::Base, like Rails' /up, so no session, CSRF, browser or token
# rate-limit filters apply; the bearer token is its only gate.
class MetricsController < ActionController::Base
  def show
    token = ENV["MUDDA_METRICS_TOKEN"]
    return head(:not_found) if token.blank?

    if ActiveSupport::SecurityUtils.secure_compare(bearer_token.to_s, token)
      render plain: Metrics::Exposition.new.render, content_type: Metrics::Exposition::CONTENT_TYPE
    else
      StructuredLog.warn("metrics.scrape.refused", reason: bearer_token ? "invalid_token" : "missing_token", ip: request.remote_ip)
      head :unauthorized
    end
  end

  private
    def bearer_token
      request.authorization.to_s[/\ABearer (.+)\z/, 1]
    end
end
