class Event < ApplicationRecord
  include Promptable

  belongs_to :creator, class_name: "User"
  belongs_to :eventable, polymorphic: true

  scope :chronologically, -> { order created_at: :asc, id: :desc }
  scope :reverse_chronologically, -> { order created_at: :desc, id: :desc }
  scope :preloaded, -> {
    includes(:creator, {
      eventable: [
        :creator,
        { rich_text_body: :embeds_attachments },
        { rich_text_description: :embeds_attachments }
      ]
    })
  }

  after_create -> { eventable.event_was_created(self) }

  delegate :card, to: :eventable

  def action
    super.inquiry
  end
end
