require "test_helper"
require "opentelemetry/sdk"
require "opentelemetry/instrumentation/rack"

# An MCP request's spans, captured in memory. The tracer provider is this test's alone while
# it runs; teardown shuts it down and puts back a no-op one, so later tests in the same worker
# record nothing.
class McpTracingTest < ActionDispatch::IntegrationTest
  setup do
    @headers = bearer_headers_for(:david)
    @board = boards(:writebook)
    @exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    @provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    @provider.add_span_processor OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(@exporter)
    OpenTelemetry.tracer_provider = @provider
  end

  teardown do
    @provider.shutdown
    OpenTelemetry.tracer_provider = OpenTelemetry::Trace::TracerProvider.new
  end

  test "a tool call is a SERVER span naming the tool, with each API call a child of it" do
    call_tool "create_card", board_id: @board.id, title: "Secret plans"

    span = finished_span("tools/call create_card")
    assert_equal :server, span.kind
    assert_equal "tools/call", span.attributes["mcp.method.name"]
    assert_equal "create_card", span.attributes["gen_ai.tool.name"]
    assert_equal "execute_tool", span.attributes["gen_ai.operation.name"]
    assert_equal "7", span.attributes["jsonrpc.request.id"]
    assert_nil span.attributes["error.type"]

    children = @exporter.finished_spans.select { it.parent_span_id == span.span_id }
    assert_equal [ "/my/user.json", "/boards/#{@board.id}/cards.json" ], children.sort_by(&:start_timestamp).map { it.attributes["url.path"] }
    assert_equal [ 200, 201 ], children.sort_by(&:start_timestamp).map { it.attributes["http.response.status_code"] }
    assert_equal david_account_id, children.first.attributes["mudda.account_id"]
    assert_no_match "Secret plans", @exporter.finished_spans.map { it.attributes.to_s }.join
  end

  test "a tool answering isError is a tool_error" do
    call_tool "get_card", board_id: @board.id, number: 999_999

    span = finished_span("tools/call get_card")
    assert_equal "tool_error", span.attributes["error.type"]
    assert_equal OpenTelemetry::Trace::Status::ERROR, span.status.code
  end

  private
    def call_tool(name, **arguments)
      post "/mcp", params: { jsonrpc: "2.0", id: 7, method: "tools/call", params: { name: name, arguments: arguments } }.to_json,
        headers: { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream", "MCP-Protocol-Version" => "2025-06-18" }.merge(@headers)

      assert_response :success
    end

    def finished_span(name)
      @exporter.finished_spans.find { it.name == name } or flunk "no #{name} span in #{@exporter.finished_spans.map(&:name)}"
    end

    def david_account_id
      users(:david).account_id
    end
end
