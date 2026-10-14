module Card::Notable
  extend ActiveSupport::Concern

  EMBEDDED_NOTES_LIMIT = 20

  included do
    has_many :notes, dependent: :destroy
  end

  # The tail of the note log, which is what a card is read for. A card can carry thousands of
  # notes, so its own representation embeds only the most recent ones; the notes index pages
  # through the rest.
  def latest_notes
    notes.chronologically.preloaded.includes(:creator).last(EMBEDDED_NOTES_LIMIT)
  end

  def notes_truncated?
    notes.size > EMBEDDED_NOTES_LIMIT
  end
end
