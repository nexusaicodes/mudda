require "test_helper"
require "open3"

# Tracing is off in tests; this boots the app with it on, in a child process, so a broken
# initializer or a bind value leaking onto a SQL span fails here.
class OpentelemetryBootTest < ActiveSupport::TestCase
  test "with OTEL_TRACES_EXPORTER set, SQL spans carry obfuscated statements and logs carry trace ids" do
    script = <<~RUBY
      OpenTelemetry.tracer_provider.tracer("test").in_span("probe") do
        User.where(email_address: "secret@example.com").count
        puts StructuredLog.trace_fields.to_json
      end
      OpenTelemetry.tracer_provider.shutdown
    RUBY
    output, status = Open3.capture2e({ "OTEL_TRACES_EXPORTER" => "console", "RAILS_ENV" => "test" }, "bin/rails", "runner", script, chdir: Rails.root.to_s)

    assert status.success?, output
    assert_match(/"trace_id":"\h{32}"/, output)
    assert_match(/db\.query\.text"\s*=>\s*"SELECT COUNT\(\*\) FROM/, output)
    assert_no_match(/secret@example\.com/, output)
  end
end
