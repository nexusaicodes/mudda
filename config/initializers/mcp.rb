require_relative "../../lib/mudda/mcp"

Rails.application.config.middleware.insert_before ActionDispatch::Executor, Mudda::Mcp::Endpoint

# The tools' schemas read app constants (TimeWindowParser), which can't be autoloaded while
# the app is still initializing.
Rails.application.config.after_initialize do
  require_relative "../../lib/mudda/mcp/tools"
end
