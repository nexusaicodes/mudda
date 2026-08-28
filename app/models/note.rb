class Note < ApplicationRecord
  include Attachments, Eventable, Promptable, Searchable

  belongs_to :card, touch: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_rich_text :body

  scope :chronologically, -> { order created_at: :asc, id: :desc }
  scope :preloaded, -> { with_rich_text_body }

  delegate :board, :accessible_to?, to: :card

  def to_partial_path
    "cards/#{super}"
  end
end
