class Column < ApplicationRecord
  include Colored, Positioned

  belongs_to :board, touch: true
  has_many :cards, dependent: :destroy

  # Card lane predicates and Board#backlog_column key off the name, so it is set once, at creation.
  attr_readonly :name

  after_save_commit    -> { after_commit_side_effect(:touch_cards) }, if: :saved_change_to_color?
  after_destroy_commit -> { after_commit_side_effect(:touch_cards, on: board) }

  def touch_cards
    cards.touch_all
  end
end
