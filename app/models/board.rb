class Board < ApplicationRecord
  include Accessible, Board::Storage, Broadcastable, Cards, Filterable, Publishable, ::Storage::Tracked, Triageable

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :account, default: -> { creator.account }

  has_rich_text :public_description

  has_many :events

  scope :alphabetically, -> { order("lower(name)") }
  scope :ordered_by_recently_accessed, -> { merge(Access.ordered_by_recently_accessed) }
end
