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

  private
    STORAGE_BATCH_SIZE = 1000

    # Override to include notes, but only load notes that have attachments.
    # Cards can have thousands of notes; most won't have attachments.
    def storage_transfer_records
      note_ids_with_attachments = storage_note_ids_with_attachments

      if note_ids_with_attachments.any?
        [ self, *notes.where(id: note_ids_with_attachments).to_a ]
      else
        [ self ]
      end
    end

    def storage_note_ids_with_attachments
      direct = []
      rich_text_map = {}

      # Scan notes in batches so attachment/rich-text lookups stay bounded per
      # query. rich_text_map keeps one entry per note's rich text to map embed
      # attachments back to their note.
      notes.in_batches(of: STORAGE_BATCH_SIZE) do |batch|
        batch_ids = batch.pluck(:id)

        direct.concat \
          ActiveStorage::Attachment
            .where(record_type: "Note", record_id: batch_ids)
            .distinct
            .pluck(:record_id)

        ActionText::RichText
          .where(record_type: "Note", record_id: batch_ids)
          .pluck(:id, :record_id)
          .each { |rt_id, note_id| rich_text_map[rt_id] = note_id }
      end

      embed_note_ids = if rich_text_map.any?
        rich_text_map.keys.each_slice(STORAGE_BATCH_SIZE).flat_map do |batch_ids|
          ActiveStorage::Attachment
            .where(record_type: "ActionText::RichText", record_id: batch_ids)
            .distinct
            .pluck(:record_id)
        end.filter_map { |rt_id| rich_text_map[rt_id] }
      else
        []
      end

      (direct + embed_note_ids).uniq
    end
end
