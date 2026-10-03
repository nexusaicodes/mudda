module Note::Eventable
  extend ActiveSupport::Concern

  include ::Eventable

  included do
    after_create_commit :track_creation
  end

  def event_was_created(event)
    card.touch_last_active_at
  end

  private
    def track_creation
      track_event("created", creator: creator)
    end
end
