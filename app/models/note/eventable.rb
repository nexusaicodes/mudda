module Note::Eventable
  extend ActiveSupport::Concern

  include ::Eventable

  # The note has already committed, so a failure to record its event is reported and repaired
  # later (see AfterCommitSideEffects) rather than failing the request that wrote it. The
  # agent is passed along, as a repair runs without the request's session.
  included do
    after_create_commit -> { after_commit_side_effect(:track_creation, Current.agent_name) }
  end

  def event_was_created(event)
    card.touch_last_active_at
  end

  # Records the note's created event once: a repair finds the event already there if an earlier
  # attempt recorded it.
  def track_creation(agent_name)
    track_event("created", creator: creator, agent_name: agent_name) unless events.exists?(action: "note_created")
  end
end
