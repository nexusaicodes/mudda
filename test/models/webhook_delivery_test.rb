require "test_helper"

class WebhookDeliveryTest < ActiveSupport::TestCase
  test "nothing is recorded until the platform configures webhooks" do
    trusting_the_platform do
      assert_no_difference -> { WebhookDelivery.count } do
        users(:kevin).update!(name: "Kevin Renamed")
      end
    end
  end

  test "a rename is recorded with its time and sent after commit" do
    with_platform_webhooks do
      assert_enqueued_with(job: WebhookDeliveryJob) do
        users(:kevin).update!(name: "Kevin Renamed")
      end
    end

    delivery = WebhookDelivery.last
    assert_equal "user.updated", delivery.kind
    assert_equal "Kevin Renamed", delivery.payload["name"]
    assert_equal users(:kevin).reload.name_changed_at.iso8601(6), delivery.payload["name_changed_at"]
  end

  test "a rename that fails to save records nothing" do
    with_platform_webhooks do
      assert_no_difference -> { WebhookDelivery.count } do
        assert_not users(:kevin).update(name: "")
      end
    end
  end

  test "delivers signed, and marks it delivered" do
    with_platform_webhooks do
      delivery = WebhookDelivery.record("user.updated", name: "K")
      http = mock
      http.expects(:post).with do |path, body, headers|
        timestamp, signature = headers["Mudda-Signature"].scan(/t=(\d+),v1=(\h+)/).first

        path == "/webhooks/boards/7" && headers["Mudda-Event-Id"] == delivery.event_id &&
          signature == OpenSSL::HMAC.hexdigest("SHA256", "s" * 64, "#{timestamp}.#{body}")
      end.returns(Net::HTTPOK.new("1.1", "200", "OK"))
      Net::HTTP.stubs(:start).yields(http).returns(Net::HTTPOK.new("1.1", "200", "OK"))

      delivery.deliver_now

      assert delivery.reload.delivered_at
      assert_nil delivery.next_attempt_at
    end
  end

  test "a failure backs off, keeps the same event id, and gives up after a week" do
    with_platform_webhooks do
      delivery = WebhookDelivery.record("user.updated", name: "K")
      Net::HTTP.stubs(:start).raises(Errno::ECONNREFUSED)

      freeze_time do
        assert_enqueued_with(job: WebhookDeliveryJob, at: 1.minute.from_now) { delivery.deliver_now }
        assert_equal [ 1, 1.minute.from_now ], [ delivery.attempts, delivery.next_attempt_at ]
        assert_match "ECONNREFUSED", delivery.last_error
      end

      delivery.update_columns created_at: 8.days.ago, attempts: 9
      delivery.deliver_now
      assert_nil delivery.reload.next_attempt_at
      assert_nil delivery.delivered_at
    end
  end

  test "a failed attempt is logged at warn, and the one given up on at error and reported" do
    with_platform_webhooks do
      delivery = WebhookDelivery.record("user.updated", name: "K")
      Net::HTTP.stubs(:start).returns(Net::HTTPBadGateway.new("1.1", "502", "Bad Gateway"))

      assert_event_reported("board.delivery.failed", payload: { event_id: delivery.event_id, status: 502, attempts: 1 }) do
        delivery.deliver_now
      end

      delivery.update_columns created_at: 8.days.ago, attempts: 9
      assert_event_reported("board.delivery.abandoned", payload: { event_id: delivery.event_id, attempts: 10 }) do
        assert_error_reported(WebhookDelivery::Abandoned) { delivery.deliver_now }
      end
    end
  end

  test "a delivery is sent by one job only" do
    with_platform_webhooks do
      delivery = WebhookDelivery.record("user.updated", name: "K")
      stale = WebhookDelivery.find(delivery.id)
      Net::HTTP.expects(:start).once.returns(Net::HTTPBadGateway.new("1.1", "502", "Bad Gateway"))

      delivery.deliver_now
      stale.deliver_now

      assert_equal 1, delivery.reload.attempts
    end
  end

  test "a bug after the platform accepted is raised, not retried as a transport failure" do
    with_platform_webhooks do
      delivery = WebhookDelivery.record("user.updated", name: "K")
      Net::HTTP.stubs(:start).returns(Net::HTTPOK.new("1.1", "200", "OK"))
      delivery.stubs(:update!).raises(ActiveRecord::RecordInvalid)

      assert_raises(ActiveRecord::RecordInvalid) { delivery.deliver_now }
      assert_equal 0, delivery.reload.attempts
      assert_nil delivery.last_error
    end
  end

  test "every pending delivery is queued again at boot, each for when it is due" do
    with_platform_webhooks do
      due = WebhookDelivery.record("user.updated", name: "K")
      later = WebhookDelivery.record("user.updated", name: "L")
      later.update_columns next_attempt_at: 1.hour.from_now
      WebhookDelivery.record("user.updated", name: "M").update_columns delivered_at: Time.current, next_attempt_at: nil
      clear_enqueued_jobs

      WebhookDelivery.deliver_pending_later

      assert_enqueued_jobs 2, only: WebhookDeliveryJob
      assert_enqueued_with(job: WebhookDeliveryJob, args: [ due ])
      assert_enqueued_with(job: WebhookDeliveryJob, args: [ later ], at: later.next_attempt_at)
    end
  end

  test "what is due is sent again" do
    with_platform_webhooks do
      due = WebhookDelivery.record("user.updated", name: "K")
      later = WebhookDelivery.record("user.updated", name: "L")
      later.update_columns next_attempt_at: 1.hour.from_now
      clear_enqueued_jobs

      WebhookDelivery.deliver_due_later
      assert_enqueued_jobs 1, only: WebhookDeliveryJob
      assert_enqueued_with(job: WebhookDeliveryJob, args: [ due ])
    end
  end

  test "the card that takes the last slot reports the limit reached" do
    account = boards(:writebook).account
    account.update_columns cards_created_count: 99, plan: "free"
    Current.session = sessions(:david)

    with_platform_webhooks(account) do
      assert_difference -> { WebhookDelivery.where(kind: "cards.limit_reached").count }, 1 do
        boards(:writebook).cards.create!(title: "Last one", creator: users(:david))
      end
    end
  end
end
