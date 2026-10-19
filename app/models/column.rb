class Column < ApplicationRecord
  include Colored, Positioned

  belongs_to :board, touch: true
  has_many :cards, dependent: :destroy

  # Card lane predicates and Board#backlog_column key off the name, so it is set once, at creation.
  attr_readonly :name
end
