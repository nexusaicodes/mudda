module User::Searcher
  extend ActiveSupport::Concern

  def search(terms)
    Search::Record.search(terms, user: self)
  end

  # How many cards match, board by board.
  def search_counts_by_board(terms)
    Search::Record.for_query(terms, user: self).joins(:card).group("cards.board_id").distinct.count(:card_id)
  end

  # The most recently matched cards on each board, keyed by board id, each with its matches:
  # the card itself, if it matched, and its latest matching note.
  def search_boards(terms, limit:)
    matches = Search::Record.for_query(terms, user: self).joins(:card)
    ranked = matches.group(:card_id, "cards.board_id")
      .select(:card_id, "ROW_NUMBER() OVER (PARTITION BY cards.board_id ORDER BY MAX(search_records.created_at) DESC) AS position")
    positions = Search::Record.from(ranked, :search_records).where(position: ..limit).pluck(:card_id, :position).to_h
    latest = matches.where(card_id: positions.keys).group(:card_id, :searchable_type).select("MAX(search_records.id)")

    search(terms).includes(card: :column).where(id: latest).group_by(&:card)
      .sort_by { |card, _| positions[card.id] }.group_by { |card, _| card.board_id }
  end
end
