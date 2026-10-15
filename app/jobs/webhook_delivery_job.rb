class WebhookDeliveryJob < ApplicationJob
  queue_as :backend

  discard_on ActiveJob::DeserializationError

  def perform(delivery)
    delivery.deliver_now
  end
end
