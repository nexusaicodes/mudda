require "mcp"

# The MCP face of the JSON API: a Streamable HTTP endpoint at /mcp whose tools are thin
# descriptions of API.md calls. It sits in front of the Rails executor, so it is required
# rather than autoloaded (lib/mudda is outside autoload_lib) and a change to it needs a server
# restart. See MCP.md and config/initializers/mcp.rb.
module Mudda
  module Mcp
    VERSION = "1"
  end
end

require_relative "mcp/api"
require_relative "mcp/endpoint"
