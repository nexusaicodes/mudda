# One JSON object per log line (RAILS_LOG_FORMAT=json, the production default), or a
# readable "event key=value" line (text, the development default).
#
# Every line goes through Rails.logger, so RAILS_LOG_LEVEL decides what is written:
# debug everywhere locally, warn in production. Domain events are Rails.event
# notifications carrying a :level; the Subscriber turns them, and the framework's own
# structured events, into log lines. Facts that must outlive the log level belong in the
# database (an Event, a delivery's last_error), not here.
module StructuredLog
  SERVICE = "mudda-board"
  SEVERITIES = { debug: Logger::DEBUG, info: Logger::INFO, warn: Logger::WARN, error: Logger::ERROR }.freeze
  EMAIL = /\b([A-Za-z0-9._%+-])[A-Za-z0-9._%+-]*@([A-Za-z0-9.-]+\.[A-Za-z]{2,})\b/
  BACKTRACE_LINES = 20

  # The framework namespaces whose structured events replace Rails' text log subscribers
  # in json mode. In text mode those subscribers still write their usual lines.
  FRAMEWORK = %w[ action_controller. action_dispatch. action_mailer. action_view. active_job. active_record. active_storage. ].freeze

  class << self
    def json?
      format == "json"
    end

    def format
      ENV.fetch("RAILS_LOG_FORMAT") { Rails.env.production? ? "json" : "text" }
    end

    %i[ debug info warn error ].each do |level|
      define_method(level) { |event, **payload| Rails.event.notify(event, level: level, **payload) }
    end

    # Who is acting: tags every later event, log line and error report in the request with
    # account_id, user_id, session_kind and, for a token, agent_name, and the request's span,
    # when tracing is on, with all but the user id.
    def set_actor(session)
      actor = { account_id: Current.account&.id, user_id: session&.user_id,
        session_kind: session&.kind, agent_name: Current.agent_name }.compact

      Rails.event.set_context(**actor)
      request_span&.add_attributes(actor.except(:user_id).to_h { |key, value| [ "mudda.#{key}", value.is_a?(Integer) ? value : value.to_s ] })
    end

    def mask_email(text)
      text.to_s.gsub(EMAIL) { "#{$1}***@#{$2}" }
    end

    # A URL query string with each value the app's filter_parameters name (tokens, OAuth codes,
    # secrets) replaced by [FILTERED], for anywhere a query leaves the request, such as a span.
    def filter_query(query)
      return query if query.blank?

      Rack::Utils.build_query(query_filter.filter(Rack::Utils.parse_query(query))).gsub("%5BFILTERED%5D", "[FILTERED]")
    rescue ArgumentError
      "[FILTERED]"
    end

    # The error fields every log line and report share.
    def error_fields(error, id: nil, handled: nil, source: nil)
      {
        id: id,
        class: error.class.name,
        message: mask_email(error.message),
        backtrace: Rails.backtrace_cleaner.clean(error.backtrace.to_a).first(BACKTRACE_LINES),
        cause: error.cause && { class: error.cause.class.name, message: mask_email(error.cause.message) },
        handled: handled,
        source: source
      }.compact
    end

    # The current span's ids, so a log line links to its trace. Empty while tracing is off.
    def trace_fields
      return {} unless defined?(OpenTelemetry::Trace)

      context = OpenTelemetry::Trace.current_span.context
      context.valid? ? { trace_id: context.hex_trace_id, span_id: context.hex_span_id } : {}
    end

    # Runs the block in a span of its own, yielding the span, or nil while tracing is off.
    # Attributes are ids and outcomes, never what a user wrote.
    def in_span(name, attributes = {}, kind: :internal, &block)
      if defined?(OpenTelemetry::Trace)
        OpenTelemetry.tracer_provider.tracer(SERVICE).in_span(name, attributes: attributes.compact.transform_values { it.is_a?(Symbol) ? it.to_s : it }, kind: kind, &block)
      else
        yield nil
      end
    end

    # The server span of the request being served (for an MCP tool call, the span of the inner
    # API call), or nil while tracing is off.
    def request_span
      if defined?(OpenTelemetry::Instrumentation::Rack)
        OpenTelemetry::Instrumentation::Rack.current_span.then { it.recording? ? it : nil }
      end
    end

    def query_filter
      @query_filter ||= ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    end

    def base_fields
      @base_fields ||= { service: SERVICE, env: ENV.fetch("MUDDA_FLEET_ENV", Rails.env), version: ENV["GIT_SHA"] }.compact
    end
  end

  # Writes Rails.event notifications to Rails.logger at the level each one deserves.
  class Subscriber
    def emit(event)
      name = event[:name]
      return if !StructuredLog.json? && FRAMEWORK.any? { |prefix| name.start_with?(prefix) }

      payload = event[:payload].dup
      level = (payload.delete(:level) || level_for(name, payload)).to_sym
      severity = SEVERITIES.fetch(level, Logger::INFO)
      return unless Rails.logger.level <= severity

      Rails.logger.add(severity, {
        ts: Time.at(0, event[:timestamp], :nsec).utc,
        event: name,
        **event[:context],
        **event[:tags],
        **payload
      })
    end

    private
      def level_for(name, payload)
        case name
        when "action_controller.request_completed"
          status = payload[:status].to_i
          if status >= 500 then :error
          elsif [ 401, 403, 429 ].include?(status) then :warn
          else :info
          end
        when "active_job.retry_scheduled" then :warn
        when "active_job.discarded", "active_job.retry_stopped" then :error
        when "active_job.completed" then payload[:exception_class] ? :error : :info
        when /\Aactive_record\.|\Aaction_view\./, "action_controller.request_started" then :debug
        else :info
        end
      end
  end

  # Formats every Rails.logger line: a Hash from the Subscriber, or a plain string from
  # framework code or a stray Rails.logger call.
  class Formatter < ::Logger::Formatter
    LEVELS = { "DEBUG" => "debug", "INFO" => "info", "WARN" => "warn", "ERROR" => "error", "FATAL" => "error", "ANY" => "error", "UNKNOWN" => "error" }.freeze

    def call(severity, time, _progname, message)
      fields = message.is_a?(Hash) ? message.dup : { event: "log", msg: StructuredLog.mask_email(message.is_a?(Exception) ? message.message : message.to_s.strip) }
      line = { ts: fields.delete(:ts) || time.utc, level: LEVELS.fetch(severity, "info"), **StructuredLog.base_fields, **Rails.event.context, **StructuredLog.trace_fields, **fields }
      StructuredLog.json? ? json(line) : text(line)
    end

    private
      def json(line)
        line[:ts] = line[:ts].iso8601(3)
        "#{line.to_json}\n"
      end

      def text(line)
        line.except(:ts, :service, :env, :version) => { level:, event:, **rest }
        msg = rest.delete(:msg)
        pairs = rest.map { |key, value| "#{key}=#{value.is_a?(String) ? value : value.to_json}" }
        "#{level.upcase.ljust(5)} #{event == "log" ? msg : [ event, msg, *pairs ].compact.join(" ")}\n"
      end
  end

  # Reports from Rails.error become one error.reported line, carrying the reference id
  # shown to the user. Unhandled errors are logged at error, handled ones at warn.
  class ErrorSubscriber
    def report(error, handled:, severity:, context:, source:)
      return if source.to_s.end_with?(".active_support") && source.start_with?("deprecation")

      id = context[:request_id] || Rails.event.context[:request_id] || SecureRandom.uuid
      record_on_span(error, handled)
      StructuredLog.public_send(severity == :error || !handled ? :error : :warn, "error.reported",
        error: StructuredLog.error_fields(error, id: id, handled: handled, source: source),
        **context.except(:controller, :job, :request_id).transform_values { |value| loggable(value) })
    end

    private
      def record_on_span(error, handled)
        return unless defined?(OpenTelemetry::Trace)

        span = OpenTelemetry::Trace.current_span
        span.record_exception(error)
        span.status = OpenTelemetry::Trace::Status.error(error.class.name) unless handled
      end

      def loggable(value)
        case value
        when ActiveRecord::Base then value.to_gid.to_s
        when String then StructuredLog.mask_email(value)
        when Numeric, true, false, nil then value
        else StructuredLog.mask_email(value.to_s)
        end
      end
  end

  # Puts the request id in every event, log line and error report made while serving it.
  class RequestContext
    def initialize(app)
      @app = app
    end

    def call(env)
      request_id = env["action_dispatch.request_id"]
      Rails.event.set_context(request_id: request_id)
      ActiveSupport::ExecutionContext[:request_id] = request_id
      @app.call(env)
    end
  end
end
