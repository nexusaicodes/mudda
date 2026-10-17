require "net/http"

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
  # How long a claimed delivery is held by the job sending it. Past it, a delivery whose sender
  # died mid-send is pending again and is picked up at the next boot.
  CLAIM_LEASE = 1.minute
  # A job scheduled for a delivery's next attempt may start a moment before it, by the clock
  # it is checked against, so a delivery due this soon can be claimed. It is far shorter than
  # the lease and every retry delay, so neither a claimed delivery nor one backing off is due.
  CLAIM_LEEWAY = 5.seconds

  # What a POST can fail with on its way to the platform and back. Anything else is a bug, so it
  # is raised and reported rather than retried as if the platform were down.
  TRANSPORT_ERRORS = [
    Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError,
    Net::HTTPBadResponse, Net::ProtocolError
  ]

  # Raised into the error report when a delivery is given up on.
  class Abandoned < StandardError; end

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

    # Whatever is due is sent again on the platform's request.
    def deliver_due_later
      due.find_each(&:deliver_later)
    end

    # The in-process queue doesn't outlive a restart, so at boot every pending delivery is queued
    # again, each for when it was next due.
    def deliver_pending_later
      pending.find_each { it.deliver_later(wait_until: it.next_attempt_at.future? ? it.next_attempt_at : nil) }
    end
  end

  def deliver_later(wait_until: nil)
    WebhookDeliveryJob.set(wait_until: wait_until).perform_later(self)
  end

  # Sent only by the job that claims it, so two jobs queued for one delivery (at boot, after
  # commit, or on the platform's request) can't both POST it, and a job that runs while the
  # delivery is backing off can't send it early.
  #
  # While tracing is on, each attempt is a board.delivery.deliver span carrying the delivery's
  # id, kind, attempt number and outcome: delivered, retrying, abandoned or skipped.
  def deliver_now
    StructuredLog.in_span("board.delivery.deliver", { "mudda.delivery.id" => id, "mudda.delivery.kind" => kind, "mudda.delivery.attempt" => attempts + 1 }) do |span|
      attempt.tap { span&.set_attribute("mudda.delivery.outcome", it.to_s) }
    end
  end

  private
    def attempt
      if delivered_at.nil? && self.class.enabled? && claim
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = post(*self.class.endpoint)
        elapsed = elapsed_ms_since(started_at)
        response.is_a?(Net::HTTPSuccess) ? delivered : failed("HTTP #{response.code}", status: response.code.to_i, duration_ms: elapsed)
      else
        :skipped
      end
    rescue *TRANSPORT_ERRORS => error
      failed "#{error.class}: #{error.message}".truncate(255), duration_ms: elapsed_ms_since(started_at)
    end

    # Takes the delivery in one conditional UPDATE, only while it is due, and holds it for
    # CLAIM_LEASE. A job that reads the delivery after another has claimed it finds it leased,
    # and one that reads it after a failed attempt finds it waiting for its retry: not due.
    def claim
      now = Time.current
      leased_until = now + CLAIM_LEASE

      if self.class.due(now + CLAIM_LEEWAY).where(id: id).update_all(next_attempt_at: leased_until) == 1
        self.next_attempt_at = leased_until
        clear_attribute_change :next_attempt_at
        true
      else
        StructuredLog.debug("board.delivery.skipped", event_id: event_id, reason: "not due")
        false
      end
    end

    def elapsed_ms_since(started_at)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(1) if started_at
    end

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
      :delivered
    end

    # Retries back off, then stop a week after the event, leaving the row as the record of what
    # was never delivered; the platform's reconcile catches the state up regardless.
    def failed(error, **details)
      retry_at = Time.current + RETRY_DELAYS.fetch(attempts, RETRY_DELAYS.last)
      retry_at = nil if retry_at > created_at + GIVE_UP_AFTER

      update!(attempts: attempts + 1, last_error: error, next_attempt_at: retry_at)
      fields = { event_id: event_id, kind: kind, attempts: attempts, last_error: error, **details.compact }

      if retry_at
        StructuredLog.warn("board.delivery.failed", **fields, retry_at: retry_at.iso8601)
        deliver_later(wait_until: retry_at)
        :retrying
      else
        abandoned fields
        :abandoned
      end
    end

    def abandoned(fields)
      StructuredLog.error("board.delivery.abandoned", **fields)
      Rails.error.report Abandoned.new("Webhook delivery #{event_id} abandoned after #{attempts} attempts"),
        handled: true, severity: :error, source: "mudda.webhook_delivery", context: fields.except(:last_error)
    end
end
