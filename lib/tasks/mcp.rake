namespace :mcp do
  desc "Write every MCP tool's name, description, input schema, scope, and API calls to docs/mcp-tools.json"
  task schema: :environment do
    path = Rails.root.join("docs/mcp-tools.json")
    File.write(path, Mudda::Mcp::Tools.contract)
    puts "Wrote #{Mudda::Mcp::Tools::ALL.size} tools to #{path.relative_path_from(Rails.root)}."
  end
end
