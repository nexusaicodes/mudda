module Card::Eventable
  extend ActiveSupport::Concern

  include ::Eventable

  included do
    before_create { self.last_active_at ||= created_at || Time.current }

    after_create -> { track_event :created }
    after_save :track_title_change, if: :saved_change_to_title?
  end

  # A card's own creation event is not activity on it — before_create has already set
  # last_active_at, and a backdated card must keep the time it was given.
  def event_was_created(event)
    touch_last_active_at unless previously_new_record?
  end

  def touch_last_active_at
    # Not using touch so that we can detect attribute change on callbacks
    update!(last_active_at: Time.current)
  end

  private
    def track_title_change
      if title_before_last_save.present?
        track_event "title_changed", particulars: { old_title: title_before_last_save, new_title: title }
        events.touch_all
      end
    end
end
