require "test_helper"

class MetricsControllerTest < ActionDispatch::IntegrationTest
  TOKEN = "scrape-secret"

  test "is not found while MUDDA_METRICS_TOKEN is unset or blank" do
    [ nil, " " ].each do |value|
      with_env("MUDDA_METRICS_TOKEN" => value) do
        get "/metrics", headers: { "Authorization" => "Bearer #{TOKEN}" }
        assert_response :not_found
      end
    end
  end

  test "refuses a wrong or missing token with a warn event that leaves the token out" do
    with_env("MUDDA_METRICS_TOKEN" => TOKEN) do
      events = capture_warnings do
        get "/metrics", headers: { "Authorization" => "Bearer wrong-token" }
        assert_response :unauthorized
        get "/metrics"
        assert_response :unauthorized
      end

      assert_equal %w[ metrics.scrape.refused metrics.scrape.refused ], events.map(&:first)
      assert_equal %w[ invalid_token missing_token ], events.map { _2[:reason] }
      assert_no_match(/wrong-token|#{TOKEN}/, events.inspect)
    end
  end

  test "serves the exposition to the right token without a session" do
    row = { kind: "card.updated", payload: "{}", next_attempt_at: nil, delivered_at: nil, updated_at: Time.current }
    WebhookDelivery.insert_all [
      row.merge(event_id: "a", next_attempt_at: 1.minute.ago, created_at: 2.minutes.ago),
      row.merge(event_id: "b", next_attempt_at: 1.hour.from_now, created_at: 1.minute.ago),
      row.merge(event_id: "c", created_at: 1.day.ago),
      row.merge(event_id: "d", delivered_at: Time.current, created_at: 1.day.ago)
    ]

    with_env("MUDDA_METRICS_TOKEN" => TOKEN, "GIT_SHA" => "abc123") do
      get "/metrics", headers: { "Authorization" => "Bearer #{TOKEN}" }
    end

    assert_response :success
    assert_equal "text/plain; version=0.0.4; charset=utf-8", response.headers["Content-Type"]
    body = response.body

    assert_includes body, "# TYPE mudda_board_cards gauge\n"
    assert_includes body, "# HELP mudda_board_accounts "
    assert_includes body, "mudda_board_accounts #{Account.count}\n"
    assert_includes body, "mudda_board_users #{User.count}\n"
    assert_includes body, "mudda_board_boards #{Board.count}\n"
    assert_includes body, "mudda_board_notes #{Note.count}\n"
    Card.joins(:column).group("columns.name").count.each do |name, count|
      assert_includes body, %(mudda_board_cards{column="#{name}"} #{count}\n)
    end
    { pending: 1, scheduled: 1, abandoned: 1, delivered: 1 }.each do |state, count|
      assert_includes body, %(mudda_board_webhook_deliveries{state="#{state}"} #{count}\n)
    end
    age = body[/^mudda_board_webhook_delivery_oldest_pending_age_seconds (\S+)$/, 1].to_f
    assert_in_delta 120, age, 5
    assert_match(/^mudda_board_database_size_bytes [1-9]\d*$/, body)
    assert_match(/^mudda_board_wal_size_bytes \d+$/, body)
    assert_includes body, %(mudda_board_build_info{version="abc123"} 1\n)
  end

  private
    def with_env(values)
      previous = values.keys.to_h { [ _1, ENV[_1] ] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      previous.each { |key, value| ENV[key] = value }
    end

    def capture_warnings
      events = []
      original = StructuredLog.method(:warn)
      StructuredLog.define_singleton_method(:warn) { |event, **fields| events << [ event, fields ] }
      yield
      events
    ensure
      StructuredLog.singleton_class.send(:remove_method, :warn)
      StructuredLog.define_singleton_method(:warn, original) unless StructuredLog.respond_to?(:warn)
    end
end
