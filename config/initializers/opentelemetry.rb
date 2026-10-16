# Tracing with OpenTelemetry, exported over OTLP (http/protobuf, port 4318) to a collector.
# Inert unless OTEL_EXPORTER_OTLP_ENDPOINT or OTEL_TRACES_EXPORTER is set, so a board that
# doesn't ask for tracing loads none of it (OTEL_TRACES_EXPORTER=console prints spans; tests
# use an in-memory exporter). The usual OTEL_* variables configure the rest; OTEL_PROPAGATORS
# defaults to tracecontext only, so no baggage leaves the board.
return unless ENV["OTEL_EXPORTER_OTLP_ENDPOINT"].present? || ENV["OTEL_TRACES_EXPORTER"].present?

ENV["OTEL_PROPAGATORS"] ||= "tracecontext"

require Rails.root.join("lib/structured_log").to_s
require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/rails"
require "opentelemetry/instrumentation/net/http"
require "opentelemetry/helpers/sql_processor"
require "opentelemetry/instrumentation/active_support/span_subscriber"

# A query string can carry an OAuth code or a token, so every span's URL attributes keep a
# query only with its filter_parameters values replaced (see StructuredLog.filter_query).
# Rack and Net::HTTP set these when they start a span, so on_start sees them.
class FilteredQuerySpans < OpenTelemetry::SDK::Trace::SpanProcessor
  QUERY = "url.query"
  WITH_QUERY = %w[ http.target http.url url.full ].freeze

  def on_start(span, _parent_context)
    attributes = span.attributes || {}
    span.set_attribute(QUERY, StructuredLog.filter_query(attributes[QUERY])) if attributes[QUERY]
    WITH_QUERY.each do |key|
      value = attributes[key]
      next unless value.is_a?(String) && value.include?("?")

      base, query = value.split("?", 2)
      span.set_attribute(key, "#{base}?#{StructuredLog.filter_query(query)}")
    end
  end
end

OpenTelemetry::SDK.configure do |c|
  c.service_name = StructuredLog::SERVICE
  c.service_version = ENV["GIT_SHA"] if ENV["GIT_SHA"]
  c.resource = OpenTelemetry::SDK::Resources::Resource.create("deployment.environment.name" => StructuredLog.base_fields[:env].to_s)

  # Every instrumentation required above: Rails (Rack, Action Pack/View/Mailer, Active
  # Job/Storage/Support) and Net::HTTP. Active Record's ORM patches stay off: they aren't
  # tested against edge Rails, and SQL spans come from the subscriber below.
  c.use_all(
    "OpenTelemetry::Instrumentation::Rack" => { untraced_endpoints: [ "/up" ] },
    "OpenTelemetry::Instrumentation::ActiveJob" => { propagation_style: :child },
    "OpenTelemetry::Instrumentation::ActiveRecord" => { enabled: false }
  )
end

# Added after configure, so the exporters chosen by OTEL_* variables stay in place.
OpenTelemetry.tracer_provider.add_span_processor FilteredQuerySpans.new

# SQLite has no driver instrumentation, so SQL spans come from Active Record's own
# notifications. The transform replaces the whole payload, so bind values never reach a span.
module SqlSpans
  def self.attributes(payload)
    sql = payload[:sql].to_s
    {
      "db.system.name" => "sqlite",
      "db.operation.name" => sql[/\A\s*(\w+)/, 1]&.upcase,
      "db.query.text" => OpenTelemetry::Helpers::SqlProcessor.obfuscate_sql(sql, adapter: :sqlite)
    }.compact
  end
end

OpenTelemetry::Instrumentation::ActiveSupport.subscribe(
  OpenTelemetry.tracer_provider.tracer("mudda-board.sql"),
  /\Asql\.active_record\z/,
  SqlSpans.method(:attributes),
  kind: :client,
  span_name_formatter: ->(_name) { "sqlite" }
)
