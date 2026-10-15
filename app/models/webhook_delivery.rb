# An event for the hosting platform, kept until it is delivered. It is written in the same
# transaction as the change it reports, so neither exists without the other, and sent after
# commit. Delivery is a POST to the account's webhook_url with the JSON body signed by its
# webhook_secret:
#
#   Mudda-Signature: t=<unix time>,v1=<hex HMAC-SHA256 of "<t>.<body>">
#   Mudda-Event-Id:  <uuid, the same on every retry>
#
# Both come only from the platform, in a signed sync.configured message (see
# Platform::Message), never from the user. Until then, and always when self-hosting, nothing is
# recorded.
class WebhookDelivery < ApplicationRecord
  RETRY_DELAYS = [ 1.minute, 5.minutes, 30.minutes, 2.hours, 6.hours ]
  GIVE_UP_AFTER = 7.days
  TIMEOUT = 5.seconds

  serialize :payload, coder: JSON

  scope :pending, -> { where(delivered_at: nil).where.not(next_attempt_at: nil) }
  scope :due, ->(now = Time.current) { pending.where(next_attempt_at: ..now) }

  after_create_commit :deliver_later

  class << self
    def enabled?
      endpoint.present?
    end

    # The URL and secret to sign with, or nil when the platform hasn't configured them.
    def endpoint
      if Platform::Message.enabled? && (account = Account.first)
        account.values_at(:webhook_url, :webhook_secret).then { |url, secret| [ url, secret ] if url.present? && secret.present? }
      end
    end

    def record(kind, **payload)
      create!(kind: kind, payload: payload, event_id: SecureRandom.uuid, next_attempt_at: Time.current) if enabled?
    end

    # The in-process queue doesn't outlive a restart, so whatever is due is picked up again here,
    # at boot and on the platform's request.
    def deliver_due_later
      due.find_each(&:deliver_later)
    end
  end

  def deliver_later(wait_until: nil)
    WebhookDeliveryJob.set(wait_until: wait_until).perform_later(self)
  end

  def deliver_now
    if delivered_at.nil? && self.class.enabled?
      response = post(*self.class.endpoint)
      response.is_a?(Net::HTTPSuccess) ? delivered : failed("HTTP #{response.code}")
    end
  rescue StandardError => error
    failed "#{error.class}: #{error.message}".truncate(255)
  end

  private
    def post(url, secret)
      uri = URI(url)
      body = { event: kind, id: event_id, data: payload }.to_json
      timestamp = Time.current.to_i

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.post uri.request_uri, body,
          "Content-Type" => "application/json",
          "Mudda-Event-Id" => event_id,
          "Mudda-Signature" => "t=#{timestamp},v1=#{OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{body}")}"
      end
    end

    def delivered
      update!(delivered_at: Time.current, next_attempt_at: nil, last_error: nil)
    end

    # Retries back off, then stop a week after the event, leaving the row as the record of what
    # was never delivered; the platform's reconcile catches the state up regardless.
    def failed(error)
      retry_at = Time.current + RETRY_DELAYS.fetch(attempts, RETRY_DELAYS.last)
      retry_at = nil if retry_at > created_at + GIVE_UP_AFTER

      update!(attempts: attempts + 1, last_error: error, next_attempt_at: retry_at)
      retry_at ? deliver_later(wait_until: retry_at) : Rails.logger.error("WebhookDelivery #{event_id} abandoned: #{error}")
    end
end
