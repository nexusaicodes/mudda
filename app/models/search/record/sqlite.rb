module Search::Record::SQLite
  extend ActiveSupport::Concern

  included do
    has_one :search_records_fts, -> { with_rowid },
      class_name: "Search::Record::SQLite::Fts", foreign_key: :rowid, primary_key: :id, dependent: :destroy

    after_save :upsert_to_fts5_table

    scope :matching, ->(query) {
      joins("INNER JOIN search_records_fts ON search_records_fts.rowid = #{table_name}.id")
        .where("search_records_fts MATCH ?", query)
    }
  end

  class_methods do
    def search_fields(query)
      [ "#{connection.quote(query.terms)} AS query" ]
    end
  end

  # The FTS table holds the normalized text that queries match against; the record keeps the
  # text as written, which is what gets highlighted.
  def card_title
    highlighter.highlight(title.presence || card.title)
  end

  def card_description
    highlighter.snippet(content) if content.present? && !note
  end

  def note_body
    highlighter.snippet(content) if content.present? && note
  end

  private
    def highlighter
      @highlighter ||= Search::Highlighter.new(self[:query])
    end

    def upsert_to_fts5_table
      Fts.upsert(id, Search::Normalizer.normalize(title), Search::Normalizer.normalize(content))
    end
end
