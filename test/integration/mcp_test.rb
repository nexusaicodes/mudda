require "test_helper"

# The MCP endpoint an agent drives Mudda through. Each tool is one API.md call, so these pin
# the translation — arguments in, the API's answer out — rather than re-testing the API.
class McpTest < ActionDispatch::IntegrationTest
  setup do
    @headers = bearer_headers_for(:david)
    @board = boards(:writebook)
  end

  # Authentication

  test "a request without a token is refused with the API's 401" do
    post "/mcp", params: rpc("tools/list").to_json, headers: mcp_headers

    assert_response :unauthorized
    assert_equal [ "Not authenticated" ], @response.parsed_body.dig("errors", "base")
  end

  test "a session cookie is not a credential here" do
    sign_in_as :david

    post "/mcp", params: rpc("tools/list").to_json, headers: mcp_headers

    assert_response :unauthorized
  end

  test "a deactivated user's token is forbidden" do
    users(:david).deactivate

    post "/mcp", params: rpc("tools/list").to_json, headers: mcp_headers(@headers)

    assert_response :forbidden
  end

  # Protocol

  test "initialize names the server and carries the instructions" do
    result = mcp("initialize", protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" })

    assert_equal "mudda", result.dig("serverInfo", "name")
    assert_match "Triage, Backlog", result["instructions"]
  end

  test "tools/list offers every tool, read-only ones marked as such" do
    tools = mcp("tools/list")["tools"].index_by { it["name"] }

    assert_equal Mudda::Mcp::Tools::ALL.map(&:name_value).sort, tools.keys.sort
    assert tools.dig("get_card", "annotations", "readOnlyHint")
    assert_not tools.dig("update_card", "annotations", "readOnlyHint")
  end

  # Tools

  test "whoami reports the token's user" do
    assert_equal users(:david).id, call_tool("whoami")["id"]
  end

  test "list_cards narrows to one board and one lane" do
    doing = @board.columns.find_by!(name: "Doing")

    cards = call_tool("list_cards", board_id: @board.id, column_ids: [ doing.id ])["data"]

    assert_equal [ cards(:text).number ], cards.pluck("number")
  end

  test "create_card creates the card with its steps, in Triage" do
    card = call_tool("create_card", board_id: @board.id, title: "From an agent", due_on: "2026-12-01",
      steps: [ "First", "Second" ])

    assert_equal "Triage", card.dig("column", "name")
    assert_equal %w[ First Second ], card["steps"].pluck("content")
  end

  test "update_card moves a card between lanes and records the event" do
    card = cards(:logo)
    doing = @board.columns.find_by!(name: "Doing")

    assert_difference -> { card.events.where(action: "card_triaged").count } do
      call_tool("update_card", board_id: @board.id, number: card.number, column_id: doing.id, golden: true)
    end

    assert_equal doing, card.reload.column
    assert card.golden?
  end

  test "update_card edits and removes steps" do
    card = call_tool("create_card", board_id: @board.id, title: "Steps", due_on: "2026-12-01", steps: [ "Keep", "Drop" ])
    keep, drop = card["steps"].pluck("id")

    card = call_tool("update_card", board_id: @board.id, number: card["number"],
      steps: [ { id: keep, completed: true }, { id: drop, remove: true }, { content: "New" } ])

    assert_equal [ [ "Keep", true ], [ "New", false ] ], card["steps"].map { [ it["content"], it["completed"] ] }.sort
  end

  test "update_card moves a card to another board and reports its new address" do
    other = Board.create!(name: "Elsewhere", account: @board.account, creator: users(:david))

    card = call_tool("update_card", board_id: @board.id, number: cards(:logo).number, to_board_id: other.id)

    assert_equal other.id, card.dig("board", "id")
    assert_equal "Triage", card.dig("column", "name")
  end

  test "update_card refuses a board in another account" do
    result = mcp("tools/call", name: "update_card",
      arguments: { board_id: @board.id, number: cards(:logo).number, to_board_id: boards(:miltons_wish_list).id })

    assert result["isError"]
    assert_equal 404, JSON.parse(result.dig("content", 0, "text"))["status"]
  end

  test "add_note appends to the card's log" do
    card = cards(:logo)

    assert_difference -> { card.notes.count } do
      call_tool("add_note", board_id: @board.id, number: card.number, body: "Agent was here")
    end
  end

  # Errors

  test "an API refusal is a tool error carrying the status and the envelope" do
    result = mcp("tools/call", name: "get_card", arguments: { board_id: @board.id, number: 9999 })

    assert result["isError"]
    assert_equal 404, JSON.parse(result.dig("content", 0, "text"))["status"]
  end

  test "a validation failure names the field" do
    result = mcp("tools/call", name: "create_card", arguments: { board_id: @board.id, title: "x", due_on: "not a date" })

    assert result["isError"]
    assert_equal 422, JSON.parse(result.dig("content", 0, "text"))["status"]
  end

  test "an argument outside the schema is refused before any request" do
    result = mcp("tools/call", name: "list_cards", arguments: { sorted_by: "sideways" })

    assert result["isError"]
    assert_match "sorted_by", result.dig("content", 0, "text")
  end

  test "an argument the tool doesn't name is refused by name" do
    result = mcp("tools/call", name: "get_card", arguments: { board_id: @board.id, number: 1, card_id: 5 })

    assert result["isError"]
    assert_match "card_id", result.dig("content", 0, "text")
  end

  private
    def call_tool(name, **arguments)
      result = mcp("tools/call", name: name, arguments: arguments)

      assert_not result["isError"], "#{name} failed: #{result.dig("content", 0, "text")}"
      JSON.parse(result.dig("content", 0, "text"))
    end

    def mcp(method, **params)
      post "/mcp", params: rpc(method, **params).to_json, headers: mcp_headers(@headers)

      assert_response :success
      @response.parsed_body.fetch("result")
    end

    def rpc(method, **params)
      { jsonrpc: "2.0", id: 1, method: method, params: params }
    end

    def mcp_headers(extra = {})
      { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream",
        "MCP-Protocol-Version" => "2025-06-18" }.merge(extra)
    end
end
