require_relative "../../lib/mudda/mcp"

# Inside the executor and after the request id is settled; see Mudda::Mcp::Endpoint.
Rails.application.config.middleware.insert_after ActionDispatch::RequestId, Mudda::Mcp::Endpoint

MCP.configure do |config|
  # A tool's arguments are the user's card titles and notes, so a report names the call, never
  # what was passed to it.
  config.exception_reporter = ->(exception, context) do
    Rails.error.report exception, handled: true, severity: :error, source: "mudda.mcp",
      context: Mudda::Mcp::Endpoint.call_named_by(context.is_a?(Hash) ? context[:request] : nil)
  end

  # One line per JSON-RPC call: its method, tool, duration and, for a failure, the error type.
  config.around_request = ->(data, &request) do
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    request.call
  ensure
    StructuredLog.public_send(data[:error] ? :warn : :info, "mcp.request.completed",
      mcp_method: data[:method], mcp_tool: data[:tool_name], mcp_error: data[:error],
      duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(1))
  end
end

# The tools' schemas read app constants (TimeWindowParser), which can't be autoloaded while
# the app is still initializing.
Rails.application.config.after_initialize do
  require_relative "../../lib/mudda/mcp/tools"
end
