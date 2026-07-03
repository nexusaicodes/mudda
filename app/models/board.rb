class Board < ApplicationRecord
  include Board::Storage, Cards, Filterable, ::Storage::Tracked, Triageable

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :account, default: -> { creator.account }

  has_many :events

  scope :alphabetically, -> { order("lower(name)") }
  scope :ordered_by_recent_activity, -> { order(updated_at: :desc) }
end
