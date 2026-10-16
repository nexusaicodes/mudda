# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3000)

# Specifies the `pidfile` that Puma will use.
pidfile ENV.fetch("PIDFILE", "tmp/pids/server.pid")

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# What escapes the Rails app altogether, or fails in Puma itself, is reported like any other
# error and answered with a 500 whose reference matches the logged error.reported line.
require "securerandom"
lowlevel_error_handler do |error, env|
  reference = env&.dig("action_dispatch.request_id") || SecureRandom.uuid

  if defined?(Rails) && Rails.respond_to?(:error)
    Rails.error.report error, handled: false, source: "puma.lowlevel", context: { request_id: reference }
  end

  [ 500, { "content-type" => "text/plain; charset=utf-8", "x-request-id" => reference },
    [ "Internal server error. Reference: #{reference}\n" ] ]
end
