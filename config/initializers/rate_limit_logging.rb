# Every rate limiter (sign-in, passkeys, password change, tokens, OAuth registration, platform
# messages) reports through this one subscriber: a hit is logged at warn with what was limited.
# The limit's key is left out, since it is a session id or an IP the request line already carries.
ActiveSupport::Notifications.subscribe("rate_limit.action_controller") do |event|
  payload = event.payload

  StructuredLog.warn("rate_limit.hit", scope: payload[:scope], name: payload[:name], count: payload[:count],
    limit: payload[:to], within_s: payload[:within].to_i, path: payload[:request]&.path)
end
