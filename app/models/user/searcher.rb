module User::Searcher
  extend ActiveSupport::Concern

  included do
    has_many :search_queries, class_name: "Search::Query", dependent: :destroy
  end

  def search(terms)
    Search::Record.search(terms, user: self)
  end

  # How many cards match, board by board.
  def search_counts_by_board(terms)
    Search::Record.for_query(terms, user: self).joins(:card).group("cards.board_id").distinct.count(:card_id)
  end

  # The most recently matched cards on a board, each with its matches: the card itself, if it
  # matched, and its latest matching note.
  def search_board(terms, board, limit:)
    matches = Search::Record.for_query(terms, user: self).joins(:card).where(cards: { board_id: board.id })
    card_ids = matches.group(:card_id).order(Arel.sql("MAX(search_records.created_at) DESC")).limit(limit).pluck(:card_id)
    latest = matches.where(card_id: card_ids).group(:card_id, :searchable_type).select("MAX(search_records.id)")

    search(terms).includes(card: :column).where(id: latest).group_by(&:card).sort_by { |card, _| card_ids.index(card.id) }
  end

  def remember_search(terms)
    search_queries.find_or_create_by(terms: terms).tap do |search_query|
      search_query.touch unless search_query.invalid? || search_query.previously_new_record?
    end
  end
end
