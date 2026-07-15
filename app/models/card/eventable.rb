module Card::Eventable
  extend ActiveSupport::Concern

  include ::Eventable

  included do
    before_create { self.last_active_at ||= created_at || Time.current }

    after_save :track_title_change, if: :saved_change_to_title?
  end

  def event_was_created(event)
    touch_last_active_at unless was_just_published?
  end

  def touch_last_active_at
    # Not using touch so that we can detect attribute change on callbacks
    update!(last_active_at: Time.current)
  end

  private
    def should_track_event?
      published?
    end

    def track_title_change
      if title_before_last_save.present?
        track_event "title_changed", particulars: { old_title: title_before_last_save, new_title: title }
        events.touch_all
      end
    end
end
