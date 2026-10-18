require "test_helper"

# docs/openapi.yaml and docs/mcp-tools.json are the contract the docs site publishes, so they
# change in the same commit as the endpoints and tools they describe.
class PublishedContractTest < ActionDispatch::IntegrationTest
  # Aliases are refused: the docs site reads the spec with a JSON-schema YAML loader, which
  # renders `<<` merge keys literally, so every example is written out in full.
  OPENAPI = YAML.safe_load_file(Rails.root.join("docs/openapi.yaml"), aliases: false)
  SCHEMAS = JSONSchemer.openapi(OPENAPI)

  # JSON endpoints that aren't Mudda's own controllers, so `serves_json` doesn't declare them.
  FRAMEWORK_OPERATIONS = [ "POST /rails/active_storage/direct_uploads", "POST /my/passkey_challenge" ]

  test "the OpenAPI spec describes exactly the actions that serve JSON" do
    assert_equal (json_operations + FRAMEWORK_OPERATIONS).sort, spec_operations.sort
  end

  test "the framework operations the spec describes are routed" do
    FRAMEWORK_OPERATIONS.each do |operation|
      verb, path = operation.split(" ")
      assert Rails.application.routes.recognize_path(path, method: verb), "#{operation} is not routed"
    end
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

  test "real responses match the spec's schemas" do
    sign_in_as :david
    board = boards(:writebook)

    post board_cards_path(board, format: :json), params: { title: "Ship it", description: "<div>Cut the <strong>release</strong>.</div>",
      steps_attributes: [ { content: "First" } ] }, as: :json
    assert_response :created
    card = board.cards.find_by!(number: response.parsed_body["number"])
    post board_card_notes_path(board, card, format: :json), params: { body: "Deployed to staging." }, as: :json
    assert_response :created
    note = card.notes.last

    assert_matches_schema "CurrentUser", my_user_path(format: :json)
    assert_matches_schema "BoardWithColumns", board_path(board, format: :json)
    assert_matches_schema "CardDetail", board_card_path(board, card, format: :json)
    assert_matches_schema "Note", board_card_note_path(board, card, note, format: :json)
    assert_matches_schema "Page", cards_path(format: :json), items: "Card"
    assert_matches_schema "Page", board_cards_path(board, format: :json), items: "Card"
  end

  test "the spec's examples match its own schemas" do
    OPENAPI.dig("components", "examples").each do |name, example|
      if OPENAPI.dig("components", "schemas", name)
        assert_valid_against name, example["value"], "the #{name} example"
      end
    end
  end

  private
    def json_operations
      Rails.application.routes.routes.filter_map do |route|
        if serves_json?(route) && route.path.spec.to_s != "/"
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

    def assert_matches_schema(name, path, items: nil)
      get path
      assert_response :success
      assert_valid_against name, response.parsed_body, "GET #{path}"

      if items
        assert_not_empty response.parsed_body["data"], "GET #{path} returned no records to check"
        response.parsed_body["data"].each { |record| assert_valid_against items, record, "a record from GET #{path}" }
      end
    end

    def assert_valid_against(name, data, subject)
      errors = SCHEMAS.schema(name).validate(data).map { |error| error["error"] }
      assert_empty errors, "#{subject} doesn't match the spec's #{name} schema"
    end
end
