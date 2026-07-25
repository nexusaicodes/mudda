module User::Accessor
  extend ActiveSupport::Concern

  def boards
    account.boards
  end

  def accessible_cards
    account.cards
  end

  def draft_new_card_in(board)
    board.cards.find_or_initialize_by(creator: self, status: "drafted").tap do |card|
      card.update!(created_at: Time.current, updated_at: Time.current, last_active_at: Time.current)
    end
  end
end
