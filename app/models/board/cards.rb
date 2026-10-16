module Board::Cards
  extend ActiveSupport::Concern

  included do
    has_many :cards, dependent: :destroy

    after_update_commit -> { after_commit_side_effect(:touch_cards) }, if: :saved_change_to_name?
  end

  def touch_cards
    cards.touch_all
  end
end
