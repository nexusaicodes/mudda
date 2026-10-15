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
