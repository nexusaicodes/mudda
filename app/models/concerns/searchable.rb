module Searchable
  extend ActiveSupport::Concern

  SEARCH_CONTENT_LIMIT = 32.kilobytes

  # The index follows a write that has already committed, so a failure to index it is reported
  # and repaired later (see AfterCommitSideEffects) rather than failing the request. Both side
  # effects are idempotent: reindex upserts, and removal finds nothing the second time.
  included do
    after_save_commit    { after_commit_side_effect(:reindex) }
    after_destroy_commit { after_commit_side_effect(:remove_from_search_index, id, on: self.class) }
  end

  class_methods do
    def remove_from_search_index(id)
      Search::Record.find_by(searchable_type: name, searchable_id: id)&.destroy
    end
  end

  def reindex
    search_record_class.upsert!(search_record_attributes)
  end

  private

    def search_record_attributes
      {
        searchable_type: self.class.name,
        searchable_id: id,
        card_id: search_card_id,
        title: search_title,
        content: search_record_content,
        created_at: created_at
      }
    end

    def search_record_content
      search_content&.truncate_bytes(SEARCH_CONTENT_LIMIT, omission: "")
    end

    def search_record_class
      Search::Record
    end

  # Models must implement these methods:
  # - search_title: returns title string or nil
  # - search_content: returns content string
  # - search_card_id: returns the card id (self.id for cards, card_id for notes)
end
