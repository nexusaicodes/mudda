class Board < ApplicationRecord
  include Cards, Triageable

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :account, default: -> { creator.account }

  normalizes :name, with: -> { it.strip }
  validates :name, presence: true

  scope :alphabetically, -> { order("lower(name)") }
  scope :ordered_by_recent_activity, -> { order(updated_at: :desc) }
end
