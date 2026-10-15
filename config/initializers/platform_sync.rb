# Events for the hosting platform still waiting when the server stopped are sent again at boot,
# since the in-process job queue didn't survive the restart.
Rails.application.config.after_initialize do
  if defined?(Rails::Server)
    Rails.application.executor.wrap do
      WebhookDelivery.deliver_due_later
    rescue ActiveRecord::ActiveRecordError => error
      Rails.logger.error "Platform sync at boot: #{error.class}: #{error.message}"
    end
  end
end
