module Searchable
  extend ActiveSupport::Concern

  SEARCH_CONTENT_LIMIT = 32.kilobytes

  # The write the index follows has already committed, so a failure to index it is reported
  # rather than failing the request; bin/rails search:reindex repairs the index.
  included do
    after_create_commit  { reporting_index_failure { create_in_search_index } }
    after_update_commit  { reporting_index_failure { update_in_search_index } }
    after_destroy_commit { reporting_index_failure { remove_from_search_index } }
  end

  def reindex
    update_in_search_index
  end

  private
    def reporting_index_failure
      yield
    rescue StandardError => error
      Rails.error.report error, handled: true, severity: :error, source: "mudda.search_index",
        context: { searchable_type: self.class.name, searchable_id: id }
    end

    def create_in_search_index
      search_record_class.create!(search_record_attributes)
    end

    def update_in_search_index
      search_record_class.upsert!(search_record_attributes)
    end

    def remove_from_search_index
      search_record_class.find_by(searchable_type: self.class.name, searchable_id: id)&.destroy
    end

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
