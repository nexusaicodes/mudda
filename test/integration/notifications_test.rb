require "test_helper"

class NotificationDeliveryTest < ActiveSupport::TestCase
  setup do
    @assigner = users(:david)
    @assignee = users(:kevin)
    @card = cards(:logo)

    @card.assignments.destroy_all
    @assignee.notifications.destroy_all

    Current.user = @assigner
  end

  test "card assignment creates a notification" do
    assert_difference -> { Notification.count }, 1 do
      perform_enqueued_jobs only: NotifyRecipientsJob do
        @card.toggle_assignment(@assignee)
      end
    end

    notification = Notification.last
    assert_equal @assignee, notification.user
    assert_equal @assigner, notification.creator
    assert_equal "card_assigned", notification.source.action
  end

  test "card assignment notification is bundled for email delivery when bundling enabled" do
    @assignee.settings.update!(bundle_email_frequency: :every_few_hours)

    assert_difference -> { Notification.count }, 1 do
      perform_enqueued_jobs only: NotifyRecipientsJob do
        @card.toggle_assignment(@assignee)
      end
    end

    notification = @assignee.notifications.reload.last
    assert_not_nil notification, "Notification should be created for assignee"

    bundle = @assignee.notification_bundles.pending.last
    assert_not_nil bundle, "Bundle should be created when bundling is enabled"
    assert_includes bundle.notifications, notification
  end

  test "comment creates a notification for card watchers" do
    @card.watch_by(@assignee)

    assert_difference -> { Notification.count }, 1 do
      perform_enqueued_jobs only: NotifyRecipientsJob do
        @card.comments.create!(body: "Great work on this!", creator: @assigner)
      end
    end

    notification = Notification.last
    assert_equal @assignee, notification.user
    assert_equal "comment_created", notification.source.action
  end

  test "mention creates a notification" do
    mention_html = ActionText::Attachment.from_attachable(@assignee).to_html

    perform_enqueued_jobs only: [ Mention::CreateJob, NotifyRecipientsJob ] do
      @card.comments.create!(
        body: "#{mention_html} check this out",
        creator: @assigner
      )
    end

    mention_notification = @assignee.notifications.find_by(source_type: "Mention")
    assert_not_nil mention_notification
  end

  test "system user actions do not create notifications" do
    Current.user = users(:system)

    assert_no_difference -> { Notification.count } do
      perform_enqueued_jobs only: NotifyRecipientsJob do
        @card.toggle_assignment(@assignee)
      end
    end
  end

  test "notifications are created for inactive users" do
    @assignee.deactivate

    assert_difference -> { Notification.count }, 1 do
      perform_enqueued_jobs only: NotifyRecipientsJob do
        @card.toggle_assignment(@assignee)
      end
    end
  end
end
