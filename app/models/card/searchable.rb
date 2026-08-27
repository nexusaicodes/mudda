module Card::Searchable
  extend ActiveSupport::Concern

  included do
    include ::Searchable

    scope :mentioning, ->(query, user:) do
      joins(Search::Record.card_join).merge(Search::Record.for_query(query, user: user))
    end
  end

  def search_title
    title
  end

  def search_content
    description.to_plain_text
  end

  def search_card_id
    id
  end

  def search_board_id
    board_id
  end

  def searchable?
    published?
  end
end
