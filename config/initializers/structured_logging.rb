require Rails.root.join("lib/structured_log").to_s

# See lib/structured_log.rb for the log line contract and lib/job_context.rb for jobs.
Rails.application.configure do
  # The formatter is a tagged one, so logger.tagged keeps working, and a tag becomes a field of
  # the line (see StructuredLog::Formatter). The request id travels in Rails.event's context.
  formatter = -> { StructuredLog::Formatter.new }
  config.log_formatter = formatter.call
  loggers = Rails.logger.respond_to?(:broadcasts) ? Rails.logger.broadcasts : [ Rails.logger ]
  loggers.each { |logger| logger.formatter = formatter.call }

  # Each failure is logged once, by StructuredLog::ErrorSubscriber.
  config.action_dispatch.debug_exception_log_level = :debug
  config.action_dispatch.log_rescued_responses = false

  config.middleware.insert_after ActionDispatch::RequestId, StructuredLog::RequestContext

  # Debug-level framework events, such as each SQL query, are only emitted when debug lines
  # would be written.
  config.after_initialize do
    Rails.event.debug_mode = Rails.logger.level <= Logger::DEBUG
  end
end

Rails.event.subscribe(StructuredLog::Subscriber.new)
Rails.error.subscribe(StructuredLog::ErrorSubscriber.new)

# In json mode the framework's structured events replace its text log subscribers.
if StructuredLog.json?
  ActiveSupport.on_load(:after_initialize) do
    subscribers = %w[ action_controller action_dispatch action_view active_record active_job active_storage ].map do |framework|
      require "#{framework}/log_subscriber"
      "#{framework.camelize}::LogSubscriber".constantize
    end
    subscribers.each { Rails.event.unsubscribe(_1) }
  end
end

ActiveSupport.on_load(:active_job) do
  require Rails.root.join("lib/job_context").to_s
  include JobContext
  self.log_arguments = false
end
