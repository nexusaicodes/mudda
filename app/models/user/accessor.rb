module User::Accessor
  extend ActiveSupport::Concern

  def boards
    account.boards
  end

  def accessible_cards
    account.cards
  end
end
