class Column < ApplicationRecord
  include Colored, Positioned

  belongs_to :board, touch: true
  has_many :cards, dependent: :destroy

  # Card lane predicates and Board#backlog_column key off the name, so it is set once, at creation.
  attr_readonly :name

  after_save_commit    -> { cards.touch_all }, if: :saved_change_to_color?
  after_destroy_commit -> { board.cards.touch_all }
end
