# When the server boots: apply the plan the host handed over in MUDDA_PLAN (the platform's last
# signed plan message, ordered by its sequence number like any other), and send whatever events
# for the platform were still waiting, since the in-process job queue didn't survive the
# restart. A bad plan is logged, never fatal: the board keeps the plan it had.
Rails.application.config.after_initialize do
  if defined?(Rails::Server)
    Rails.application.executor.wrap do
      if (plan = ENV["MUDDA_PLAN"].presence) && Platform::Message.enabled? && (account = Account.first)
        message = Platform::Message.verify(plan, host: Platform::Message.audience, fresh: false)
        message.apply(account) if message.kind == "plan.updated"
      end

      WebhookDelivery.deliver_due_later
    rescue Platform::Message::Invalid, ActiveRecord::ActiveRecordError => error
      Rails.logger.error "Platform sync at boot: #{error.class}: #{error.message}"
    end
  end
end
