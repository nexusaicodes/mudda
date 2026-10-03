module Card::Eventable
  extend ActiveSupport::Concern

  include ::Eventable

  # The changes a card's audit trail records, one event each.
  TRACKED_ATTRIBUTES = %w[ title column_id board_id ]

  included do
    before_create { self.last_active_at ||= created_at || Time.current }
    before_update :capture_tracked_changes

    after_create -> { track_event :created }
    after_update :track_title_change, if: -> { tracked_change?("title") }
  end

  # Activity that happens to a card from outside it — a note being added. A card's own changes
  # carry their activity time in the same UPDATE (see capture_tracked_changes).
  def touch_last_active_at
    update!(last_active_at: Time.current)
  end

  private
    # Snapshotted before the UPDATE, because the events are recorded after it: by then any
    # nested write to the card — a touch from a step saved with it, say — would have replaced
    # saved_changes, and a request that changed two things would record only one of them.
    def capture_tracked_changes
      @tracked_changes = changes_to_save.slice(*TRACKED_ATTRIBUTES)

      if @tracked_changes.any? && !last_active_at_changed?
        self.last_active_at = Time.current
      end
    end

    def tracked_change?(attribute)
      @tracked_changes&.key?(attribute)
    end

    def tracked_change_was(attribute)
      @tracked_changes.dig(attribute, 0)
    end

    def track_title_change
      if old_title = tracked_change_was("title").presence
        track_event "title_changed", particulars: { old_title: old_title, new_title: title }
        events.touch_all
      end
    end
end
