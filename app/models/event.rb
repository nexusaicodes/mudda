class Event < ApplicationRecord
  include Promptable

  belongs_to :board
  belongs_to :creator, class_name: "User"
  belongs_to :eventable, polymorphic: true

  scope :chronologically, -> { order created_at: :asc, id: :desc }
  scope :reverse_chronologically, -> { order created_at: :desc, id: :desc }
  scope :for_boards, ->(ids) { where(board_id: ids) if ids.present? }
  scope :preloaded, -> {
    includes(:creator, :board, {
      eventable: [
        :creator, :image_attachment,
        { rich_text_body: :embeds_attachments },
        { rich_text_description: :embeds_attachments },
        { card: :image_attachment }
      ]
    })
  }

  after_create -> { eventable.event_was_created(self) }

  delegate :card, to: :eventable

  def action
    super.inquiry
  end
end
