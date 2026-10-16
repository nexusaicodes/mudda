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
    # The note has already committed, so a failure to record its audit event is reported rather
    # than failing the request that wrote it.
    def track_creation
      track_event("created", creator: creator)
    rescue StandardError => error
      Rails.error.report error, handled: true, severity: :error, source: "mudda.event",
        context: { eventable_type: self.class.name, eventable_id: id }
    end
end
