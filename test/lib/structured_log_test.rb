require "test_helper"

class StructuredLogTest < ActiveSupport::TestCase
  setup do
    @io = StringIO.new
    @logger = ActiveSupport::TaggedLogging.logger(@io)
    @logger.formatter = StructuredLog::Formatter.new.extend(ActiveSupport::TaggedLogging::Formatter)
    @previous = Rails.logger
    Rails.logger = @logger
  end

  teardown { Rails.logger = @previous }

  test "domain events are one JSON line with the request context and masked emails" do
    with_json do
      Rails.event.set_context(request_id: "req-1")
      StructuredLog.warn("board.delivery.failed", account_id: 7, msg: "mail ada@example.com")

      line = JSON.parse(@io.string.lines.last)
      assert_equal [ "warn", "board.delivery.failed", "req-1", 7, "mudda-board" ], line.values_at("level", "event", "request_id", "account_id", "service")
      assert_match(/\A\d{4}-\d\d-\d\dT[\d:.]+Z\z/, line["ts"])
      assert_equal "mail ada@example.com", line["msg"], "payload strings are the caller's to mask"
    end
  end

  test "the parameter filter hides every OAuth secret" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    secrets = %w[ token access_token refresh_token client_secret code code_verifier authorization password ]

    filtered = filter.filter(secrets.index_with("leak").merge("state" => "xyz", "Authorization" => "Bearer leak"))

    assert_equal [ "[FILTERED]" ], filtered.except("state").values.uniq
    assert_equal "xyz", filtered["state"]
  end

  test "filter_query hides secret values and keeps the rest" do
    assert_equal "code=[FILTERED]&state=xyz&access_token=[FILTERED]", StructuredLog.filter_query("code=abc&state=xyz&access_token=t0k")
    assert_nil StructuredLog.filter_query(nil)
  end

  test "a redirect carrying an OAuth code or token is filtered from the log" do
    %w[ code access_token refresh_token ].each do |name|
      assert Rails.application.config.filter_redirect.any? { "https://client.test/cb?state=x&#{name}=abc".match?(it) }, name
    end
    assert_not Rails.application.config.filter_redirect.any? { "https://board.test/boards/1?page=2".match?(it) }
  end

  test "the logger level gates events" do
    @logger.level = :warn
    with_json do
      StructuredLog.info("board.delivery.succeeded")
      StructuredLog.error("board.delivery.abandoned")
    end

    assert_equal [ "board.delivery.abandoned" ], @io.string.lines.map { JSON.parse(_1)["event"] }
  end

  test "stray logger strings become JSON with emails masked" do
    with_json { @logger.warn("could not reach ada@example.com") }

    assert_equal "could not reach a***@example.com", JSON.parse(@io.string)["msg"]
  end

  test "request outcomes get a level from their status" do
    with_json do
      Rails.event.notify("action_controller.request_completed", controller: "X", action: "y", status: 503, duration_ms: 1.0, gc_time_ms: 0.0)
      Rails.event.notify("action_controller.request_completed", controller: "X", action: "y", status: 401, duration_ms: 1.0, gc_time_ms: 0.0)
    end

    assert_equal %w[ error warn ], @io.string.lines.map { JSON.parse(_1)["level"] }
  end

  test "error reports are logged once with a reference id, cause and app backtrace" do
    with_json do
      Rails.event.set_context(request_id: "req-9")
      begin
        begin
          raise IOError, "socket closed"
        rescue IOError
          raise ArgumentError, "bad ada@example.com"
        end
      rescue => error
        Rails.error.report(error, handled: false, context: { card_id: 3 })
      end
    end

    line = JSON.parse(@io.string.lines.last)
    assert_equal [ "error", "error.reported", 3 ], line.values_at("level", "event", "card_id")
    assert_equal({ "id" => "req-9", "class" => "ArgumentError", "message" => "bad a***@example.com", "handled" => false },
      line["error"].slice("id", "class", "message", "handled"))
    assert_equal "IOError", line.dig("error", "cause", "class")
  end

  test "text mode writes a readable line" do
    StructuredLog.warn("board.delivery.failed", status: 502)

    assert_equal "WARN  board.delivery.failed status=502\n", @io.string.lines.last
  end

  test "the actor names the account, user, session kind and agent" do
    session = users(:david).sessions.create!(kind: :token, label: "claude")
    Current.session = session

    with_json do
      StructuredLog.set_actor(session)
      StructuredLog.warn("auth.token.refused")
    end

    line = JSON.parse(@io.string.lines.last)
    assert_equal [ session.user.account_id, session.user_id, "token", session.label ],
      line.values_at("account_id", "user_id", "session_kind", "agent_name")
  end

  test "a discarded job is reported with its context" do
    job_class = Class.new(ApplicationJob) do
      def self.name = "ExplodingJob"
      discard_on(ArgumentError)
      def perform = raise(ArgumentError, "boom")
    end

    assert_error_reported(ArgumentError) { job_class.perform_now }
  end

  private
    def with_json
      ENV["RAILS_LOG_FORMAT"] = "json"
      yield
    ensure
      ENV.delete("RAILS_LOG_FORMAT")
    end
end
