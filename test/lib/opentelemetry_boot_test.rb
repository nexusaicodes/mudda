require "test_helper"
require "open3"

# Tracing is off in tests; these boot the app in a child process: with it on, so a broken
# initializer or a bind value leaking onto a SQL span fails here, and with it off in
# production, so code leaning on a library only tracing happens to load fails too.
class OpentelemetryBootTest < ActiveSupport::TestCase
  test "with OTEL_TRACES_EXPORTER set, SQL spans carry obfuscated statements, URLs carry no secrets and logs carry trace ids" do
    script = <<~RUBY
      OpenTelemetry.tracer_provider.tracer("test").in_span("probe") do
        User.where(email_address: "secret@example.com").count
        puts StructuredLog.trace_fields.to_json
      end
      Rack::MockRequest.new(Rails.application).get("/oauth/authorize?code=one-time-code&access_token=leaky-token&state=xyz")
      OpenTelemetry.tracer_provider.shutdown
    RUBY
    output, status = Open3.capture2e({ "OTEL_TRACES_EXPORTER" => "console", "RAILS_ENV" => "test" }, "bin/rails", "runner", script, chdir: Rails.root.to_s)

    assert status.success?, output
    assert_match(/"trace_id":"\h{32}"/, output)
    assert_match(/db\.query\.text"\s*=>\s*"SELECT COUNT\(\*\) FROM/, output)
    assert_no_match(/secret@example\.com/, output)
    assert_match(/state=xyz/, output)
    assert_no_match(/one-time-code|leaky-token/, output)
  end

  # Production, because the test environment's own gems load libraries production lacks.
  test "with tracing off, production boots" do
    env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "OTEL_TRACES_EXPORTER" => nil, "OTEL_EXPORTER_OTLP_ENDPOINT" => nil }
    output, status = Open3.capture2e(env, "bin/rails", "runner", "puts :loaded", chdir: Rails.root.to_s)

    assert status.success?, output
    assert_match(/loaded/, output)
  end
end
