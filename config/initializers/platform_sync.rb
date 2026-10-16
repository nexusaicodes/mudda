# Events for the hosting platform still waiting when the server stopped are queued again at boot,
# since the in-process job queue didn't survive the restart.
Rails.application.config.after_initialize do
  if defined?(Rails::Server)
    Rails.application.executor.wrap do
      WebhookDelivery.deliver_pending_later
    rescue ActiveRecord::ActiveRecordError => error
      Rails.error.report error, handled: true, severity: :error, source: "mudda.platform_sync"
    end
  end
end
