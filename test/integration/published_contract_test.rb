require "test_helper"

# docs/openapi.yaml and docs/mcp-tools.json are the contract the docs site publishes, so they
# change in the same commit as the endpoints and tools they describe.
class PublishedContractTest < ActiveSupport::TestCase
  OPENAPI = YAML.safe_load_file(Rails.root.join("docs/openapi.yaml"), aliases: true)

  test "the OpenAPI spec describes exactly the actions that serve JSON" do
    assert_equal json_operations.sort, spec_operations.sort
  end

  test "docs/mcp-tools.json is what mcp:schema writes" do
    assert_equal Mudda::Mcp::Tools.contract, Rails.root.join("docs/mcp-tools.json").read,
      "Run bin/rails mcp:schema and commit docs/mcp-tools.json"
  end

  test "every MCP tool calls an operation in the OpenAPI spec" do
    Mudda::Mcp::Tools::ALL.each do |tool|
      assert tool.endpoints.present?, "#{tool.name_value} declares no calls"

      tool.endpoints.each do |endpoint|
        assert OPENAPI.dig("paths", endpoint[:path], endpoint[:method].downcase),
          "#{tool.name_value} calls #{endpoint[:method]} #{endpoint[:path]}, which the spec lacks"
      end
    end
  end

  private
    def json_operations
      Rails.application.routes.routes.filter_map do |route|
        if serves_json?(route)
          operation route.verb, route.path.spec.to_s.delete_suffix("(.:format)").gsub(/:(\w+)/, "{}") + ".json"
        end
      end.uniq
    end

    def spec_operations
      OPENAPI["paths"].flat_map do |path, item|
        item.keys.excluding("parameters").map { |verb| operation verb, path.gsub(/\{\w+\}/, "{}") }
      end
    end

    def serves_json?(route)
      controller = "#{route.defaults[:controller]}_controller".camelize.safe_constantize if route.defaults[:controller]
      controller.respond_to?(:json_actions) && controller.json_actions.include?(route.defaults[:action])
    end

    # Rails routes an update as both PATCH and PUT; the spec names one of them.
    def operation(verb, path)
      verb = verb.upcase.sub(/\A(PATCH|PUT)\z/, "PATCH|PUT")
      "#{verb} #{path}"
    end
end
